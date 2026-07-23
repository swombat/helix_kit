require "test_helper"

class OrientNewAgentJobTest < ActiveJob::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.update!(
      runtime: "external",
      health_state: "healthy",
      birth_committed_at: Time.current,
      uuid: SecureRandom.uuid_v7
    )
  end

  test "records operational orientation timestamps independently of journaling" do
    request = Object.new
    def request.call = { status: 200, oriented: false }

    ExternalAgentOrientationRequest.stub(:new, ->(**) { request }) do
      OrientNewAgentJob.perform_now(@agent.id)
    end

    @agent.reload
    assert_predicate @agent.orientation_requested_at, :present?
    assert_predicate @agent.orientation_completed_at, :present?
    assert_nil @agent.oriented_at
  end

  test "leaves completion blank when the orientation request fails" do
    request = Object.new
    def request.call = { status: 500, error: "failed" }

    ExternalAgentOrientationRequest.stub(:new, ->(**) { request }) do
      OrientNewAgentJob.perform_now(@agent.id)
    end

    @agent.reload
    assert_predicate @agent.orientation_requested_at, :present?
    assert_nil @agent.orientation_completed_at
    assert_equal "failed", @agent.orientation_last_error
    assert_predicate @agent.orientation_last_error_at, :present?
  end

end
