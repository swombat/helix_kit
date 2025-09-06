require "test_helper"

class ChatTest < ActiveSupport::TestCase

  test "belongs to account" do
    chat = chats(:conversation)
    assert_equal accounts(:personal_account), chat.account
  end

  test "has many messages with destroy dependency" do
    chat = chats(:conversation)
    message_ids = chat.messages.pluck(:id)

    assert_not_empty message_ids

    chat.destroy!

    message_ids.each do |id|
      assert_not Message.exists?(id)
    end
  end

  test "validates model_id presence" do
    chat = Chat.new(account: accounts(:personal_account))
    chat.model_id = nil

    assert_not chat.valid?
    assert_includes chat.errors[:model_id], "can't be blank"
  end

  test "defaults model_id to openrouter/auto" do
    chat = Chat.create!(account: accounts(:personal_account))
    assert_equal "openrouter/auto", chat.model_id
  end

  test "schedules title generation job after create when no title" do
    assert_enqueued_with(job: GenerateTitleJob) do
      Chat.create!(account: accounts(:personal_account))
    end
  end

  test "does not schedule title generation when title exists" do
    assert_no_enqueued_jobs(only: GenerateTitleJob) do
      Chat.create!(account: accounts(:personal_account), title: "Existing Title")
    end
  end

  test "includes required concerns" do
    assert Chat.included_modules.include?(Broadcastable)
    assert Chat.included_modules.include?(ObfuscatesId)
  end

  test "acts as chat" do
    chat = chats(:conversation)
    # RubyLLM methods should be available
    assert chat.respond_to?(:ask)
    assert chat.respond_to?(:generate_title)
  end

  test "broadcasts to account" do
    chat = chats(:conversation)
    assert_equal [ :account ], chat.class.broadcast_targets
  end

end
