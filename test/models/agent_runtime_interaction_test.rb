require "test_helper"
require "action_cable/test_helper"

class AgentRuntimeInteractionTest < ActiveSupport::TestCase

  include ActionCable::TestHelper

  test "records trigger result stdout and stderr" do
    agent = agents(:research_assistant)
    chat = agent.account.chats.create!(model_id: "openrouter/auto", title: "Runtime log")

    result = AgentRuntimeInteraction.record_trigger!(
      agent: agent,
      chat: chat,
      trigger_kind: "conversation",
      conversation_id: chat.to_param,
      requested_by: "test",
      session_id: "session-1",
      endpoint_url: "https://agent.example.com",
      request_text: "Please respond"
    ) do
      {
        status: 200,
        body: {
          "status" => "ok",
          "returncode" => 0,
          "stdout" => "hello from runtime",
          "stderr" => "diagnostic noise"
        }
      }
    end

    interaction = AgentRuntimeInteraction.last
    assert_equal 200, result[:status]
    assert_equal agent, interaction.agent
    assert_equal chat, interaction.chat
    assert_equal "ok", interaction.runtime_status
    assert_equal 0, interaction.runtime_returncode
    assert_equal "hello from runtime", interaction.stdout
    assert_equal "diagnostic noise", interaction.stderr
    assert_not_nil interaction.duration_ms
  end

  test "broadcasts agent runtime interactions refresh when recorded" do
    agent = agents(:research_assistant)
    chat = agent.account.chats.create!(model_id: "openrouter/auto", title: "Runtime log")

    assert_broadcasts("Agent:#{agent.obfuscated_id}", 2) do
      assert_broadcasts("Chat:#{chat.obfuscated_id}", 2) do
        AgentRuntimeInteraction.record_trigger!(
          agent: agent,
          chat: chat,
          trigger_kind: "conversation",
          conversation_id: chat.to_param,
          requested_by: "test",
          session_id: "session-1",
          endpoint_url: "https://agent.example.com",
          request_text: "Please respond"
        ) do
          { status: 200, body: { "status" => "ok" } }
        end
      end
    end
  end

  test "chat timeline activity is visible only when no assistant message was posted" do
    agent = agents(:research_assistant)
    chat = agent.account.chats.create!(model_id: "openrouter/auto", title: "Runtime log")

    interaction = AgentRuntimeInteraction.create!(
      agent: agent,
      chat: chat,
      trigger_kind: "conversation",
      conversation_obfuscated_id: chat.to_param,
      requested_by: "test",
      session_id: "session-1",
      endpoint_url: "https://agent.example.com",
      request_text: "Please respond",
      started_at: 1.minute.ago,
      finished_at: Time.current,
      stdout: "I chose not to post."
    )

    assert interaction.visible_in_chat_timeline?
    assert_equal "completed_without_reply", interaction.as_chat_activity_json[:status]

    chat.messages.create!(role: "assistant", agent: agent, content: "Actually posting.")

    assert_not interaction.visible_in_chat_timeline?
  end

  test "record_result! maps chaos session and usage fields from the response body" do
    agent = agents(:research_assistant)
    chat = agent.account.chats.create!(model_id: "openrouter/auto", title: "Runtime log")

    AgentRuntimeInteraction.record_trigger!(
      agent: agent,
      chat: chat,
      trigger_kind: "conversation",
      conversation_id: chat.to_param,
      requested_by: "test",
      session_id: "session-1",
      endpoint_url: "https://agent.example.com",
      request_text: "Please respond",
      last_included_message_id: 42
    ) do
      {
        status: 200,
        body: {
          "status" => "ok",
          "chaos_session_id" => "chaos-abc",
          "session_resumed" => true,
          "fresh_fallback" => false,
          "usage" => { "input_tokens" => 100, "cached_input_tokens" => 40, "output_tokens" => 20 }
        }
      }
    end

    interaction = AgentRuntimeInteraction.last
    assert_equal 42, interaction.last_included_message_id
    assert_equal "chaos-abc", interaction.chaos_session_id
    assert interaction.session_resumed
    assert_not interaction.fresh_fallback
    assert_equal 100, interaction.input_tokens
    assert_equal 40, interaction.cached_input_tokens
    assert_equal 20, interaction.output_tokens
  end

  test "record_result! leaves usage and session fields nil when absent from the response body" do
    agent = agents(:research_assistant)
    chat = agent.account.chats.create!(model_id: "openrouter/auto", title: "Runtime log")

    AgentRuntimeInteraction.record_trigger!(
      agent: agent,
      chat: chat,
      trigger_kind: "conversation",
      conversation_id: chat.to_param,
      requested_by: "test",
      session_id: "session-1",
      endpoint_url: "https://agent.example.com",
      request_text: "Please respond"
    ) do
      { status: 200, body: { "status" => "ok" } }
    end

    interaction = AgentRuntimeInteraction.last
    assert_nil interaction.last_included_message_id
    assert_nil interaction.chaos_session_id
    assert_nil interaction.session_resumed
    assert_nil interaction.fresh_fallback
    assert_nil interaction.input_tokens
    assert_nil interaction.cached_input_tokens
    assert_nil interaction.output_tokens
  end

end
