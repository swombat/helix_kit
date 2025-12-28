require "test_helper"
require "ostruct"

class ConsolidateConversationJobTest < ActiveJob::TestCase

  setup do
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)
    @user = users(:user_1)

    # Create a group chat with an agent
    @chat = @account.chats.new(
      model_id: "openrouter/auto",
      title: "Test Group Chat",
      manual_responses: true
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!

    # Create some messages older than 6 hours
    travel_to 7.hours.ago do
      @chat.messages.create!(role: "user", content: "Hello agent!", user: @user)
      @chat.messages.create!(role: "assistant", content: "Hello! I'm happy to help.", agent: @agent)
    end
    travel_back
  end

  test "skips non-group chats" do
    regular_chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "Regular Chat",
      manual_responses: false
    )

    travel_to 7.hours.ago do
      regular_chat.messages.create!(role: "user", content: "Hello", user: @user)
    end
    travel_back

    ConsolidateConversationJob.perform_now(regular_chat)

    assert_equal 0, @agent.memories.count
  end

  test "skips recently active conversations" do
    @chat.messages.create!(role: "user", content: "New message", user: @user)

    ConsolidateConversationJob.perform_now(@chat)

    assert_equal 0, @agent.memories.count
  end

  test "extracts memories using agent's own model" do
    extraction_response = { "journal" => [ "User prefers concise responses" ], "core" => [] }

    model_used = nil
    stub_extraction(extraction_response, capture_model: ->(m) { model_used = m }) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    assert_equal @agent.model_id, model_used, "Should use agent's model"
    assert_equal 1, @agent.memories.journal.count
    assert_includes @agent.memories.journal.first.content, "concise responses"
  end

  test "creates both journal and core memories" do
    extraction_response = {
      "journal" => [ "User is working on a Ruby project" ],
      "core" => [ "I value helping developers" ]
    }

    stub_extraction(extraction_response) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    assert_equal 1, @agent.memories.journal.count
    assert_equal 1, @agent.memories.core.count
    assert_includes @agent.memories.journal.first.content, "Ruby project"
    assert_includes @agent.memories.core.first.content, "helping developers"
  end

  test "tracks last consolidated message" do
    extraction_response = { "journal" => [], "core" => [] }
    message_count_before = @chat.messages.count

    stub_extraction(extraction_response) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    @chat.reload

    # Should have consolidated up to the last message in the chat
    assert_equal message_count_before, @chat.messages.count, "Message count should not change"
    assert_equal @chat.messages.order(:created_at, :id).last.id, @chat.last_consolidated_message_id
    assert_not_nil @chat.last_consolidated_at
  end

  test "only processes new messages on subsequent runs" do
    # First consolidation
    stub_extraction({ "journal" => [ "First observation" ], "core" => [] }) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    # Add new message (7 hours ago to be idle)
    travel_to 7.hours.ago do
      @chat.messages.create!(role: "user", content: "Another message", user: @user)
    end
    travel_back

    # Second consolidation should only process the new message
    prompts_received = []
    stub_extraction({ "journal" => [ "Second observation" ], "core" => [] }, capture_prompt: prompts_received) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    # Should not include old messages
    assert prompts_received.any?
    refute prompts_received.first.include?("Hello agent!"), "Should not include old messages"
    assert prompts_received.first.include?("Another message"), "Should include new message"
  end

  test "includes existing core memories in prompt" do
    # Create existing core memory
    @agent.memories.create!(content: "I am a helpful assistant", memory_type: :core)

    prompts_received = []
    stub_extraction({ "journal" => [], "core" => [] }, capture_prompt: prompts_received) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    assert prompts_received.first.include?("I am a helpful assistant"), "Prompt should include existing core memories"
  end

  test "uses custom reflection_prompt when provided" do
    custom_prompt = "Custom reflection: %{system_prompt}\nExisting: %{existing_memories}\nExtract memories from this."
    @agent.update!(reflection_prompt: custom_prompt)
    @chat.reload # Reload chat to get fresh agent association

    prompts_received = []
    stub_extraction({ "journal" => [], "core" => [] }, capture_prompt: prompts_received) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    # Should include custom prompt content
    assert prompts_received.first.include?("Custom reflection:"), "Should use custom reflection prompt"
    assert prompts_received.first.include?("You are a helpful research assistant"), "Should substitute system_prompt"
    # Should still include JSON format instruction
    assert prompts_received.first.include?("Respond ONLY with valid JSON"), "Should append JSON format instruction"
  end

  test "uses default EXTRACTION_PROMPT when no custom reflection_prompt" do
    @agent.update!(reflection_prompt: nil)
    @chat.reload # Reload chat to get fresh agent association

    prompts_received = []
    stub_extraction({ "journal" => [], "core" => [] }, capture_prompt: prompts_received) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    # Should include default prompt content
    assert prompts_received.first.include?("You are reviewing a conversation"), "Should use default extraction prompt"
    assert prompts_received.first.include?("JOURNAL entries"), "Should include default prompt sections"
    assert prompts_received.first.include?("CORE entries"), "Should include default prompt sections"
    # Should still include JSON format instruction
    assert prompts_received.first.include?("Respond ONLY with valid JSON"), "Should append JSON format instruction"
  end

  test "custom reflection_prompt supports placeholders" do
    @agent.update!(
      system_prompt: "I am a test agent with specific behavior",
      reflection_prompt: "Agent identity: %{system_prompt}\n\nPrevious core: %{existing_memories}"
    )
    @agent.memories.create!(content: "Existing memory 1", memory_type: :core)
    @agent.memories.create!(content: "Existing memory 2", memory_type: :core)
    @chat.reload # Reload chat to get fresh agent association

    prompts_received = []
    stub_extraction({ "journal" => [], "core" => [] }, capture_prompt: prompts_received) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    prompt = prompts_received.first
    assert_includes prompt, "I am a test agent with specific behavior", "Should substitute system_prompt"
    assert_includes prompt, "Existing memory 1", "Should substitute existing_memories"
    assert_includes prompt, "Existing memory 2", "Should substitute existing_memories"
  end

  test "handles JSON parse errors gracefully" do
    stub_extraction_raw("not valid json") do
      ConsolidateConversationJob.perform_now(@chat)
    end

    # Should not create any memories but should still mark as consolidated
    assert_equal 0, @agent.memories.count
    @chat.reload
    assert_not_nil @chat.last_consolidated_at
  end

  test "handles LLM errors gracefully" do
    stub_extraction_error(StandardError.new("API error")) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    # Should not create any memories but should still mark as consolidated
    assert_equal 0, @agent.memories.count
    @chat.reload
    assert_not_nil @chat.last_consolidated_at
  end

  test "processes multiple agents independently" do
    agent2 = agents(:code_reviewer)
    @chat.agents << agent2

    # Different responses for different agents
    call_count = 0
    RubyLLM.stub(:chat, ->(**args) {
      call_count += 1
      response = if args[:model] == @agent.model_id
        { "journal" => [ "Memory for research assistant" ], "core" => [] }
      else
        { "journal" => [ "Memory for code reviewer" ], "core" => [] }
      end
      MockLlm.new(response.to_json)
    }) do
      ConsolidateConversationJob.perform_now(@chat)
    end

    assert_equal 2, call_count, "Should call LLM for each agent"
    assert_equal 1, @agent.memories.journal.count
    assert_equal 1, agent2.memories.journal.count
  end

  private

  def stub_extraction(response, capture_model: nil, capture_prompt: nil, &block)
    RubyLLM.stub(:chat, ->(**args) {
      capture_model&.call(args[:model])
      MockLlm.new(response.to_json, capture_prompt: capture_prompt)
    }, &block)
  end

  def stub_extraction_raw(response, &block)
    RubyLLM.stub(:chat, ->(**_) { MockLlm.new(response) }, &block)
  end

  def stub_extraction_error(error, &block)
    RubyLLM.stub(:chat, ->(**_) { MockLlm.new(nil, raise_error: error) }, &block)
  end

  class MockLlm

    def initialize(response_content, capture_prompt: nil, raise_error: nil)
      @response_content = response_content
      @capture_prompt = capture_prompt
      @raise_error = raise_error
    end

    def ask(prompt)
      raise @raise_error if @raise_error

      @capture_prompt << prompt if @capture_prompt
      OpenStruct.new(content: @response_content)
    end

  end

end
