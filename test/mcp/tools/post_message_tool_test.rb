require "test_helper"
require "action_mcp/test_helper"

class PostMessageToolTest < ActiveSupport::TestCase

  include ActionMCP::TestHelper

  setup do
    @user = users(:confirmed_user)
    @account = @user.personal_account
    @chat = @account.chats.create!(model_id: "openrouter/auto", title: "MCP Chat")
    ActionMCP::Current.user = @user
  end

  teardown do
    ActionMCP::Current.reset
    Current.reset
  end

  test "is registered" do
    assert_mcp_tool_findable "post_message"
  end

  test "creates a message in an accessible chat" do
    assert_difference "Message.count", 1 do
      @response = execute_mcp_tool(
        "post_message",
        "chat_id" => @chat.to_param,
        "content" => "Hello from MCP"
      )
    end

    message = @chat.messages.order(:created_at).last
    assert_equal @user, message.user
    assert_equal "user", message.role
    assert_equal "Hello from MCP", message.content
    assert_equal [ { type: "text", text: "Posted message #{message.to_param} into chat #{@chat.to_param}" } ],
      @response.contents.map(&:to_h)
  end

  test "reports an error for missing chat" do
    response = execute_mcp_tool_with_error(
      "post_message",
      "chat_id" => "missing",
      "content" => "Hello from MCP"
    )

    assert response.to_h[:isError]
    assert_equal "Chat not found or cannot receive messages", response.contents.first.text
  end

  test "reports an error for unauthorized chat" do
    other_user = users(:existing_user)
    other_chat = other_user.personal_account.chats.create!(model_id: "openrouter/auto", title: "Other")

    response = execute_mcp_tool_with_error(
      "post_message",
      "chat_id" => other_chat.to_param,
      "content" => "Hello from MCP"
    )

    assert response.to_h[:isError]
    assert_equal "Chat not found or cannot receive messages", response.contents.first.text
  end

  test "reports an error for archived chat" do
    @chat.archive!

    response = execute_mcp_tool_with_error(
      "post_message",
      "chat_id" => @chat.to_param,
      "content" => "Hello from MCP"
    )

    assert response.to_h[:isError]
    assert_equal "Chat not found or cannot receive messages", response.contents.first.text
  end

end
