require "test_helper"
require "support/vcr_setup"

class TwitterToolTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:team_account)
    @chat = @account.chats.create!(model_id: "openai/gpt-4o")
    @agent = agents(:research_assistant)
  end

  # --- Validation tests (no API calls needed) ---

  test "returns error when no x integration configured" do
    result = build_tool.execute(text: "Hello world")

    assert_equal "error", result[:type]
    assert_match(/not configured/, result[:error])
  end

  test "returns error when integration is disabled" do
    create_integration(enabled: false)

    result = build_tool.execute(text: "Hello world")

    assert_equal "error", result[:type]
    assert_match(/not configured/, result[:error])
  end

  test "returns error when integration is not connected" do
    create_integration(access_token: nil, refresh_token: nil)

    result = build_tool.execute(text: "Hello world")

    assert_equal "error", result[:type]
    assert_match(/not configured/, result[:error])
  end

  test "returns error when text exceeds 280 characters" do
    create_integration

    result = build_tool.execute(text: "a" * 281)

    assert_equal "error", result[:type]
    assert_match(/281 chars/, result[:error])
    assert_match(/max 280/, result[:error])
  end

  private

  def create_integration(**overrides)
    defaults = {
      account: @account,
      enabled: true,
      access_token: "test_access_token",
      refresh_token: "test_refresh_token",
      token_expires_at: 1.day.from_now,
      x_username: "test_user"
    }
    XIntegration.create!(**defaults.merge(overrides))
  end

  def build_tool
    TwitterTool.new(chat: @chat, current_agent: @agent)
  end

end
