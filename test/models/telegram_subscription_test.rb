require "test_helper"

class TelegramSubscriptionTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:personal_account)
    @agent = @account.agents.create!(name: "Sub Agent")
    @user = users(:user_1)
  end

  test "creates valid subscription" do
    sub = @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 12345)
    assert sub.persisted?
  end

  test "enforces uniqueness on agent_id and user_id" do
    @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 111)
    duplicate = @agent.telegram_subscriptions.build(user: @user, telegram_chat_id: 222)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save! }
  end

  test "enforces uniqueness on agent_id and telegram_chat_id" do
    @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 111)
    other_user = users(:existing_user)
    duplicate = @agent.telegram_subscriptions.build(user: other_user, telegram_chat_id: 111)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save! }
  end

  test "active scope excludes blocked subscriptions" do
    active = @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 111)
    blocked = @agent.telegram_subscriptions.create!(user: users(:existing_user), telegram_chat_id: 222, blocked: true)

    results = @agent.telegram_subscriptions.active
    assert_includes results, active
    assert_not_includes results, blocked
  end

  test "mark_blocked! sets blocked flag" do
    sub = @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 111)
    sub.mark_blocked!
    assert sub.reload.blocked?
  end

end
