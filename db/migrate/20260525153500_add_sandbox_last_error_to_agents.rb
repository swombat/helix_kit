class AddSandboxLastErrorToAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :sandbox_last_error, :text
    add_column :agents, :sandbox_last_error_at, :datetime
  end

end
