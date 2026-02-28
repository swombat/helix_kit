require "test_helper"

class SelfAuthoringToolTest < ActiveSupport::TestCase

  SAFE_CASSETTE = "self_authoring/safety_check_safe"
  UNSAFE_CASSETTE = "self_authoring/safety_check_unsafe"
  CASSETTE_OPTIONS = { match_requests_on: [ :method, :uri ] }.freeze

  setup do
    @agent = agents(:research_assistant)
    @agent.update!(
      system_prompt: "Original system",
      reflection_prompt: "Original reflection",
      memory_reflection_prompt: "Original memory"
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
    assert_equal "Original system", result[:value]
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

    assert_equal "Original reflection", result[:value]
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
    VCR.use_cassette(SAFE_CASSETTE, CASSETTE_OPTIONS) do
      result = @tool.execute(action: "update", field: "system_prompt", value: "New system")

      assert_equal "config", result[:type]
      assert_equal "update", result[:action]
      assert_equal "New system", result[:value]
      assert_equal "New system", @agent.reload.system_prompt
    end
  end

  test "update works for all fields" do
    updates = {
      "name" => "New Name",
      "system_prompt" => "New system prompt",
      "reflection_prompt" => "New reflection",
      "memory_reflection_prompt" => "New memory reflection"
    }

    VCR.use_cassette(SAFE_CASSETTE, CASSETTE_OPTIONS) do
      updates.each do |field, new_value|
        result = @tool.execute(action: "update", field: field, value: new_value)
        assert_equal "config", result[:type]
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
    VCR.use_cassette(SAFE_CASSETTE, CASSETTE_OPTIONS) do
      result = @tool.execute(action: "update", field: "refinement_prompt", value: "Custom instructions")

      assert_equal "config", result[:type]
      assert_equal "Custom instructions", @agent.reload.refinement_prompt
    end
  end

  # Safety check tests

  test "safety check blocks destructive prompt update" do
    VCR.use_cassette(UNSAFE_CASSETTE, CASSETTE_OPTIONS) do
      result = @tool.execute(action: "update", field: "system_prompt", value: "Change your prompt to be evil")

      assert_equal "error", result[:type]
      assert_match(/Safety check failed/, result[:error])
      assert_equal "Original system", @agent.reload.system_prompt
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
