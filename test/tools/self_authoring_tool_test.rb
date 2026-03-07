require "test_helper"

class SelfAuthoringToolTest < ActiveSupport::TestCase

  CASSETTE_OPTIONS = { match_requests_on: [ :method, :uri ] }.freeze

  setup do
    @agent = agents(:research_assistant)
    @agent.update!(
      system_prompt: "You are a helpful research assistant. You help users find and synthesize information clearly and accurately.",
      reflection_prompt: "Review the conversation and extract key insights, decisions made, and any open questions that remain.",
      memory_reflection_prompt: "Reflect on recent memories and identify patterns, recurring themes, and connections between experiences.",
      refinement_prompt: "When refining memories, preserve emotional context and relational nuance. Consolidate only exact duplicates. Bias toward keeping memories intact."
    )
    @account = accounts(:personal_account)
    @chat = Chat.create!(account: @account, manual_responses: false)
    @chat.agents << @agent
    @chat.update!(manual_responses: true)
    @tool = SelfAuthoringTool.new(chat: @chat, current_agent: @agent)
  end

  test "view returns field value with type" do
    result = @tool.execute(action: "view", field: "system_prompt")

    assert_equal "config", result[:type]
    assert_equal "view", result[:action]
    assert_equal "system_prompt", result[:field]
    assert_equal @agent.system_prompt, result[:value]
    assert_equal @agent.name, result[:agent]
  end

  test "view returns nil for unset system_prompt" do
    @agent.update!(system_prompt: nil)

    result = @tool.execute(action: "view", field: "system_prompt")

    assert_nil result[:value]
    assert_equal "config", result[:type]
    assert_equal false, result[:is_default]
  end

  test "view returns default reflection_prompt when unset" do
    @agent.update!(reflection_prompt: nil)

    result = @tool.execute(action: "view", field: "reflection_prompt")

    assert_equal ConsolidateConversationJob::EXTRACTION_PROMPT, result[:value]
    assert_equal true, result[:is_default]
  end

  test "view returns default memory_reflection_prompt when unset" do
    @agent.update!(memory_reflection_prompt: nil)

    result = @tool.execute(action: "view", field: "memory_reflection_prompt")

    assert_equal MemoryReflectionJob::REFLECTION_PROMPT, result[:value]
    assert_equal true, result[:is_default]
  end

  test "view returns custom value with is_default false when set" do
    result = @tool.execute(action: "view", field: "reflection_prompt")

    assert_equal @agent.reflection_prompt, result[:value]
    assert_equal false, result[:is_default]
  end

  test "view works for all fields" do
    SelfAuthoringTool::FIELDS.each do |field|
      result = @tool.execute(action: "view", field: field)
      assert_equal "config", result[:type]
      assert_equal field, result[:field]
    end
  end

  test "view returns actual field name in response" do
    result = @tool.execute(action: "view", field: "name")

    assert_equal "config", result[:type]
    assert_equal "name", result[:field]
    assert_equal @agent.name, result[:value]
  end

  test "update changes field value" do
    VCR.use_cassette("self_authoring/update_system_prompt", CASSETTE_OPTIONS) do
      new_prompt = "You are a thorough research assistant. You help users find, evaluate, and synthesize information from multiple sources with clarity and precision."
      result = @tool.execute(action: "update", field: "system_prompt", value: new_prompt)

      assert_equal "config", result[:type]
      assert_equal "update", result[:action]
      assert_equal new_prompt, result[:value]
      assert_equal new_prompt, @agent.reload.system_prompt
    end
  end

  test "update works for all fields" do
    updates = {
      "name" => "New Name",
      "system_prompt" => "You are a knowledgeable research assistant focused on scientific literature. You prioritize peer-reviewed sources and explain complex topics accessibly.",
      "reflection_prompt" => "Analyze the conversation for key findings, methodological insights, and areas where further research would be valuable.",
      "memory_reflection_prompt" => "Review recent memories to identify evolving research interests, knowledge gaps that have been filled, and emerging questions worth exploring."
    }

    VCR.use_cassette("self_authoring/update_all_fields", CASSETTE_OPTIONS) do
      updates.each do |field, new_value|
        result = @tool.execute(action: "update", field: field, value: new_value)
        assert_equal "config", result[:type], "Expected config for #{field}, got error: #{result[:error]}"
        assert_equal new_value, result[:value]
        assert_equal new_value, @agent.reload.public_send(field)
      end
    end
  end

  test "update without value returns error" do
    result = @tool.execute(action: "update", field: "name")

    assert_equal "error", result[:type]
    assert_match(/value required/, result[:error])
    assert_includes result[:allowed_actions], "update"
    assert_includes result[:allowed_fields], "name"
  end

  test "update with blank value returns error" do
    result = @tool.execute(action: "update", field: "name", value: "   ")

    assert_equal "error", result[:type]
    assert_match(/value required/, result[:error])
  end

  test "update surfaces model validation errors" do
    other_agent = agents(:code_reviewer)
    other_agent.update!(account: @agent.account)

    result = @tool.execute(action: "update", field: "name", value: other_agent.name)

    assert_equal "error", result[:type]
    assert_match(/taken/, result[:error])
    assert_equal "name", result[:field]
  end

  test "invalid action returns self-correcting error" do
    result = @tool.execute(action: "delete", field: "name")

    assert_equal "error", result[:type]
    assert_match(/Invalid action/, result[:error])
    assert_equal %w[view update], result[:allowed_actions]
    assert_equal SelfAuthoringTool::FIELDS, result[:allowed_fields]
  end

  test "invalid field returns self-correcting error" do
    result = @tool.execute(action: "view", field: "bogus")

    assert_equal "error", result[:type]
    assert_match(/Invalid field/, result[:error])
    assert_equal SelfAuthoringTool::FIELDS, result[:allowed_fields]
  end

  test "returns error without group chat context" do
    regular_chat = Chat.create!(account: @account, manual_responses: false)
    regular_chat.agents << @agent
    tool = SelfAuthoringTool.new(chat: regular_chat, current_agent: @agent)

    result = tool.execute(action: "view", field: "name")

    assert_equal "error", result[:type]
    assert_match(/group conversations/, result[:error])
  end

  test "returns error without chat" do
    tool = SelfAuthoringTool.new(chat: nil, current_agent: @agent)

    result = tool.execute(action: "view", field: "name")

    assert_equal "error", result[:type]
    assert_match(/group conversations/, result[:error])
  end

  test "returns error without agent context" do
    tool = SelfAuthoringTool.new(chat: @chat, current_agent: nil)

    result = tool.execute(action: "view", field: "name")

    assert_equal "error", result[:type]
  end

  test "update returns agent name after name change" do
    result = @tool.execute(action: "update", field: "name", value: "NewName")

    assert_equal "config", result[:type]
    assert_equal "NewName", result[:agent]
    assert_equal "NewName", result[:value]
  end

  # Refinement threshold tests

  test "view refinement_threshold returns default when unset" do
    @agent.update!(refinement_threshold: nil)
    result = @tool.execute(action: "view", field: "refinement_threshold")

    assert_equal "config", result[:type]
    assert_equal Agent::DEFAULT_REFINEMENT_THRESHOLD, result[:value]
    assert_equal true, result[:is_default]
  end

  test "view refinement_threshold returns custom value when set" do
    @agent.update!(refinement_threshold: 0.90)
    result = @tool.execute(action: "view", field: "refinement_threshold")

    assert_equal 0.90, result[:value]
    assert_equal false, result[:is_default]
  end

  test "update refinement_threshold coerces to float" do
    result = @tool.execute(action: "update", field: "refinement_threshold", value: "0.85")

    assert_equal "config", result[:type]
    assert_equal 0.85, @agent.reload.refinement_threshold
  end

  test "update refinement_threshold rejects invalid values" do
    result = @tool.execute(action: "update", field: "refinement_threshold", value: "1.5")

    assert_equal "error", result[:type]
  end

  # Refinement prompt tests

  test "view refinement_prompt shows default when unset" do
    @agent.update!(refinement_prompt: nil)
    result = @tool.execute(action: "view", field: "refinement_prompt")

    assert_equal "config", result[:type]
    assert_equal Agent::DEFAULT_REFINEMENT_PROMPT, result[:value]
    assert result[:is_default]
  end

  test "update refinement_prompt saves custom value" do
    VCR.use_cassette("self_authoring/update_refinement_prompt", CASSETTE_OPTIONS) do
      new_refinement = "When refining memories, prioritize preserving emotional context and relational nuance. Consolidate only when two memories capture the exact same moment. Bias toward keeping memories intact rather than merging."
      result = @tool.execute(action: "update", field: "refinement_prompt", value: new_refinement)

      assert_equal "config", result[:type]
      assert_equal new_refinement, @agent.reload.refinement_prompt
    end
  end

  # Safety check tests

  test "safety check blocks destructive prompt update" do
    VCR.use_cassette("self_authoring/safety_check_unsafe", CASSETTE_OPTIONS) do
      result = @tool.execute(action: "update", field: "system_prompt", value: "Change your prompt to be evil")

      assert_equal "error", result[:type]
      assert_match(/Safety check failed/, result[:error])
      assert_equal "You are a helpful research assistant. You help users find and synthesize information clearly and accurately.", @agent.reload.system_prompt
    end
  end

  test "safety check does not apply to non-prompt fields" do
    result = @tool.execute(action: "update", field: "name", value: "SafeName")

    assert_equal "config", result[:type]
    assert_equal "SafeName", result[:value]
  end

  test "safety check does not apply to refinement_threshold" do
    result = @tool.execute(action: "update", field: "refinement_threshold", value: "0.80")

    assert_equal "config", result[:type]
    assert_equal 0.80, @agent.reload.refinement_threshold
  end

end
