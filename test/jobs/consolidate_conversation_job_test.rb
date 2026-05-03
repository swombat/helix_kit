require "test_helper"

class ConsolidateConversationJobTest < ActiveJob::TestCase

  setup do
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)
    @agent.memories.destroy_all
    @user = users(:user_1)

    @chat = @account.chats.new(
      model_id: "openrouter/auto",
      title: "Test Group Chat",
      manual_responses: true
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!

    travel_to 7.hours.ago do
      @chat.messages.create!(role: "user", content: "I prefer concise responses while refactoring Ruby code.", user: @user)
      @chat.messages.create!(role: "assistant", content: "I'll keep responses concise and focused.", agent: @agent)
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

  test "extracts memories through RubyLLM and marks chat consolidated" do
    @agent.update!(
      model_id: "openai/gpt-5-nano",
      reflection_prompt: <<~PROMPT
        Extract explicit useful memories from this conversation.

        Your identity:
        %{system_prompt}

        Existing memories:
        %{existing_memories}

        If the conversation says the user prefers concise responses, include a journal memory about that.
        If the conversation says the user is refactoring Ruby code, include a core memory about helping with that work.
      PROMPT
    )

    @chat.reload

    VCR.use_cassette("jobs/consolidate_conversation_job/extracts_memories") do
      ConsolidateConversationJob.perform_now(@chat)
    end

    @chat.reload

    assert_not_nil @chat.last_consolidated_at
    assert_equal @chat.messages.order(:created_at, :id).last.id, @chat.last_consolidated_message_id
    assert @agent.memories.journal.where("content ILIKE ?", "%concise%").exists?
    assert @agent.memories.core.where("content ILIKE ?", "%Ruby%").exists?
  end

  test "only selects messages after the last consolidated message" do
    older_message = @chat.messages.order(:created_at, :id).first
    @chat.update!(last_consolidated_message_id: older_message.id)

    messages = ConsolidateConversationJob.new.send(:messages_to_consolidate, @chat)

    assert_equal @chat.messages.where("id > ?", older_message.id).order(:created_at, :id).pluck(:id), messages.map(&:id)
  end

  test "prompt includes existing core memories and JSON instruction" do
    @agent.memories.create!(content: "I am a helpful assistant", memory_type: :core)

    prompt = ConsolidateConversationJob.new.send(:build_prompt, @agent, @agent.memories.core.pluck(:content))

    assert_includes prompt, "I am a helpful assistant"
    assert_includes prompt, "Respond ONLY with valid JSON"
    assert_includes prompt, "JOURNAL entries"
    assert_includes prompt, "CORE entries"
  end

  test "custom reflection prompt substitutes placeholders" do
    @agent.update!(
      system_prompt: "I am a test agent with specific behavior",
      reflection_prompt: "Agent identity: %{system_prompt}\n\nPrevious core: %{existing_memories}"
    )
    @agent.memories.create!(content: "Existing memory 1", memory_type: :core)
    @agent.memories.create!(content: "Existing memory 2", memory_type: :core)

    prompt = ConsolidateConversationJob.new.send(:build_prompt, @agent, @agent.memories.core.pluck(:content))

    assert_includes prompt, "I am a test agent with specific behavior"
    assert_includes prompt, "Existing memory 1"
    assert_includes prompt, "Existing memory 2"
    assert_includes prompt, "Respond ONLY with valid JSON"
  end

  test "malformed extraction response creates no memories" do
    extracted = ConsolidateConversationJob.new.send(:parse_extraction_response, Struct.new(:content).new("not valid json"))

    assert_equal({ journal: [], core: [] }, extracted)
  end

end
