require "test_helper"

class ChatTest < ActiveSupport::TestCase

  def setup
    @user = User.create!(
      email_address: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    @user.profile.update!(first_name: "Test", last_name: "User")
    @account = @user.personal_account
  end

  test "belongs to account" do
    chat = Chat.create!(account: @account)
    assert_equal @account, chat.account
  end

  test "has many messages with destroy dependency" do
    chat = Chat.create!(account: @account)
    message = chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )
    message_id = message.id

    chat.destroy!

    assert_not Message.exists?(message_id)
  end

  test "validates model_id presence" do
    chat = Chat.new(account: @account)
    chat.model_id = nil

    assert_not chat.valid?
    assert_includes chat.errors[:model_id], "can't be blank"
  end

  test "defaults model_id to openrouter/auto" do
    chat = Chat.create!(account: @account)
    assert_equal "openrouter/auto", chat.model_id
  end

  test "schedules title generation job after create when no title" do
    assert_enqueued_with(job: GenerateTitleJob) do
      Chat.create!(account: @account)
    end
  end

  test "does not schedule title generation when title exists" do
    assert_no_enqueued_jobs(only: GenerateTitleJob) do
      Chat.create!(account: @account, title: "Existing Title")
    end
  end

  test "includes required concerns" do
    assert Chat.included_modules.include?(Broadcastable)
    assert Chat.included_modules.include?(ObfuscatesId)
  end

  test "acts as chat" do
    chat = Chat.create!(account: @account)
    # RubyLLM methods should be available
    assert chat.respond_to?(:ask)
    # Note: generate_title is not a direct method, it's handled by the job
    assert chat.respond_to?(:to_llm)
  end

  test "broadcasts to account" do
    assert_equal [ :account ], Chat.broadcast_targets
  end

  test "create_with_message! creates chat and message" do
    assert_difference "Chat.count" do
      assert_difference "Message.count" do
        assert_enqueued_with(job: AiResponseJob) do
          @chat = Chat.create_with_message!(
            { model_id: "gpt-4o", account: @account },
            message_content: "Hello AI",
            user: @user
          )
        end
      end
    end

    message = @chat.messages.last
    assert_equal "Hello AI", message.content
    assert_equal "user", message.role
    assert_equal @user, message.user
  end

  test "create_with_message! creates chat without message when content is blank" do
    assert_difference "Chat.count" do
      assert_no_difference "Message.count" do
        assert_no_enqueued_jobs(only: AiResponseJob) do
          @chat = Chat.create_with_message!(
            { model_id: "gpt-4o", account: @account },
            message_content: nil,
            user: @user
          )
        end
      end
    end
  end

  test "title_or_default returns title when present" do
    chat = Chat.create!(account: @account, title: "My Chat")
    assert_equal "My Chat", chat.title_or_default
  end

  test "title_or_default returns default when title is blank" do
    chat = Chat.create!(account: @account)
    assert_equal "New Conversation", chat.title_or_default
  end

  test "ai_model_name returns correct model name" do
    chat = Chat.create!(account: @account, model_id: "openai/gpt-4o-mini")
    assert_equal "GPT-4 Mini", chat.ai_model_name
  end

  test "ai_model_name returns nil for unknown model" do
    chat = Chat.create!(account: @account, model_id: "unknown/model")
    assert_nil chat.ai_model_name
  end

  test "updated_at_formatted returns formatted date" do
    chat = Chat.create!(account: @account)
    # Use a time that accounts for potential timezone differences
    time = Time.parse("2024-01-15 14:30:00 UTC")
    chat.update!(updated_at: time)
    # Test the format without being specific about timezone
    formatted = chat.updated_at_formatted
    assert_includes formatted, "Jan 15 at"
    assert_includes formatted, ":30"
    assert_includes formatted, "M" # AM or PM
  end

  test "updated_at_short returns short date" do
    chat = Chat.create!(account: @account)
    chat.update!(updated_at: Time.new(2024, 1, 15, 14, 30, 0))
    assert_equal "Jan 15", chat.updated_at_short
  end

  test "message_count returns correct count" do
    chat = Chat.create!(account: @account)
    assert_equal 0, chat.message_count

    chat.messages.create!(content: "Test", role: "user", user: @user)
    assert_equal 1, chat.reload.message_count

    chat.messages.create!(content: "Response", role: "assistant")
    assert_equal 2, chat.reload.message_count
  end

  test "as_json returns default format" do
    chat = Chat.create!(account: @account, title: "Test Chat", model_id: "gpt-4o")
    chat.messages.create!(content: "Test", role: "user", user: @user)

    json = chat.as_json

    assert_equal chat.to_param, json[:id]
    assert_equal "Test Chat", json[:title_or_default]
    assert_equal "gpt-4o", json[:model_id]
    assert_nil json[:ai_model_name] # Unknown model
    assert_equal 1, json[:message_count]
    assert json[:updated_at_formatted].present?
  end

  test "as_json returns sidebar format" do
    chat = Chat.create!(account: @account, title: "Sidebar Chat")

    json = chat.as_json(as: :sidebar_json)

    assert_equal chat.to_param, json[:id]
    assert_equal "Sidebar Chat", json[:title_or_default]
    assert json[:updated_at_short].present?

    # Should not include other fields
    assert_nil json[:model_id]
    assert_nil json[:ai_model_name]
    assert_nil json[:message_count]
    assert_nil json[:updated_at_formatted]
  end

end
