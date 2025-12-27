require "test_helper"
require "ostruct"

class ManualAgentResponseJobTest < ActiveJob::TestCase

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)
    # Build the chat first, set agent_ids, then save to satisfy validation
    @chat = @account.chats.new(
      model_id: "openrouter/auto",
      title: "Test Group Chat",
      manual_responses: true
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!
    @user_message = @chat.messages.create!(
      content: "Hello, agents!",
      role: "user",
      user: @user
    )
  end

  test "job is enqueued properly" do
    assert_enqueued_with(job: ManualAgentResponseJob, args: [ @chat, @agent ]) do
      ManualAgentResponseJob.perform_later(@chat, @agent)
    end
  end

  test "creates message attributed to agent" do
    mock_llm = MockLlm.new(
      final_content: "Hello, I am the research assistant!",
      model_id: "openrouter/auto"
    )

    RubyLLM.stub(:chat, ->(*args, **kwargs) { mock_llm }) do
      ManualAgentResponseJob.perform_now(@chat, @agent)
    end

    # Verify message was created with agent attribution
    ai_message = @chat.messages.where(role: "assistant").last
    assert_not_nil ai_message, "AI message should be created"
    assert_equal @agent, ai_message.agent
    assert_equal "Hello, I am the research assistant!", ai_message.content
    assert_not ai_message.streaming?
  end

  test "adds context messages then calls complete" do
    # Track what happens during the job
    messages_added = []
    complete_called = false

    mock_llm = MockLlm.new(
      final_content: "Response from agent",
      model_id: "test-model",
      on_add_message: ->(msg) { messages_added << msg },
      on_complete: -> { complete_called = true }
    )

    RubyLLM.stub(:chat, ->(*args, **kwargs) { mock_llm }) do
      ManualAgentResponseJob.perform_now(@chat, @agent)
    end

    # Should have added context messages (system + user message)
    assert_equal 2, messages_added.length, "Should add system and user messages"
    assert_equal "system", messages_added.first[:role]
    assert complete_called, "complete should be called"
  end

  test "handles tool calls correctly" do
    # Verify tool calls continue the loop until final response
    tool_call_count = 0

    mock_llm = MockLlm.new(
      final_content: "I fetched the webpage and here is the summary...",
      model_id: "test-model",
      simulate_tool_call: true,
      on_tool_call_invoked: -> { tool_call_count += 1 }
    )

    # Enable web fetch for the agent (use the actual class name)
    @agent.update!(enabled_tools: [ "WebFetchTool" ])

    RubyLLM.stub(:chat, ->(*args, **kwargs) { mock_llm }) do
      ManualAgentResponseJob.perform_now(@chat, @agent)
    end

    # Verify tool was invoked
    assert_equal 1, tool_call_count, "Tool should be invoked"

    # Verify final message was still created with tool_used
    ai_message = @chat.messages.where(role: "assistant").last
    assert_not_nil ai_message
    assert ai_message.tools_used.present?, "tools_used should be populated"
  end

  test "cleans up streaming on error" do
    mock_llm = MockLlm.new(raise_error: RuntimeError.new("Simulated error"))

    assert_raises(RuntimeError) do
      RubyLLM.stub(:chat, ->(*args, **kwargs) { mock_llm }) do
        ManualAgentResponseJob.perform_now(@chat, @agent)
      end
    end

    # Streaming should be stopped for any created messages
    ai_message = @chat.messages.where(role: "assistant").last
    if ai_message
      assert_not ai_message.streaming?, "Streaming should be stopped after error"
    end
  end

  # Helper class to mock RubyLLM chat behavior
  class MockLlm

    attr_reader :tools

    def initialize(options = {})
      @final_content = options[:final_content] || "Mock response"
      @model_id = options[:model_id] || "test-model"
      @simulate_tool_call = options[:simulate_tool_call] || false
      @raise_error = options[:raise_error]
      @on_add_message = options[:on_add_message]
      @on_complete = options[:on_complete]
      @on_tool_call_invoked = options[:on_tool_call_invoked]
      @tools = {}
      @on_callbacks = {}
    end

    def with_tool(tool)
      tool_instance = tool.is_a?(Class) ? tool.new : tool
      @tools[tool_instance.name.to_sym] = tool_instance
      self
    end

    def on_new_message(&block)
      @on_callbacks[:new_message] = block
      self
    end

    def on_tool_call(&block)
      @on_callbacks[:tool_call] = block
      self
    end

    def on_end_message(&block)
      @on_callbacks[:end_message] = block
      self
    end

    def add_message(msg)
      @on_add_message&.call(msg)
    end

    def complete(&block)
      raise @raise_error if @raise_error

      @on_complete&.call

      # Simulate new message callback
      @on_callbacks[:new_message]&.call

      # Simulate tool call if configured
      if @simulate_tool_call
        tool_call = OpenStruct.new(
          name: "WebFetchTool",
          arguments: { url: "https://example.com" }
        )
        @on_callbacks[:tool_call]&.call(tool_call)
        @on_tool_call_invoked&.call
      end

      # Simulate streaming chunk
      block.call(OpenStruct.new(content: @final_content)) if block_given?

      # Simulate end message callback
      final_message = OpenStruct.new(
        content: @final_content,
        model_id: @model_id,
        input_tokens: 10,
        output_tokens: 20
      )
      @on_callbacks[:end_message]&.call(final_message)

      final_message
    end

  end

end
