require "test_helper"
require "webmock/minitest"

class ChaosTriggerClientTest < ActiveSupport::TestCase

  test "sends optional provider and model in trigger payload" do
    stub = stub_request(:post, "https://agent.example.com/trigger")
      .with do |request|
        body = JSON.parse(request.body)
        body.fetch("provider") == "anthropic" &&
          body.fetch("model") == "claude-opus-4-7" &&
          body.fetch("timeout_secs") == 1800
      end
      .to_return(status: 200, body: { status: "ok" }.to_json)

    result = ChaosTriggerClient.new("https://agent.example.com", "tr_valid").request_response(
      conversation_id: nil,
      requested_by: "test",
      session_id: "session",
      request: "hello",
      trigger_kind: "orientation",
      provider: "anthropic",
      model: "claude-opus-4-7",
      read_timeout: 1830,
      runtime_timeout_secs: 1800
    )

    assert_equal 200, result[:status]
    assert_requested stub
  end

  test "defaults runtime timeout to thirty minutes" do
    stub = stub_request(:post, "https://agent.example.com/trigger")
      .with do |request|
        JSON.parse(request.body).fetch("timeout_secs") == 1800
      end
      .to_return(status: 200, body: { status: "ok" }.to_json)

    result = ChaosTriggerClient.new("https://agent.example.com", "tr_valid").request_response(
      conversation_id: nil,
      requested_by: "test",
      session_id: "session",
      request: "hello"
    )

    assert_equal 200, result[:status]
    assert_requested stub
  end

  test "omits request_delta and persistent_session from body by default" do
    stub = stub_request(:post, "https://agent.example.com/trigger")
      .with do |request|
        body = JSON.parse(request.body)
        !body.key?("request_delta") && !body.key?("persistent_session")
      end
      .to_return(status: 200, body: { status: "ok" }.to_json)

    ChaosTriggerClient.new("https://agent.example.com", "tr_valid").request_response(
      conversation_id: nil,
      requested_by: "test",
      session_id: "session",
      request: "hello"
    )

    assert_requested stub
  end

  test "includes request_delta and persistent_session when given" do
    stub = stub_request(:post, "https://agent.example.com/trigger")
      .with do |request|
        body = JSON.parse(request.body)
        body.fetch("request_delta") == "slim delta prompt" && body.fetch("persistent_session") == true && body.fetch("request") == "full prompt"
      end
      .to_return(status: 200, body: { status: "ok" }.to_json)

    ChaosTriggerClient.new("https://agent.example.com", "tr_valid").request_response(
      conversation_id: nil,
      requested_by: "test",
      session_id: "session",
      request: "full prompt",
      request_delta: "slim delta prompt",
      persistent_session: true
    )

    assert_requested stub
  end

  test "includes channel-specific trigger payload without replacing standard fields" do
    stub = stub_request(:post, "https://agent.example.com/trigger")
      .with do |request|
        body = JSON.parse(request.body)
        body["channel"] == "telegram" &&
          body["thread_id"] == "thread-1" &&
          body["request"] == "canonical request"
      end
      .to_return(status: 200, body: { status: "ok" }.to_json)

    ChaosTriggerClient.new("https://agent.example.com", "tr_valid").request_response(
      conversation_id: "thread-1",
      requested_by: "test",
      session_id: "session",
      request: "canonical request",
      trigger_payload: { channel: "telegram", thread_id: "thread-1", request: "cannot replace" }
    )

    assert_requested stub
  end

end
