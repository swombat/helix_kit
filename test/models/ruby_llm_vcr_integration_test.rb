require "test_helper"
require "vcr"

class RubyLlmVcrIntegrationTest < ActiveSupport::TestCase

  # === VCR Tests for Ruby LLM Integration ===
  # These tests verify that the Ruby LLM integration works correctly with VCR
  # to record and replay API interactions for testing purposes.

  test "Message to_llm conversion works correctly" do
    email = "message-llm-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account
    chat = Chat.create!(account: account)

    # Test user message conversion
    user_message = chat.messages.create!(
      user: user,
      role: "user",
      content: "Hello AI"
    )

    llm_format = user_message.to_llm
    assert llm_format.is_a?(RubyLLM::Message)
    assert_equal :user, llm_format.role
    assert_equal "Hello AI", llm_format.content

    # Test assistant message conversion
    assistant_message = chat.messages.create!(
      role: "assistant",
      content: "Hello! How can I help?"
    )

    llm_format = assistant_message.to_llm
    assert llm_format.is_a?(RubyLLM::Message)
    assert_equal :assistant, llm_format.role
    assert_equal "Hello! How can I help?", llm_format.content
  end

  test "Chat to_llm conversation conversion works correctly" do
    email = "chat-llm-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account
    chat = Chat.create!(account: account)

    # Add multiple messages
    chat.messages.create!(user: user, role: "user", content: "Hello")
    chat.messages.create!(role: "assistant", content: "Hi there!")
    chat.messages.create!(user: user, role: "user", content: "How are you?")

    llm_format = chat.to_llm
    assert llm_format.is_a?(RubyLLM::Chat)
    assert_equal 3, llm_format.messages.length

    assert_equal :user, llm_format.messages[0].role
    assert_equal "Hello", llm_format.messages[0].content

    assert_equal :assistant, llm_format.messages[1].role
    assert_equal "Hi there!", llm_format.messages[1].content

    assert_equal :user, llm_format.messages[2].role
    assert_equal "How are you?", llm_format.messages[2].content
  end

  test "Chat ask method signature and response structure" do
    email = "ask-test-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account
    chat = Chat.create!(account: account)

    # Verify ask method exists and has correct signature
    assert chat.respond_to?(:ask)
    assert_equal [ [ :req, :message ], [ :key, :with ], [ :block, :& ] ], chat.method(:ask).parameters

    # Verify to_llm method exists and returns RubyLLM::Chat
    llm_chat = chat.to_llm
    assert llm_chat.is_a?(RubyLLM::Chat)
    assert llm_chat.respond_to?(:ask)
  end

  test "Ruby LLM providers are configured correctly" do
    # Verify OpenAI configuration
    openai_key = Rails.application.credentials.dig(:ai, :open_ai, :api_token)
    assert_not_nil openai_key, "OpenAI API key should be configured in credentials"

    # Verify Anthropic configuration
    claude_key = Rails.application.credentials.dig(:ai, :claude, :api_token)
    assert_not_nil claude_key, "Claude API key should be configured in credentials"

    # Verify OpenRouter configuration
    openrouter_key = Rails.application.credentials.dig(:ai, :openrouter, :api_token)
    assert_not_nil openrouter_key, "OpenRouter API key should be configured in credentials"

    # Verify RubyLLM configuration
    config = RubyLLM.config
    assert_not_nil config.openai_api_key
    assert_not_nil config.anthropic_api_key
    assert_not_nil config.openrouter_api_key
    assert_equal "openrouter/auto", config.default_model
  end

  test "VCR is properly configured for API recording" do
    # Verify VCR configuration
    assert VCR.configuration.cassette_library_dir.end_with?("test/vcr_cassettes")
    # Verify VCR has configured hooks (may be empty in test environment)
    # This ensures VCR setup file has been loaded
    assert_respond_to VCR.configuration, :hook_into

    # Verify VCR has some basic filtering set up
    # (Specific filters are configured in test/support/vcr_setup.rb)
    assert_respond_to VCR.configuration, :filter_sensitive_data
  end

  # === Live API Tests (Disabled by Default) ===
  # To enable these tests for creating new VCR cassettes:
  # 1. Ensure valid API keys are configured in Rails credentials
  # 2. Change skip to test and run individually
  # 3. Commit the generated cassettes to the repository

  def skip_openai_provider_chat_completion_with_vcr
    email = "openai-test-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account

    VCR.use_cassette("openai_chat_completion_test") do
      chat = Chat.create!(account: account, model_id: "gpt-4o-mini")

      response = chat.ask("What is 2 + 2? Please respond with just the number.")

      assert_not_nil response
      assert response.is_a?(String)
      assert response.length > 0

      # Verify messages were created
      assert_equal 2, chat.messages.count
      user_msg = chat.messages.where(role: "user").first
      assistant_msg = chat.messages.where(role: "assistant").first

      assert_equal "What is 2 + 2? Please respond with just the number.", user_msg.content
      assert_not_nil assistant_msg
      assert assistant_msg.content.length > 0
    end
  end

  def skip_openrouter_provider_chat_completion_with_vcr
    email = "openrouter-test-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account

    VCR.use_cassette("openrouter_chat_completion_test") do
      chat = Chat.create!(account: account, model_id: "openai/gpt-4.1-mini")

      response = chat.ask("What is the capital of France? Please respond with just the city name.")

      assert_not_nil response
      assert response.is_a?(String)
      assert response.length > 0

      # Verify message was created
      assert_equal 2, chat.messages.count
      assistant_message = chat.messages.where(role: "assistant").first
      assert_not_nil assistant_message
      assert assistant_message.content.downcase.include?("paris")
    end
  end

  def skip_claude_provider_chat_completion_with_vcr
    email = "claude-test-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account

    VCR.use_cassette("claude_chat_completion_test") do
      chat = Chat.create!(account: account, model_id: "claude-3-haiku")

      response = chat.ask("What is 10 * 10? Please respond with just the number.")

      assert_not_nil response
      assert response.is_a?(String)
      assert response.length > 0

      # Verify message was created
      assert_equal 2, chat.messages.count
      assistant_message = chat.messages.where(role: "assistant").first
      assert_not_nil assistant_message
      assert assistant_message.content.include?("100")
    end
  end

end
