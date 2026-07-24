require "test_helper"

module Agents
  class SandboxModelTest < ActiveSupport::TestCase

    test "uses provider model id for chaos runtime when configured" do
      agent = agents(:research_assistant)
      agent.model_id = "anthropic/claude-opus-4.7"

      ResolvesProvider.stub :api_key_available?, true do
        assert_equal "anthropic", Agents::Sandbox.chaos_provider_for(agent)
        assert_equal "claude-opus-4-7", Agents::Sandbox.chaos_model_for(agent)
      end
    end

    test "maps Claude Opus 4.8 to direct provider id" do
      agent = agents(:research_assistant)
      agent.model_id = "anthropic/claude-opus-4.8"

      ResolvesProvider.stub :api_key_available?, true do
        assert_equal "claude-opus-4-8", Agents::Sandbox.chaos_model_for(agent)
      end
    end

    test "keeps models without a direct provider mapping on OpenRouter" do
      agent = agents(:research_assistant)
      agent.model_id = "anthropic/claude-sonnet-4-5"

      ResolvesProvider.stub :api_key_available?, true do
        assert_equal "openrouter", Agents::Sandbox.chaos_provider_for(agent)
        assert_equal "anthropic/claude-sonnet-4-5", Agents::Sandbox.chaos_model_for(agent)
      end
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

      ResolvesProvider.stub :api_key_available?, true do
        assert_equal "xai", Agents::Sandbox.chaos_provider_for(agent)
        assert_equal "grok-4.5", Agents::Sandbox.chaos_model_for(agent)
      end
    end

    test "maps RubyLLM Gemini provider to Chaos provider id" do
      agent = agents(:research_assistant)
      agent.model_id = "google/gemini-3.1-pro-preview"

      ResolvesProvider.stub :api_key_available?, true do
        assert_equal "gemini", Agents::Sandbox.chaos_provider_for(agent)
        assert_equal "gemini-3.1-pro-preview", Agents::Sandbox.chaos_model_for(agent)
      end
    end

    test "every selectable RubyLLM model maps to a configured Chaos provider and model" do
      agent = agents(:research_assistant)

      ResolvesProvider.stub :api_key_available?, true do
        Chat::MODELS.map { |model| model.fetch(:model_id) }.uniq.each do |model_id|
          agent.model_id = model_id
          ruby_llm_selection = ResolvesProvider.resolve_provider(model_id)
          chaos_selection = Agents::Sandbox.chaos_selection_for(agent)

          assert_equal(
            ruby_llm_selection.fetch(:provider).to_s,
            chaos_selection.fetch(:provider),
            "provider mapping differs for #{model_id}"
          )
          assert_equal(
            ruby_llm_selection.fetch(:model_id),
            chaos_selection.fetch(:model),
            "model mapping differs for #{model_id}"
          )
          assert_includes(
            Agents::Sandbox::SUPPORTED_CHAOS_PROVIDER_IDS,
            chaos_selection.fetch(:provider),
            "Chaos provider is not configured for #{model_id}"
          )
        end
      end
    end

    test "every selectable model falls back intact through OpenRouter" do
      agent = agents(:research_assistant)

      ResolvesProvider.stub :api_key_available?, false do
        Chat::MODELS.map { |model| model.fetch(:model_id) }.uniq.each do |model_id|
          agent.model_id = model_id

          assert_equal "openrouter", Agents::Sandbox.chaos_provider_for(agent), model_id
          assert_equal model_id, Agents::Sandbox.chaos_model_for(agent), model_id
        end
      end
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

    test "provider environment uses account keys including Moonshot" do
      agent = agents(:research_assistant)
      agent.account.update!(
        use_system_ai_credentials: false,
        anthropic_api_key: "account-anthropic",
        moonshot_api_key: "account-moonshot"
      )

      args = Agents::Sandbox.new(agent).send(:provider_env_args)

      assert_includes args, "ANTHROPIC_API_KEY=account-anthropic"
      assert_includes args, "MOONSHOT_API_KEY=account-moonshot"
      assert_not_includes args, "OPENAI_API_KEY"
    end

  end
end
