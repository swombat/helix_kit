class AddPerAgentRepoFields < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :github_repo_url, :string
    add_column :agents, :github_repo_owner, :string
    add_column :agents, :github_repo_name, :string
    add_column :agents, :github_deploy_key_id, :string
    add_column :agents, :github_deploy_key_priv, :text

    add_column :accounts, :github_pat, :text
    add_column :accounts, :github_login, :string
  end

end
