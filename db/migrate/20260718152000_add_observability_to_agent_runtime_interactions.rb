class AddObservabilityToAgentRuntimeInteractions < ActiveRecord::Migration[8.0]

  def change
    change_table :agent_runtime_interactions, bulk: true do |t|
      t.integer :telemetry_schema_version
      t.string :chaos_telemetry_status
      t.integer :unsupported_chaos_telemetry_schema_version
      t.string :chaos_version
      t.string :provider
      t.string :model
      t.string :cache_ttl

      t.boolean :persistent_session_requested
      t.boolean :session_mapping_found
      t.boolean :resume_attempted
      t.string :session_outcome
      t.string :session_roll_reason
      t.jsonb :changed_identity_files, default: []
      t.string :prior_chaos_session_id
      t.integer :session_trigger_sequence
      t.integer :session_age_seconds

      t.string :prompt_mode
      t.bigint :full_prompt_bytes
      t.bigint :delta_prompt_bytes
      t.bigint :selected_prompt_bytes
      t.jsonb :prompt_component_bytes, default: {}

      t.string :usage_scope
      t.bigint :uncached_input_tokens
      t.bigint :cache_creation_input_tokens
      t.bigint :cache_read_input_tokens
      t.bigint :reasoning_output_tokens
      t.integer :provider_request_count
      t.boolean :usage_complete
    end

    add_index :agent_runtime_interactions, [ :agent_id, :session_id, :started_at ],
      name: "idx_runtime_interactions_agent_session_started"
    add_index :agent_runtime_interactions, [ :agent_id, :chaos_session_id, :started_at ],
      name: "idx_runtime_interactions_agent_chaos_started"
    add_index :agent_runtime_interactions, [ :agent_id, :session_outcome, :started_at ],
      name: "idx_runtime_interactions_agent_outcome_started"
    add_index :agent_runtime_interactions, [ :agent_id, :session_roll_reason, :started_at ],
      name: "idx_runtime_interactions_agent_roll_reason_started"
  end

end
