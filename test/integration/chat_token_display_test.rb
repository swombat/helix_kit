require "test_helper"

class ChatTokenDisplayTest < ActiveSupport::TestCase

  setup do
    @user = User.create!(email_address: "tok-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @user.profile.update!(first_name: "Tok", last_name: "User")
    @account = @user.personal_account
    @chat = @account.chats.create!(model_id: "openrouter/auto", title: "Token Display")
  end

  test "context_tokens reports max input_tokens across last 10 assistant messages" do
    @chat.messages.create!(role: "user", user: @user, content: "Q1", input_tokens: 50)
    @chat.messages.create!(role: "assistant", content: "A1", input_tokens: 1_200, output_tokens: 100)
    @chat.messages.create!(role: "user", user: @user, content: "Q2", input_tokens: 60)
    @chat.messages.create!(role: "assistant", content: "A2", input_tokens: 3_400, output_tokens: 110)

    assert_equal 3_400, @chat.context_tokens
  end

  test "cost_tokens returns per-turn sums with hash shape" do
    @chat.messages.create!(role: "user", user: @user, content: "Q", input_tokens: 50, output_tokens: 0)
    @chat.messages.create!(role: "assistant", content: "A", input_tokens: 200, output_tokens: 90)
    @chat.messages.create!(role: "assistant", content: "B", input_tokens: 100, output_tokens: 60)

    assert_equal({ input: 350, output: 150 }, @chat.cost_tokens)
  end

  test "reasoning_tokens sums thinking_tokens" do
    @chat.messages.create!(role: "assistant", content: "A", thinking_tokens: 250)
    @chat.messages.create!(role: "assistant", content: "B", thinking_tokens: 0)
    @chat.messages.create!(role: "assistant", content: "C", thinking_tokens: 100)

    assert_equal 350, @chat.reasoning_tokens
  end

  test "json includes context_tokens, cost_tokens and reasoning_tokens, not total_tokens" do
    @chat.messages.create!(role: "user", user: @user, content: "Q", input_tokens: 50)
    @chat.messages.create!(role: "assistant", content: "A", input_tokens: 800, output_tokens: 200, thinking_tokens: 60)

    json = @chat.as_json
    assert_includes json.keys, "context_tokens"
    assert_includes json.keys, "cost_tokens"
    assert_includes json.keys, "reasoning_tokens"
    refute_includes json.keys, "total_tokens"

    assert_equal 800, json["context_tokens"]
    assert_equal 60, json["reasoning_tokens"]
  end

  test "sidebar JSON includes context_tokens for hover display but omits cost and reasoning" do
    json = @chat.as_json(as: :sidebar_json)
    assert_includes json.keys, "context_tokens"
    refute_includes json.keys, "cost_tokens"
    refute_includes json.keys, "reasoning_tokens"
    refute_includes json.keys, "total_tokens"
  end

end
