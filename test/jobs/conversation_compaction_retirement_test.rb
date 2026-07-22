require "test_helper"

class ConversationCompactionRetirementTest < ActiveJob::TestCase

  test "previously queued compaction jobs drain without doing work" do
    agent = agents(:research_assistant)
    chat = agent.account.chats.create!(
      model_id: "openrouter/auto",
      manual_responses: true,
      agent_ids: [ agent.id ]
    )

    assert_no_changes -> { [ chat.reload.updated_at, chat.messages.count, agent.reload.memories.count ] } do
      ConsolidateConversationJob.perform_now(chat)
      ConsolidateStaleConversationsJob.perform_now
    end
  end

end
