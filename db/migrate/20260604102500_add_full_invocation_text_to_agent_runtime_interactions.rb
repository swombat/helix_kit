class AddFullInvocationTextToAgentRuntimeInteractions < ActiveRecord::Migration[8.1]

  def change
    add_column :agent_runtime_interactions, :full_invocation_text, :text
  end

end
