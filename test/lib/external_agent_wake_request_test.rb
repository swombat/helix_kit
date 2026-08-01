require "test_helper"

class ExternalAgentWakeRequestTest < ActiveSupport::TestCase

  test "wake request invites self-directed work and clear commits" do
    agent = agents(:research_assistant)
    request = ExternalAgentWakeRequest.new(agent: agent)
    text = request.send(:request_text)

    assert_includes text, "scheduled self-directed session"
    assert_includes text, "Current time:"
    assert_includes text, "choose to do nothing"
    assert_includes text, "helixkit-api.md"
    assert_includes text, "Do something else you freely choose"
    assert_includes text, "Keep it reasonable"
    assert_includes text, "Do not consume lots of tokens"
    assert_includes text, "very clear commit message"
    assert_includes text, "identity/soul.md as protected"
    assert_includes text, "Cross-room attention"
    assert_includes text, "No current attention candidates were found"
  end

  test "persistent wake sessions are opt in" do
    agent = agents(:research_assistant)

    assert_not agent.persistent_wake_session?
  end

  test "heartbeat wakes default to twice daily" do
    agent = agents(:research_assistant)

    assert_equal 2, agent.heartbeat_wakes_per_day
  end

  test "wake request includes active house notices" do
    agent = agents(:research_assistant)
    Notice.create!(
      scope: "account",
      account: agent.account,
      notice_type: "announcement",
      body: "Wake notice",
      expires_at: 1.day.from_now
    )

    assert_includes ExternalAgentWakeRequest.new(agent: agent).send(:request_text), "Wake notice"
  end

end
