require "test_helper"

class ExternalAgentResponseRequestTest < ActiveSupport::TestCase

  test "trigger request points external agent at the API skill file" do
    agent = agents(:research_assistant)
    chat = agent.account.chats.create!(model_id: "openrouter/auto", title: "External prompt")
    request = ExternalAgentResponseRequest.new(agent: agent, chat: chat)
    text = request.send(:request_text)

    assert_includes text, "helixkit-api.md"
    assert_includes text, "post-message endpoint"
  end

end
