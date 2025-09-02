class CreateAuditLogs < ActiveRecord::Migration[8.0]

  def change
    create_table :audit_logs do |t|
      t.references :user, foreign_key: true  # Nullable for system actions
      t.references :account, foreign_key: true  # Nullable for non-account actions
      t.references :auditable, polymorphic: true
      t.string :action, null: false
      t.jsonb :changes, default: {}
      t.string :ip_address
      t.string :user_agent

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
    add_index :audit_logs, [ :auditable_type, :auditable_id ]
    add_index :audit_logs, [ :account_id, :created_at ]
  end

end
