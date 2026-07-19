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

    job = ConsolidateConversationJob.new
    job.stub(:build_checkpoint_summary, "The user prefers concise Ruby refactoring help.") do
      VCR.use_cassette("jobs/consolidate_conversation_job/extracts_memories") do
        job.perform(@chat)
      end
    end

    @chat.reload

    assert_not_nil @chat.last_consolidated_at
    assert_equal @chat.messages.order(:created_at, :id).last.id, @chat.last_consolidated_message_id
    assert_equal "The user prefers concise Ruby refactoring help.", @chat.checkpoint_summary
    assert @agent.memories.journal.where("content ILIKE ?", "%concise%").exists?
    assert @agent.memories.core.where("content ILIKE ?", "%Ruby%").exists?
  end

  test "over-budget conversations consolidate even while recently active" do
    regular_chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "Large regular chat",
      manual_responses: false
    )
    message = regular_chat.messages.create!(role: "user", content: "A long active conversation", user: @user)
    job = ConsolidateConversationJob.new

    ENV.stub(:fetch, ->(key, default = nil) { key == "HELIX_TRANSCRIPT_BUDGET_TOKENS" ? "1" : ENV[key] || default }) do
      job.stub(:build_checkpoint_summary, "A compact checkpoint.") do
        job.perform(regular_chat)
      end
    end

    regular_chat.reload
    assert_equal message.id, regular_chat.last_consolidated_message_id
    assert_equal "A compact checkpoint.", regular_chat.checkpoint_summary
  end

  test "checkpoint consolidation reduces the transcript sent on the next turn" do
    @agent.update!(prompt_cache_layout_v2: true)
    10.times do |index|
      @chat.messages.create!(
        role: "user",
        content: "Historical #{index}: " + ("expensive transcript material " * 100),
        user: @user
      )
    end
    20.times do |index|
      @chat.messages.create!(role: "user", content: "Recent #{index}", user: @user)
    end

    @chat.build_context_for_agent(@agent, provider: :openai)
    before_bytes = @chat.prompt_layout_telemetry[:transcript_prompt_bytes]
    job = ConsolidateConversationJob.new

    ENV.stub(:fetch, ->(key, default = nil) { key == "HELIX_TRANSCRIPT_BUDGET_TOKENS" ? "1" : ENV[key] || default }) do
      job.stub(:build_checkpoint_summary, "The historical exchange established a durable plan.") do
        job.stub(:extract_memories_for_agent, nil) do
          job.perform(@chat)
        end
      end
    end

    @chat.reload.build_context_for_agent(@agent, provider: :openai)
    after_bytes = @chat.prompt_layout_telemetry[:transcript_prompt_bytes]

    assert_operator after_bytes, :<, before_bytes / 2
    assert_includes @chat.build_context_for_agent(@agent, provider: :openai)
      .map { |message| message[:content].to_s }.join("\n"), "durable plan"
  end

  test "does not advance the checkpoint boundary when summary generation fails" do
    job = ConsolidateConversationJob.new

    job.stub(:build_checkpoint_summary, nil) do
      job.perform(@chat)
    end

    @chat.reload
    assert_nil @chat.last_consolidated_message_id
    assert_nil @chat.checkpoint_summary
    assert_equal 0, @agent.memories.count
  end

  test "checkpoint prompt carries the previous checkpoint forward" do
    @chat.update!(checkpoint_summary: "Earlier, the user chose PostgreSQL.")
    new_message = @chat.messages.create!(role: "user", content: "Now use JSONB for metadata.", user: @user)

    prompt = ConsolidateConversationJob.new.send(:checkpoint_prompt, @chat, [ new_message ])

    assert_includes prompt, "Earlier, the user chose PostgreSQL."
    assert_includes prompt, "Now use JSONB for metadata."
    assert_includes prompt, "Preserve decisions, commitments, durable preferences"
  end

  test "persisted checkpoint remains byte-stable when there are no new messages" do
    last_message = @chat.messages.order(:created_at, :id).last
    @chat.update!(
      checkpoint_summary: "Stable checkpoint bytes.",
      last_consolidated_at: 1.hour.ago,
      last_consolidated_message_id: last_message.id
    )

    ConsolidateConversationJob.perform_now(@chat)

    assert_equal "Stable checkpoint bytes.", @chat.reload.checkpoint_summary
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
