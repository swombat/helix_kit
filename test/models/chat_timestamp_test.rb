require "test_helper"

class ChatTimestampTest < ActiveSupport::TestCase

  setup do
    @user = User.create!(
      email_address: "timestamp_test#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    @user.profile.update!(first_name: "Test", last_name: "User")
    @account = @user.personal_account

    @agent = @account.agents.create!(
      name: "Test Agent",
      system_prompt: "You are a helpful assistant.",
      model_id: "openrouter/auto"
    )

    @chat = Chat.create!(account: @account, manual_responses: true, agent_ids: [ @agent.id ])
  end

  test "user_timezone returns user's timezone when set" do
    @user.profile.update!(timezone: "Eastern Time (US & Canada)")
    @chat.messages.create!(role: "user", content: "Hello", user: @user)

    assert_equal "Eastern Time (US & Canada)", @chat.send(:user_timezone).name
  end

  test "user_timezone falls back to UTC when no timezone set" do
    @user.profile.update!(timezone: nil)
    @chat.messages.create!(role: "user", content: "Hello", user: @user)

    assert_equal "UTC", @chat.send(:user_timezone).name
  end

  test "user_timezone falls back to UTC when no human messages" do
    assert_equal "UTC", @chat.send(:user_timezone).name
  end

  test "user_timezone uses most recent human message's user timezone" do
    # Create first message with one timezone
    @user.profile.update!(timezone: "Eastern Time (US & Canada)")
    travel_to 2.hours.ago do
      @chat.messages.create!(role: "user", content: "Earlier message", user: @user)
    end

    # Clear memoization
    @chat.instance_variable_set(:@user_timezone, nil)
    assert_equal "Eastern Time (US & Canada)", @chat.send(:user_timezone).name

    # Now user changes timezone and sends another message
    @user.profile.update!(timezone: "London")
    @chat.messages.create!(role: "user", content: "Later message", user: @user)

    # Clear memoization again
    @chat.instance_variable_set(:@user_timezone, nil)

    # Should still use the same user's timezone (now London)
    assert_equal "London", @chat.send(:user_timezone).name
  end

  test "system_message_for includes current time" do
    system_msg = @chat.send(:system_message_for, @agent)
    assert_match(/Current time: \w+, \d{4}-\d{2}-\d{2} \d{2}:\d{2} \w+/, system_msg[:content])
  end

  test "system_message_for uses user timezone for current time" do
    @user.profile.update!(timezone: "Eastern Time (US & Canada)")
    @chat.messages.create!(role: "user", content: "Hello", user: @user)

    # Clear memoized timezone
    @chat.instance_variable_set(:@user_timezone, nil)

    system_msg = @chat.send(:system_message_for, @agent)

    # The timezone abbreviation should be in the output (EST or EDT depending on time of year)
    assert_match(/Current time: \w+, \d{4}-\d{2}-\d{2} \d{2}:\d{2} (EST|EDT)/, system_msg[:content])
  end

  test "format_message_for_context prepends timestamp to user messages" do
    message = @chat.messages.create!(role: "user", content: "Hello world", user: @user)
    tz = ActiveSupport::TimeZone["UTC"]

    formatted = @chat.send(:format_message_for_context, message, @agent, tz)

    assert_match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}\] \[.+\]: Hello world/, formatted[:content])
  end

  test "format_message_for_context prepends timestamp to agent messages" do
    message = @chat.messages.create!(role: "assistant", content: "Hi there", agent: @agent)
    tz = ActiveSupport::TimeZone["UTC"]

    formatted = @chat.send(:format_message_for_context, message, @agent, tz)

    # Agent's own messages don't have the name prefix, just the timestamp
    assert_match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}\] Hi there/, formatted[:content])
  end

  test "format_message_for_context prepends timestamp to other agent messages" do
    other_agent = @account.agents.create!(
      name: "Other Agent",
      system_prompt: "You are another assistant.",
      model_id: "openrouter/auto"
    )
    @chat.agents << other_agent

    message = @chat.messages.create!(role: "assistant", content: "Hello from other", agent: other_agent)
    tz = ActiveSupport::TimeZone["UTC"]

    formatted = @chat.send(:format_message_for_context, message, @agent, tz)

    # Other agent's messages should have the agent name prefix
    assert_match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}\] \[Other Agent\]: Hello from other/, formatted[:content])
  end

  test "messages_context_for includes timestamps on all messages" do
    @chat.messages.create!(role: "user", content: "Question", user: @user)
    @chat.messages.create!(role: "assistant", content: "Answer", agent: @agent)

    context = @chat.send(:messages_context_for, @agent)

    assert_equal 2, context.length
    context.each do |msg|
      assert_match(/^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}\]/, msg[:content].to_s)
    end
  end

  test "timestamps use correct timezone conversion" do
    @user.profile.update!(timezone: "Eastern Time (US & Canada)")
    # Create a message at a specific UTC time
    travel_to Time.utc(2026, 1, 24, 18, 30, 0) do
      @chat.messages.create!(role: "user", content: "Test message", user: @user)
    end

    # Clear memoized timezone
    @chat.instance_variable_set(:@user_timezone, nil)

    context = @chat.send(:messages_context_for, @agent)

    # 18:30 UTC on Jan 24 should be 13:30 EST (UTC-5)
    assert_match(/\[2026-01-24 13:30\]/, context.first[:content].to_s)
  end

end
