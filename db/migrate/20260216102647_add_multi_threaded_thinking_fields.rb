class AddMultiThreadedThinkingFields < ActiveRecord::Migration[8.1]

  def change
    add_column :chat_agents, :agent_summary, :text
    add_column :chat_agents, :agent_summary_generated_at, :datetime
    add_column :chat_agents, :borrowed_context_json, :jsonb

    add_index :chat_agents, [ :agent_id, :agent_summary_generated_at ],
              name: "index_chat_agents_on_agent_summary_recency"

    # Per-agent summary identity prompt (like reflection_prompt, memory_reflection_prompt)
    add_column :agents, :summary_prompt, :text
  end

end
