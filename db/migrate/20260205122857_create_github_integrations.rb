class CreateGithubIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :github_integrations do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.text :access_token
      t.string :github_username
      t.string :repository_full_name
      t.jsonb :recent_commits, default: []
      t.datetime :commits_synced_at
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end
  end
end
