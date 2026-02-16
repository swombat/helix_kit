require "test_helper"
require "support/vcr_setup"

class GenerateAgentSummaryJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @account = @agent.account
    @chat = @account.chats.new(
      title: "Summary Test Chat",
      manual_responses: true,
      model_id: @agent.model_id
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!
    @chat_agent = ChatAgent.find_by(chat: @chat, agent: @agent)

    # Create enough messages to trigger summary generation
    @chat.messages.create!(role: "user", content: "Hello, can you help me with this project?")
    @chat.messages.create!(role: "assistant", agent: @agent, content: "Of course! What do you need help with?")
    @chat.messages.create!(role: "user", content: "I need to refactor the authentication system.")
  end

  test "generates summary when stale" do
    VCR.use_cassette("generate_agent_summary_job/generates_summary") do
      GenerateAgentSummaryJob.perform_now(@chat, @agent)
    end

    @chat_agent.reload
    assert @chat_agent.agent_summary.present?
    assert @chat_agent.agent_summary_generated_at.present?
  end

  test "skips when not stale (debounce)" do
    @chat_agent.update_columns(
      agent_summary: "Existing summary",
      agent_summary_generated_at: 2.minutes.ago
    )

    GenerateAgentSummaryJob.perform_now(@chat, @agent)

    assert_equal "Existing summary", @chat_agent.reload.agent_summary
  end

  test "skips when fewer than 2 messages" do
    chat2 = @account.chats.new(title: "Short Chat", manual_responses: true, model_id: @agent.model_id)
    chat2.agent_ids = [ @agent.id ]
    chat2.save!
    chat2.messages.create!(role: "user", content: "Just one message")

    ca = ChatAgent.find_by(chat: chat2, agent: @agent)
    GenerateAgentSummaryJob.perform_now(chat2, @agent)

    assert_nil ca.reload.agent_summary
  end

  test "updates agent_summary and agent_summary_generated_at" do
    VCR.use_cassette("generate_agent_summary_job/updates_summary") do
      GenerateAgentSummaryJob.perform_now(@chat, @agent)
    end

    @chat_agent.reload
    assert @chat_agent.agent_summary.present?
    assert @chat_agent.agent_summary_generated_at.present?
  end

  test "returns early when chat_agent not found" do
    @chat_agent.destroy

    assert_nothing_raised do
      GenerateAgentSummaryJob.perform_now(@chat, @agent)
    end
  end

end
