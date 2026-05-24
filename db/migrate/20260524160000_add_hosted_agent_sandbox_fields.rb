class AddHostedAgentSandboxFields < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :container_name, :string
    add_column :agents, :sandbox_host, :string
    add_column :agents, :container_image, :string
    add_column :agents, :restic_password, :string
    add_column :agents, :outbound_api_token, :string
    add_column :agents, :backup_interval_hours, :integer, default: 24, null: false
    add_column :agents, :backup_keep_daily, :integer, default: 7, null: false
    add_column :agents, :backup_keep_weekly, :integer, default: 4, null: false
    add_column :agents, :backup_keep_monthly, :integer, default: 12, null: false
    add_column :agents, :container_memory_mb, :integer, default: 8192, null: false
    add_column :agents, :container_cpu_shares, :integer, default: 1024, null: false

    add_index :agents, :container_name, unique: true
    add_index :agents, :sandbox_host

    create_table :agent_backup_snapshots do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :restic_snapshot_id, null: false
      t.bigint :size_bytes
      t.datetime :taken_at, null: false
      t.integer :duration_ms
      t.boolean :ok, null: false, default: false
      t.text :stderr_tail
      t.timestamps

      t.index [ :agent_id, :taken_at ]
    end
  end

end
