# frozen_string_literal: true

# This migration adds metadata column to tool_calls to support Gemini thought signatures.
# See: https://github.com/crmne/ruby_llm/issues/521
#
# Gemini 2.5+ and 3 models require thought_signature to be preserved across multi-turn
# tool calls. This metadata column stores the encrypted thought signature so it can be
# replayed in subsequent API requests.
class AddMetadataToToolCalls < ActiveRecord::Migration[8.1]

  def change
    add_column :tool_calls, :metadata, :jsonb, default: {}
  end

end
