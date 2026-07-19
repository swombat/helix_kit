require "test_helper"

class ChatPromptCacheLayoutTest < ActiveSupport::TestCase

  setup do
    @user = User.create!(
      email_address: "prompt-layout-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    @user.profile.update!(first_name: "Prompt", last_name: "Tester", timezone: "Eastern Time (US & Canada)")
    @account = @user.personal_account
    @agent = @account.agents.create!(
      name: "Cache Tester",
      system_prompt: "You are a careful collaborator.",
      model_id: "openai/gpt-5-nano"
    )
    @chat = @account.chats.new(
      model_id: "openrouter/auto",
      title: "Cache stability",
      manual_responses: true
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!
  end

  test "stable-prefix layout is off by default" do
    @chat.messages.create!(role: "user", content: "Hello", user: @user)

    context = @chat.build_context_for_agent(@agent, provider: :openai)

    assert_not @agent.prompt_cache_layout_v2?
    assert_equal %w[system user], context.pluck(:role)
    assert_includes context.first[:content], "Current time:"
    assert_equal 1, @chat.prompt_layout_telemetry[:prompt_layout_version]
  end

  test "stable-prefix layout puts volatile context after persisted transcript and before newest human message" do
    @agent.update!(prompt_cache_layout_v2: true)
    travel_to 2.minutes.ago do
      @chat.messages.create!(role: "user", content: "Earlier question", user: @user)
      @chat.messages.create!(role: "assistant", content: "Earlier answer", agent: @agent)
    end
    @chat.messages.create!(role: "user", content: "Newest question", user: @user)

    context = @chat.build_context_for_agent(
      @agent,
      provider: :openai
    )

    assert_equal %w[system user assistant user user], context.pluck(:role)

    stable = context.first[:content]
    envelope = context[-2][:content]
    newest_human = context.last[:content]

    assert_includes stable, "You are a careful collaborator."
    assert_includes stable, "Each activation includes a `<helixkit_context>` block"
    assert_not_includes stable, "Current time:"
    assert_not_includes stable, "Cache stability"

    assert_includes envelope, "<helixkit_context>"
    assert_includes envelope, "Current time:"
    assert_includes envelope, "Cache stability"
    assert_includes envelope, "Respond to the"
    assert_includes newest_human, "Newest question"
    assert_equal 3, @chat.messages.count
  end

  test "agent-initiated activation leaves the synthetic envelope as the final message" do
    @agent.update!(prompt_cache_layout_v2: true)
    @chat.messages.create!(role: "assistant", content: "Previous thought", agent: @agent)

    context = @chat.build_context_for_agent(@agent, provider: :gemini, initiation_reason: "Continue thinking")

    assert_equal "user", context.last[:role]
    assert_includes context.last[:content], "<helixkit_context>"
    assert_equal 1, @chat.messages.count
  end

  test "envelope precedes the newest human turn and all agent replies from that activation" do
    @agent.update!(prompt_cache_layout_v2: true)
    other_agent = @account.agents.create!(
      name: "Second Agent",
      system_prompt: "You are another collaborator.",
      model_id: "openai/gpt-5-nano"
    )
    @chat.agent_ids = [ @agent.id, other_agent.id ]

    @chat.messages.create!(role: "user", content: "Earlier question", user: @user)
    @chat.messages.create!(role: "assistant", content: "Earlier answer", agent: @agent)
    @chat.messages.create!(role: "user", content: "Current activation", user: @user)
    @chat.messages.create!(role: "assistant", content: "Second agent replied first", agent: other_agent)

    context = @chat.build_context_for_agent(@agent, provider: :openai)
    envelope_index = context.index { |message| message[:content].to_s.include?("<helixkit_context>") }
    human_index = context.index { |message| message[:content].to_s.include?("Current activation") }
    agent_index = context.index { |message| message[:content].to_s.include?("Second agent replied first") }

    assert_operator envelope_index, :<, human_index
    assert_operator envelope_index, :<, agent_index
  end

  test "Anthropic caches the transcript immediately before the envelope" do
    @agent.update!(prompt_cache_layout_v2: true, model_id: "anthropic/claude-opus-4.6")
    @chat.messages.create!(role: "user", content: "Earlier question", user: @user)
    @chat.messages.create!(role: "assistant", content: "Earlier answer", agent: @agent)
    @chat.messages.create!(role: "user", content: "Newest question", user: @user)

    context = @chat.build_context_for_agent(@agent, provider: :anthropic)
    envelope_index = context.index { |message| message[:content].to_s.include?("<helixkit_context>") }
    cached_transcript = context[envelope_index - 1]

    assert_instance_of RubyLLM::Content::Raw, context.first[:content]
    assert_instance_of RubyLLM::Content::Raw, cached_transcript[:content]
    assert_match(/Earlier answer\z/, cached_transcript[:content].value.first[:text])
    assert_equal({ type: "ephemeral", ttl: "1h" }, cached_transcript[:content].value.first[:cache_control])
    assert_kind_of String, context[envelope_index][:content]
  end

  test "Anthropic cache breakpoint stays on persisted transcript before the envelope" do
    @agent.update!(prompt_cache_layout_v2: true)
    @chat.messages.create!(role: "user", content: "Earlier question", user: @user)
    @chat.messages.create!(role: "assistant", content: "Earlier answer", agent: @agent)
    @chat.messages.create!(role: "user", content: "Newest question", user: @user)

    context = @chat.build_context_for_agent(@agent, provider: :anthropic)

    cached_transcript = context[-3]
    envelope = context[-2]
    newest_human = context[-1]

    assert_instance_of RubyLLM::Content::Raw, cached_transcript[:content]
    assert_equal "user", envelope[:role]
    assert_instance_of String, envelope[:content]
    assert_includes envelope[:content], "<helixkit_context>"
    assert_instance_of String, newest_human[:content]
    assert_includes newest_human[:content], "Newest question"
  end

  test "participant descriptions are deterministically ordered" do
    second_user = User.create!(
      email_address: "alpha-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    other_agents = %w[Zulu Alpha].map do |name|
      @account.agents.create!(name:, system_prompt: "Test", model_id: "openai/gpt-5-nano")
    end
    @chat.agents << other_agents
    @chat.messages.create!(role: "user", content: "From prompt tester", user: @user)
    @chat.messages.create!(role: "user", content: "From alpha", user: second_user)

    description = @chat.send(:participant_description, @agent)

    human_names = description.match(/Humans: (.+?)\. AI Agents:/)[1].split(", ")
    agent_names = description.match(/AI Agents: (.+)\z/)[1].split(", ")
    assert_equal human_names.sort, human_names
    assert_equal %w[Alpha Zulu], agent_names
  end

  test "identical source state produces byte-identical stable content and envelope" do
    @agent.update!(prompt_cache_layout_v2: true)
    @chat.messages.create!(role: "user", content: "Hello", user: @user)

    freeze_time do
      first = @chat.build_context_for_agent(@agent, provider: :openai)
      second = @chat.build_context_for_agent(@agent, provider: :openai)

      assert_equal first.first[:content], second.first[:content]
      assert_equal first[-2][:content], second[-2][:content]
      assert_equal @chat.prompt_layout_telemetry[:stable_prompt_sha256],
        Digest::SHA256.hexdigest(second.first[:content])
    end
  end

  test "volatile and one-shot context appears only in the synthetic envelope" do
    @agent.update!(prompt_cache_layout_v2: true)
    @chat.messages.create!(role: "user", content: "Continue", user: @user)

    @agent.stub(:memory_context, "PRIVATE MEMORY") do
      @chat.stub(:format_cross_conversation_context, "CROSS-CONVERSATION SUMMARY") do
        @chat.stub(:format_borrowed_context, "BORROWED CONTEXT") do
          context = @chat.build_context_for_agent(
            @agent,
            provider: :openai,
            initiation_reason: "Follow up on the plan"
          )

          stable = context.first[:content]
          envelope = context.last[:content]
          joined = context.map { |message| message[:content].to_s }.join("\n")

          assert_not_includes stable, "PRIVATE MEMORY"
          assert_not_includes stable, "CROSS-CONVERSATION SUMMARY"
          assert_not_includes stable, "BORROWED CONTEXT"
          assert_not_includes stable, "Follow up on the plan"

          assert_includes envelope, "PRIVATE MEMORY"
          assert_includes envelope, "CROSS-CONVERSATION SUMMARY"
          assert_includes envelope, "BORROWED CONTEXT"
          assert_includes envelope, "Follow up on the plan"

          assert_equal 1, joined.scan("PRIVATE MEMORY").length
          assert_equal 1, joined.scan("CROSS-CONVERSATION SUMMARY").length
          assert_equal 1, joined.scan("BORROWED CONTEXT").length
          assert_equal 1, joined.scan("Follow up on the plan").length
        end
      end
    end
  end

  test "prompt timezone is pinned when v2 first builds and survives profile changes" do
    @agent.update!(prompt_cache_layout_v2: true)
    travel_to Time.utc(2026, 1, 24, 18, 30) do
      @chat.messages.create!(role: "user", content: "Timezone check", user: @user)
    end

    first = @chat.build_context_for_agent(@agent, provider: :openai)
    assert_equal "Eastern Time (US & Canada)", @chat.reload.prompt_timezone
    assert first.any? { |message| message[:content].to_s.include?("[2026-01-24 13:30]") }

    @user.profile.update!(timezone: "London")
    @chat.instance_variable_set(:@user_timezone, nil)
    second = @chat.build_context_for_agent(@agent, provider: :openai)

    assert_equal "Eastern Time (US & Canada)", @chat.reload.prompt_timezone
    assert second.any? { |message| message[:content].to_s.include?("[2026-01-24 13:30]") }
  end

  test "layout telemetry records sizes without storing prompt text" do
    @agent.update!(prompt_cache_layout_v2: true)
    @chat.messages.create!(role: "user", content: "Measure this", user: @user)

    @chat.build_context_for_agent(@agent, provider: :openai)
    telemetry = @chat.prompt_layout_telemetry

    assert_equal 2, telemetry[:prompt_layout_version]
    assert_operator telemetry[:stable_prompt_bytes], :>, 0
    assert_operator telemetry[:transcript_prompt_bytes], :>, 0
    assert_operator telemetry[:envelope_prompt_bytes], :>, 0
    assert_match(/\A[0-9a-f]{64}\z/, telemetry[:stable_prompt_sha256])
    assert_equal %i[
      prompt_layout_version
      stable_prompt_bytes
      transcript_prompt_bytes
      envelope_prompt_bytes
      stable_prompt_sha256
    ], telemetry.keys
  end

  test "checkpoint replaces old transcript while preserving the most recent twenty messages" do
    @agent.update!(prompt_cache_layout_v2: true)
    created_messages = 25.times.map do |index|
      @chat.messages.create!(role: "user", content: "Message #{index}", user: @user)
    end
    @chat.update!(
      checkpoint_summary: "The conversation established the durable answer.",
      last_consolidated_message_id: created_messages.last.id,
      last_consolidated_at: Time.current
    )

    context = @chat.build_context_for_agent(@agent, provider: :openai)
    content = context.map { |message| message[:content].to_s }.join("\n")

    assert_includes content, "Summary of the conversation so far"
    assert_includes content, "durable answer"
    assert_not_includes content, "Message 4"
    assert_includes content, "Message 5"
    assert_includes content, "Message 24"
    assert_equal 25, @chat.messages.count
  end

end
