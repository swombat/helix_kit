require "test_helper"

class ModelChangeOrientationJobTest < ActiveJob::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.update_columns(
      runtime: "external",
      health_state: "healthy",
      uuid: SecureRandom.uuid_v7,
      model_id: "openai/gpt-5.2"
    )
  end

  test "sends a fresh model change orientation on the expected healthy external model" do
    calls = []
    request = Object.new
    def request.call = { status: 200 }

    ExternalAgentOrientationRequest.stub(:new, ->(**args) { calls << args; request }) do
      ModelChangeOrientationJob.perform_now(@agent.id, "openai/gpt-5.2")
    end

    assert_equal 1, calls.size
    assert_equal @agent, calls.first.fetch(:agent)
    assert_equal :model_change, calls.first.fetch(:context)
    assert_equal "souls.house model-change orientation", calls.first.fetch(:requested_by)
  end

  test "coalesces stale model changes" do
    ExternalAgentOrientationRequest.stub(:new, ->(**) { flunk "stale job should not send" }) do
      assert_nothing_raised do
        ModelChangeOrientationJob.perform_now(@agent.id, "anthropic/claude-fable-5")
      end
    end
  end

  test "does not send while the resident is offline or unhealthy" do
    ExternalAgentOrientationRequest.stub(:new, ->(**) { flunk "unavailable resident should not be called" }) do
      assert_nothing_raised do
        @agent.update_columns(runtime: "offline")
        ModelChangeOrientationJob.perform_now(@agent.id, @agent.model_id)

        @agent.update_columns(runtime: "external", health_state: "unhealthy")
        ModelChangeOrientationJob.perform_now(@agent.id, @agent.model_id)
      end
    end
  end

  test "does nothing when the resident was deleted before the job ran" do
    agent_id = @agent.id
    @agent.destroy!

    assert_nothing_raised do
      ModelChangeOrientationJob.perform_now(agent_id, "openai/gpt-5.2")
    end
  end

end
