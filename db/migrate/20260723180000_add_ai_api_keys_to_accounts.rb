class AddAiApiKeysToAccounts < ActiveRecord::Migration[8.1]

  def up
    add_column :accounts, :openrouter_api_key, :text
    add_column :accounts, :anthropic_api_key, :text
    add_column :accounts, :openai_api_key, :text
    add_column :accounts, :gemini_api_key, :text
    add_column :accounts, :xai_api_key, :text
    add_column :accounts, :moonshot_api_key, :text
    add_column :accounts, :use_system_ai_credentials, :boolean, default: false, null: false

    execute "UPDATE accounts SET use_system_ai_credentials = TRUE"
  end

  def down
    remove_column :accounts, :use_system_ai_credentials
    remove_column :accounts, :moonshot_api_key
    remove_column :accounts, :xai_api_key
    remove_column :accounts, :gemini_api_key
    remove_column :accounts, :openai_api_key
    remove_column :accounts, :anthropic_api_key
    remove_column :accounts, :openrouter_api_key
  end

end
