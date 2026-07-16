require "test_helper"

class ExternalAgentWakeRequestTest < ActiveSupport::TestCase

  test "wake request invites self-directed work and clear commits" do
    agent = agents(:research_assistant)
    request = ExternalAgentWakeRequest.new(agent: agent)
    text = request.send(:request_text)

    assert_includes text, "hourly self-directed session"
    assert_includes text, "Current time:"
    assert_includes text, "choose to do nothing"
    assert_includes text, "helixkit-api.md"
    assert_includes text, "Do something else you freely choose"
    assert_includes text, "Keep it reasonable"
    assert_includes text, "Do not consume lots of tokens"
    assert_includes text, "very clear commit message"
    assert_includes text, "identity/soul.md as protected"
  end

  test "persistent wake sessions are opt in" do
    agent = agents(:research_assistant)

    assert_not agent.persistent_wake_session?
  end

  test "half-hourly wakes are opt in" do
    agent = agents(:research_assistant)

    assert_not agent.half_hourly_wake?
  end

end
