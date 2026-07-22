require "test_helper"

module Agents
  class SandboxModelTest < ActiveSupport::TestCase

    test "uses provider model id for chaos runtime when configured" do
      agent = agents(:research_assistant)
      agent.model_id = "anthropic/claude-opus-4.7"

      assert_equal "anthropic", Agents::Sandbox.chaos_provider_for(agent)
      assert_equal "claude-opus-4-7", Agents::Sandbox.chaos_model_for(agent)
    end

    test "maps Claude Opus 4.8 to direct provider id" do
      agent = agents(:research_assistant)
      agent.model_id = "anthropic/claude-opus-4.8"

      assert_equal "claude-opus-4-8", Agents::Sandbox.chaos_model_for(agent)
    end

    test "falls back to provider suffix for direct provider models" do
      agent = agents(:research_assistant)
      agent.model_id = "anthropic/claude-sonnet-4-5"

      assert_equal "claude-sonnet-4-5", Agents::Sandbox.chaos_model_for(agent)
    end

    test "keeps openrouter model id intact" do
      agent = agents(:research_assistant)
      agent.model_id = "openrouter/auto"

      assert_equal "openrouter", Agents::Sandbox.chaos_provider_for(agent)
      assert_equal "openrouter/auto", Agents::Sandbox.chaos_model_for(agent)
    end

    test "maps OpenRouter xAI prefix to Chaos provider id" do
      agent = agents(:research_assistant)
      agent.model_id = "x-ai/grok-4.5"

      assert_equal "xai", Agents::Sandbox.chaos_provider_for(agent)
      assert_equal "grok-4.5", Agents::Sandbox.chaos_model_for(agent)
    end

    test "status reports stale image explicitly" do
      agent = agents(:research_assistant)
      agent.update!(
        runtime: "external",
        uuid: SecureRandom.uuid_v7,
        container_name: "hk-agent-test",
        container_image: "helixkit-agent-runtime:latest"
      )
      sandbox = Agents::Sandbox.new(agent)
      container = {
        "Id" => "container123456789",
        "Image" => "sha256:old",
        "State" => { "Status" => "running", "Running" => true, "ExitCode" => 0 },
        "NetworkSettings" => { "Ports" => {} },
        "Config" => { "Env" => [ "HELIXKIT_APP_URL=http://helix-kit-web:3000" ] }
      }
      sandbox.define_singleton_method(:docker_capture) do |*args|
        case args
        in [ "info", "--format", "{{.ServerVersion}}" ]
          { ok: true, stdout: "27.0.0\n", stderr: "" }
        in [ "volume", "inspect", _name ]
          { ok: true, stdout: "[]", stderr: "" }
        in [ "image", "inspect", "--format", "{{.Id}}", "helixkit-agent-runtime:latest" ]
          { ok: true, stdout: "sha256:new\n", stderr: "" }
        in [ "container", "inspect", "hk-agent-test" ]
          { ok: true, stdout: [ container ].to_json, stderr: "" }
        in [ "logs", "--tail", "30", "hk-agent-test" ]
          { ok: true, stdout: "", stderr: "" }
        else
          raise "unexpected docker args: #{args.inspect}"
        end
      end

      status = sandbox.status

      assert_equal false, status[:container_image_current]
      assert_equal true, status[:image_stale]
      assert_equal "hk-agent-#{agent.uuid}-repo", status[:repo_volume_name]
      assert_equal true, status[:repo_volume_exists]
    end

    test "recreate migrates repo volume before replacing container" do
      agent = agents(:research_assistant)
      agent.update!(uuid: SecureRandom.uuid_v7, container_name: "hk-agent-test")
      sandbox = Agents::Sandbox.new(agent)
      calls = []
      sandbox.define_singleton_method(:container_exists?) { true }
      sandbox.define_singleton_method(:migrate_repo_volume_from_container!) { calls << :migrate_repo }
      sandbox.define_singleton_method(:remove!) { |delete_volume: false| calls << [ :remove, delete_volume ] }
      sandbox.define_singleton_method(:spawn!) { calls << :spawn }

      sandbox.recreate!

      assert_equal [ :migrate_repo, [ :remove, false ], :spawn ], calls
    end

  end
end
