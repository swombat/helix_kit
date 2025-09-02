class RenameChangesToDataInAuditLogs < ActiveRecord::Migration[8.0]

  def change
    rename_column :audit_logs, :changes, :data
  end

end
