require "test_helper"
require "webmock/minitest"

class ChaosTriggerClientTest < ActiveSupport::TestCase

  test "sends optional model in trigger payload" do
    stub = stub_request(:post, "https://agent.example.com/trigger")
      .with do |request|
        body = JSON.parse(request.body)
        body.fetch("model") == "claude-opus-4-7" && body.fetch("timeout_secs") == 1800
      end
      .to_return(status: 200, body: { status: "ok" }.to_json)

    result = ChaosTriggerClient.new("https://agent.example.com", "tr_valid").request_response(
      conversation_id: nil,
      requested_by: "test",
      session_id: "session",
      request: "hello",
      trigger_kind: "orientation",
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

end
