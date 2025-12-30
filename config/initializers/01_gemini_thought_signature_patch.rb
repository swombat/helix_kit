# frozen_string_literal: true

# =============================================================================
# GEMINI THOUGHT SIGNATURE MONKEY PATCH
# =============================================================================
#
# This patch adds support for Gemini's thought_signature feature required for
# tool calling with Gemini 2.5+ and 3 models.
#
# WHY THIS EXISTS:
# Gemini models require thought_signature to be preserved across multi-turn
# tool calls. Without this, tool calling fails with:
#   "Function call is missing a thought_signature in functionCall parts"
#
# IMPORTANT - WHEN TO REMOVE:
# This patch should be REMOVED when upgrading RubyLLM to a version that
# includes PR #542 (https://github.com/crmne/ruby_llm/pull/542).
# Check the RubyLLM changelog for "thought signature" or "Gemini tool calling"
# support before upgrading.
#
# To test if it's safe to remove:
#   1. Comment out this entire file
#   2. Test Gemini tool calling in a group chat
#   3. If it works, delete this file
#   4. If it fails with thought_signature error, uncomment and keep the patch
#
# See: https://github.com/crmne/ruby_llm/issues/521
# =============================================================================

# Only apply patch if RubyLLM is loaded and Gemini provider exists
if defined?(RubyLLM) && defined?(RubyLLM::Providers::Gemini)

  # Step 1: Add thought_signature accessor to ToolCall
  RubyLLM::ToolCall.class_eval do
    attr_accessor :thought_signature
  end

  # Step 2: Patch Gemini provider to READ thought_signature from API responses
  module GeminiToolsThoughtSignaturePatch

    def extract_tool_calls(data)
      tool_calls = super
      return nil unless tool_calls

      # Find the function call part that contains the thought signature
      function_call_part = data&.dig("candidates", 0, "content", "parts")
        &.find { |p| p["functionCall"] }
      signature = function_call_part&.[]("thoughtSignature")

      Rails.logger.info "[ThoughtSignature] Extracting from response: signature=#{signature ? 'present' : 'nil'}, tool_calls=#{tool_calls.keys}"

      # Attach signature to the first tool call (Gemini typically returns one at a time)
      if signature && tool_calls.values.first
        tool_calls.values.first.thought_signature = signature
        Rails.logger.info "[ThoughtSignature] Attached signature to tool call: #{tool_calls.keys.first}"
      end

      tool_calls
    end

  end

  # Step 3: Patch Gemini provider to WRITE thought_signature into API requests
  module GeminiChatThoughtSignaturePatch

    def render_payload(messages, **options)
      payload = super

      Rails.logger.info "[ThoughtSignature] render_payload called with #{messages.length} messages"

      payload[:contents]&.each_with_index do |content_part, index|
        message = messages[index]
        Rails.logger.info "[ThoughtSignature] Message #{index}: role=#{message&.role}, tool_call?=#{message&.tool_call?}"
        next unless message&.role == :assistant && message.tool_call?

        tool_call = message.tool_calls&.values&.first
        Rails.logger.info "[ThoughtSignature] Tool call found: #{tool_call&.id}, has_signature=#{tool_call&.thought_signature ? 'yes' : 'no'}"
        if tool_call&.thought_signature
          function_call_part = content_part[:parts]&.find { |p| p.key?(:functionCall) }
          if function_call_part
            function_call_part[:thoughtSignature] = tool_call.thought_signature
            Rails.logger.info "[ThoughtSignature] Added signature to payload for tool: #{tool_call.id}"
          end
        end
      end

      payload
    end

  end

  # Step 4: Patch ActiveRecord persistence to SAVE thought_signature to metadata
  module ActiveRecordThoughtSignaturePersistencePatch

    def persist_tool_calls(tool_calls)
      tool_calls.each_value do |tool_call|
        attributes = tool_call.to_h
        attributes[:tool_call_id] = attributes.delete(:id)

        # Store thought_signature in metadata column
        if tool_call.thought_signature
          attributes[:metadata] ||= {}
          attributes[:metadata][:thought_signature] = tool_call.thought_signature
        end

        @message.tool_calls_association.create!(**attributes)
      end
    end

  end

  # Step 5: Patch ActiveRecord rehydration to LOAD thought_signature from metadata
  module ActiveRecordThoughtSignatureRehydrationPatch

    private

    def extract_tool_calls
      tool_calls_hash = super

      tool_calls_association.each do |ar_tool_call|
        llm_tool_call = tool_calls_hash[ar_tool_call.tool_call_id]
        next unless llm_tool_call

        signature = ar_tool_call.metadata&.dig("thought_signature")
        llm_tool_call.thought_signature = signature if signature
      end

      tool_calls_hash
    end

  end

  # Apply all patches
  RubyLLM::Providers::Gemini::Tools.prepend(GeminiToolsThoughtSignaturePatch)
  RubyLLM::Providers::Gemini::Chat.prepend(GeminiChatThoughtSignaturePatch)
  RubyLLM::ActiveRecord::ChatMethods.prepend(ActiveRecordThoughtSignaturePersistencePatch)
  RubyLLM::ActiveRecord::MessageMethods.prepend(ActiveRecordThoughtSignatureRehydrationPatch)

  Rails.logger.info "[RubyLLM] Gemini thought_signature patch applied"
end
