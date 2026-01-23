class RenameThinkingToThinkingText < ActiveRecord::Migration[8.1]

  def change
    # RubyLLM 1.10+ expects 'thinking_text' instead of 'thinking'
    rename_column :messages, :thinking, :thinking_text

    # RubyLLM 1.10+ also tracks thinking token usage
    add_column :messages, :thinking_tokens, :integer unless column_exists?(:messages, :thinking_tokens)
  end

end
