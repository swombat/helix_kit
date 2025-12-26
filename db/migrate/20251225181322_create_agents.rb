class CreateAgents < ActiveRecord::Migration[8.1]

  def change
    create_table :agents do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :system_prompt
      t.string :model_id, null: false, default: "openrouter/auto"
      t.jsonb :enabled_tools, null: false, default: []
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :agents, [ :account_id, :name ], unique: true
    add_index :agents, [ :account_id, :active ]

    add_column :settings, :allow_agents, :boolean, null: false, default: false
  end

end
