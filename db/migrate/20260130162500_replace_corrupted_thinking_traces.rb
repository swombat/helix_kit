class ReplaceCorruptedThinkingTraces < ActiveRecord::Migration[8.0]

  def up
    # RubyLLM 1.11 upgrade (Jan 23, 2026) changed thinking chunks from strings
    # to RubyLLM::Thinking objects. The streaming code called .to_s on these,
    # writing "#<RubyLLM::Thinking:0x...>" into the database instead of actual text.
    # The original thinking content is unrecoverable.
    #
    # For human users: replace with an explanatory message.
    # For AI message history: clear to nil so models don't see garbage tags.
    execute <<~SQL
      UPDATE messages
      SET thinking_text = '[Thinking trace lost due to a RubyLLM upgrade issue on January 23rd, 2026]'
      WHERE thinking_text LIKE '%#<RubyLLM::Thinking:%'
    SQL
  end

  def down
    # Cannot recover original thinking content
  end

end
