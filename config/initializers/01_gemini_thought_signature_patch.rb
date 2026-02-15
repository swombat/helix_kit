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

  # Step 1: Thread-safe cache for thought signatures, keyed by tool call ID
  # This is needed because RubyLLM recreates ToolCall objects internally
  class ThoughtSignatureCache

    class << self

      def store(tool_call_id, signature)
        cache[tool_call_id] = signature
        Rails.logger.info "[ThoughtSignature] Cached signature for tool_call_id=#{tool_call_id}"
      end

      def fetch(tool_call_id)
        cache[tool_call_id]
      end

      def clear(tool_call_id)
        cache.delete(tool_call_id)
      end

      private

      def cache
        @cache ||= {}
      end

    end

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

      # Store signature in cache for each tool call ID
      if signature
        tool_calls.each do |id, tool_call|
          ThoughtSignatureCache.store(id, signature)
          Rails.logger.info "[ThoughtSignature] Stored signature for: id=#{id}, name=#{tool_call.name}"
        end
      end

      tool_calls
    end

  end

  # Step 3: Patch Gemini provider to WRITE thought_signature into API requests
  # This patches format_tool_call which creates the functionCall parts
  module GeminiToolsFormatPatch

    def format_tool_call(msg)
      parts = []

      if msg.content && !(msg.content.respond_to?(:empty?) && msg.content.empty?)
        formatted_content = RubyLLM::Providers::Gemini::Media.format_content(msg.content)
        parts.concat(formatted_content.is_a?(Array) ? formatted_content : [ formatted_content ])
      end

      msg.tool_calls.each_value do |tool_call|
        function_call_part = {
          functionCall: {
            name: tool_call.name,
            args: tool_call.arguments
          }
        }

        # Look up thought signature from cache by tool call ID
        signature = ThoughtSignatureCache.fetch(tool_call.id)
        Rails.logger.info "[ThoughtSignature] format_tool_call: name=#{tool_call.name}, id=#{tool_call.id}, signature=#{signature ? 'present' : 'nil'}"

        if signature
          function_call_part[:thoughtSignature] = signature
          Rails.logger.info "[ThoughtSignature] Added signature to functionCall for: #{tool_call.name}"
        end

        parts << function_call_part
      end

      parts
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
  # Note: Both patches go to Tools module - one for reading signatures, one for writing them
  RubyLLM::Providers::Gemini::Tools.prepend(GeminiToolsThoughtSignaturePatch)
  RubyLLM::Providers::Gemini::Tools.prepend(GeminiToolsFormatPatch)

  # ActiveRecord patches only needed if using RubyLLM's ActiveRecord integration
  # (not used in this app, but kept for completeness)
  if defined?(RubyLLM::ActiveRecord::ChatMethods)
    RubyLLM::ActiveRecord::ChatMethods.prepend(ActiveRecordThoughtSignaturePersistencePatch)
  end
  if defined?(RubyLLM::ActiveRecord::MessageMethods)
    RubyLLM::ActiveRecord::MessageMethods.prepend(ActiveRecordThoughtSignatureRehydrationPatch)
  end

  Rails.logger.info "[RubyLLM] Gemini thought_signature patch applied"
end
