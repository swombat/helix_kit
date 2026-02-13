class AddClosedForInitiationToChatAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :chat_agents, :closed_for_initiation_at, :datetime
    add_index :chat_agents, [ :agent_id, :closed_for_initiation_at ],
              name: "index_chat_agents_on_agent_closed_initiation"
  end

end
