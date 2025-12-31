require "test_helper"
require "ostruct"

class AllAgentsResponseJobTest < ActiveJob::TestCase

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent1 = agents(:research_assistant)
    @agent2 = agents(:code_reviewer)
    # Build the chat first, set agent_ids, then save to satisfy validation
    @chat = @account.chats.new(
      model_id: "openrouter/auto",
      title: "Test Group Chat",
      manual_responses: true
    )
    @chat.agent_ids = [ @agent1.id, @agent2.id ]
    @chat.save!
    @user_message = @chat.messages.create!(
      content: "Hello, agents!",
      role: "user",
      user: @user
    )
  end

  test "job is enqueued properly" do
    agent_ids = [ @agent1.id, @agent2.id ]
    assert_enqueued_with(job: AllAgentsResponseJob, args: [ @chat, agent_ids ]) do
      AllAgentsResponseJob.perform_later(@chat, agent_ids)
    end
  end

  test "processes first agent and queues remaining" do
    agent_ids = [ @agent1.id, @agent2.id ]

    mock_llm = MockLlm.new(
      final_content: "Response from first agent",
      model_id: "test-model"
    )

    # First agent processes
    RubyLLM.stub(:chat, ->(*args, **kwargs) { mock_llm }) do
      assert_enqueued_with(job: AllAgentsResponseJob, args: [ @chat, [ @agent2.id ] ]) do
        AllAgentsResponseJob.perform_now(@chat, agent_ids)
      end
    end

    # Verify first agent's message was created
    ai_message = @chat.messages.where(role: "assistant", agent: @agent1).last
    assert_not_nil ai_message, "First agent's message should be created"
    assert_equal "Response from first agent", ai_message.content
  end

  test "does nothing when agent_ids is empty" do
    assert_no_enqueued_jobs do
      AllAgentsResponseJob.perform_now(@chat, [])
    end

    # No new messages should be created (only the original user message)
    assert_equal 1, @chat.messages.count
  end

  test "adds context messages then calls complete" do
    agent_ids = [ @agent1.id ]

    messages_added = []
    complete_called = false

    mock_llm = MockLlm.new(
      final_content: "Response from agent",
      model_id: "test-model",
      on_add_message: ->(msg) { messages_added << msg },
      on_complete: -> { complete_called = true }
    )

    RubyLLM.stub(:chat, ->(*args, **kwargs) { mock_llm }) do
      AllAgentsResponseJob.perform_now(@chat, agent_ids)
    end

    # Should have added context messages (system + user message)
    assert_equal 2, messages_added.length, "Should add system and user messages"
    assert_equal "system", messages_added.first[:role]
    assert complete_called, "complete should be called"
  end

  test "handles tool calls and continues to final response" do
    agent_ids = [ @agent1.id ]
    tool_call_count = 0

    mock_llm = MockLlm.new(
      final_content: "I fetched the webpage and here is the summary...",
      model_id: "test-model",
      simulate_tool_call: true,
      on_tool_call_invoked: -> { tool_call_count += 1 }
    )

    # Enable web tool for the agent (use the actual class name)
    @agent1.update!(enabled_tools: [ "WebTool" ])

    RubyLLM.stub(:chat, ->(*args, **kwargs) { mock_llm }) do
      AllAgentsResponseJob.perform_now(@chat, agent_ids)
    end

    # Tool should be invoked
    assert_equal 1, tool_call_count, "Tool should be invoked"

    # Final message should still be created
    ai_message = @chat.messages.where(role: "assistant").last
    assert_not_nil ai_message
    assert_equal "I fetched the webpage and here is the summary...", ai_message.content
    assert ai_message.tools_used.present?, "tools_used should be populated"
  end

  test "sequential processing creates context for subsequent agents" do
    # Run first agent
    mock_llm1 = MockLlm.new(
      final_content: "Response from agent 1",
      model_id: "test-model"
    )

    RubyLLM.stub(:chat, ->(*args, **kwargs) { mock_llm1 }) do
      AllAgentsResponseJob.perform_now(@chat, [ @agent1.id ])
    end

    # Now reload chat and run second agent
    @chat.reload
    second_agent_context = []

    mock_llm2 = MockLlm.new(
      final_content: "Response from agent 2",
      model_id: "test-model",
      on_add_message: ->(msg) { second_agent_context << msg }
    )

    RubyLLM.stub(:chat, ->(*args, **kwargs) { mock_llm2 }) do
      AllAgentsResponseJob.perform_now(@chat, [ @agent2.id ])
    end

    # Second agent should see system + user message + first agent's response
    assert_equal 3, second_agent_context.length, "Second agent should see all prior messages"
    assert_equal "system", second_agent_context[0][:role]
    assert_equal "user", second_agent_context[1][:role]
    # The third message is from agent1, formatted as a user message with [AgentName] prefix
    assert_equal "user", second_agent_context[2][:role]
    assert_includes second_agent_context[2][:content], "Research Assistant"
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
          name: "WebTool",
          arguments: { action: "fetch", url: "https://example.com" }
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
