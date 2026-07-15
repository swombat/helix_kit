class AddSessionTrackingToAgentRuntimeInteractions < ActiveRecord::Migration[8.1]

  def change
    add_column :agent_runtime_interactions, :last_included_message_id, :bigint
    add_column :agent_runtime_interactions, :chaos_session_id, :string
    add_column :agent_runtime_interactions, :session_resumed, :boolean
    add_column :agent_runtime_interactions, :fresh_fallback, :boolean
    add_column :agent_runtime_interactions, :input_tokens, :bigint
    add_column :agent_runtime_interactions, :cached_input_tokens, :bigint
    add_column :agent_runtime_interactions, :output_tokens, :bigint
  end

end
