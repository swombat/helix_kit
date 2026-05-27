require "test_helper"
require "webmock/minitest"

class ExternalAgentResponseRequestTest < ActiveSupport::TestCase

  test "trigger request points external agent at the API skill file" do
    agent = agents(:research_assistant)
    chat = agent.account.chats.create!(model_id: "openrouter/auto", title: "External prompt")
    chat.messages.create!(role: "user", content: "Can you see this transcript?")
    request = ExternalAgentResponseRequest.new(agent: agent, chat: chat)
    text = request.send(:request_text)

    assert_includes text, "HELIXKIT_BEARER_TOKEN"
    assert_includes text, "helixkit-post-message"
    assert_includes text, "explicit user request"
    assert_includes text, "normally expecting a visible reply"
    assert_includes text, "final answer in this Chaos runtime is diagnostic stdout only"
    assert_includes text, "must post it to HelixKit yourself before exiting"
    assert_includes text, "no separate confirmation is needed"
    assert_includes text, "default for this trigger is that you post a reply"
    assert_includes text, "choosing not to is also a valid response"
    assert_includes text, "already authorized"
    assert_includes text, "post your own messages"
    assert_includes text, "stdout is diagnostic only"
    assert_includes text, "explain your reason briefly on stdout"
    assert_includes text, "Conversation transcript"
    assert_includes text, "Can you see this transcript?"

    # Sovereignty guard: assistant-pattern nudges that previously crept in.
    # The agent's outputs are messages, not "assistant messages"; the trigger
    # is an invitation, not a "decide and act now" imperative; the transcript
    # is rendered with names, not role labels like "user (..." / "assistant (...".
    refute_includes text, "post your own assistant messages"
    refute_includes text, "Do not offer to post later"
    refute_includes text, "decide and act now"
    refute_includes text, "Do not ask for a second confirmation"
    refute_includes text, "asking you to act"
  end

  test "records runtime stdout and stderr when triggering external agent" do
    agent = agents(:research_assistant)
    chat = agent.account.chats.create!(model_id: "openrouter/auto", title: "External prompt")
    agent.update!(
      runtime: "external",
      uuid: SecureRandom.uuid_v7,
      endpoint_url: "https://agent.example.com",
      trigger_bearer_token: "tr_valid",
      health_state: "healthy",
      consecutive_health_failures: 0
    )
    stub_request(:post, "https://agent.example.com/trigger")
      .to_return(
        status: 200,
        body: {
          status: "ok",
          returncode: 0,
          stdout: "runtime said hello",
          stderr: "runtime diagnostics"
        }.to_json
      )

    assert_difference "AgentRuntimeInteraction.count", 1 do
      ExternalAgentResponseRequest.new(agent: agent, chat: chat).call
    end

    interaction = AgentRuntimeInteraction.last
    assert_equal agent, interaction.agent
    assert_equal chat, interaction.chat
    assert_equal "conversation", interaction.trigger_kind
    assert_equal 200, interaction.transport_status
    assert_equal "ok", interaction.runtime_status
    assert_equal "runtime said hello", interaction.stdout
    assert_equal "runtime diagnostics", interaction.stderr
  end

end
