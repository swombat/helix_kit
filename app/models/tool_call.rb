class ToolCall < ApplicationRecord

  acts_as_tool_call

  def thought_signature
    replay_payload&.dig("thought_signature")
  end

end
