class AddReasoningEffortToAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :reasoning_effort, :string, default: "medium", null: false
  end

end
