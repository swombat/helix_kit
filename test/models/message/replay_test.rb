require "test_helper"

class Message::ReplayTest < ActiveSupport::TestCase

  setup do
    @user = User.create!(email_address: "rep-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @user.profile.update!(first_name: "Rep", last_name: "Player")
    @account = @user.personal_account
    @opus = @account.agents.create!(name: "Opus", model_id: "anthropic/claude-opus-4.5", system_prompt: "You are Opus.")
    @sonnet = @account.agents.create!(name: "Sonnet", model_id: "anthropic/claude-sonnet-4.5", system_prompt: "You are Sonnet.")
    @chat = @account.chats.new(model_id: "openrouter/auto", manual_responses: true, title: "Replay Test")
    @chat.agents = [ @opus, @sonnet ]
    @chat.save!
  end

  test "Anthropic same agent with signed thinking returns thinking block" do
    msg = @chat.messages.create!(
      role: "assistant", agent: @opus,
      content: "Thoughtful answer.",
      thinking: "Inner monologue.",
      replay_payload: { "provider" => "anthropic", "thinking" => { "text" => "Inner monologue.", "signature" => "sig-xyz" } }
    )

    replay = msg.replay_for(:anthropic, current_agent: @opus)
    assert_equal :assistant, replay[:role]
    assert_equal "Thoughtful answer.", replay[:content]
    assert_kind_of RubyLLM::Thinking, replay[:thinking]
    assert_equal "Inner monologue.", replay[:thinking].text
    assert_equal "sig-xyz", replay[:thinking].signature
  end

  test "Anthropic same agent legacy unsigned returns assistant text only and infers legacy_no_signature" do
    msg = @chat.messages.create!(
      role: "assistant", agent: @opus,
      content: "Old answer.",
      thinking: "Old thinking without signature."
    )

    replay = msg.replay_for(:anthropic, current_agent: @opus)
    assert_equal :assistant, replay[:role]
    assert_equal "Old answer.", replay[:content]
    assert_nil replay[:thinking]
    assert_equal "legacy_no_signature", msg.reasoning_skip_reason
  end

  test "Anthropic other agent returns user-shaped with [Name]: prefix" do
    msg = @chat.messages.create!(role: "assistant", agent: @sonnet, content: "Sonnet's reply.")

    replay = msg.replay_for(:anthropic, current_agent: @opus)
    assert_equal :user, replay[:role]
    assert_equal "[Sonnet]: Sonnet's reply.", replay[:content]
  end

  test "OpenRouter same agent with no replay_payload returns assistant text only" do
    msg = @chat.messages.create!(role: "assistant", agent: @opus, content: "Plain reply.")

    replay = msg.replay_for(:openrouter, current_agent: @opus)
    assert_equal({ role: :assistant, content: "Plain reply." }, replay)
    assert_nil msg.reasoning_skip_reason
  end

  test "OpenRouter same agent with reasoning_details includes them" do
    details = [ { "type" => "reasoning.text", "text" => "step 1" } ]
    msg = @chat.messages.create!(
      role: "assistant", agent: @opus, content: "Reasoned reply.",
      replay_payload: { "provider" => "openrouter", "reasoning_details" => details }
    )

    replay = msg.replay_for(:openrouter, current_agent: @opus)
    assert_equal :assistant, replay[:role]
    assert_equal "Reasoned reply.", replay[:content]
    assert_equal details, replay[:reasoning_details]
  end

  test "Gemini same agent with tool call signature serializes signature" do
    msg = @chat.messages.create!(role: "assistant", agent: @opus, content: "Used tool.")
    msg.tool_calls.create!(
      tool_call_id: "tc1", name: "WebTool", arguments: { url: "https://example.com" },
      replay_payload: { "provider" => "gemini", "thought_signature" => "tc-sig-1" }
    )

    replay = msg.replay_for(:gemini, current_agent: @opus)
    assert_equal 1, replay[:tool_calls].size
    entry = replay[:tool_calls]["tc1"]
    assert_kind_of RubyLLM::ToolCall, entry
    assert_equal "tc1", entry.id
    assert_equal "WebTool", entry.name
    assert_equal "tc-sig-1", entry.thought_signature
  end

  test "Gemini same agent with tool call missing signature serializes without thought_signature" do
    msg = @chat.messages.create!(role: "assistant", agent: @opus, content: "Used tool legacy.")
    msg.tool_calls.create!(tool_call_id: "tc-legacy", name: "WebTool", arguments: { url: "https://example.com" }, replay_payload: nil)

    replay = msg.replay_for(:gemini, current_agent: @opus)
    entry = replay[:tool_calls]["tc-legacy"]
    assert_equal "tc-legacy", entry.id
    assert_nil entry.thought_signature, "should not fabricate a thought_signature"
  end

  test "ten legacy unsigned Anthropic turns build context with no thinking blocks; new turn has thinking enabled" do
    @chat.messages.create!(role: "user", user: @user, content: "Hi")
    10.times do |i|
      @chat.messages.create!(
        role: "assistant", agent: @opus,
        content: "Reply #{i}",
        thinking: "Old thinking #{i}"
      )
    end

    context = @chat.build_context_for_agent(@opus, thinking_enabled: true, provider: :anthropic)

    assistant_entries = context.select { |c| c[:role] == "assistant" }
    assert_equal 10, assistant_entries.size
    assistant_entries.each do |entry|
      assert_nil entry[:thinking]
    end
  end

end
