require "test_helper"

module Agents
  class SandboxModelTest < ActiveSupport::TestCase

    test "uses provider model id for chaos runtime when configured" do
      agent = agents(:research_assistant)
      agent.model_id = "anthropic/claude-opus-4.7"

      assert_equal "claude-opus-4-7", Agents::Sandbox.chaos_model_for(agent)
    end

    test "falls back to provider suffix for direct provider models" do
      agent = agents(:research_assistant)
      agent.model_id = "anthropic/claude-sonnet-4-5"

      assert_equal "claude-sonnet-4-5", Agents::Sandbox.chaos_model_for(agent)
    end

    test "keeps openrouter model id intact" do
      agent = agents(:research_assistant)
      agent.model_id = "openrouter/auto"

      assert_equal "openrouter/auto", Agents::Sandbox.chaos_model_for(agent)
    end

  end
end
