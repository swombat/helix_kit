class AddPromptLayoutObservability < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :prompt_cache_layout_v2, :boolean, default: false, null: false
    add_column :chats, :prompt_timezone, :string

    add_column :messages, :prompt_layout_version, :integer
    add_column :messages, :stable_prompt_bytes, :integer
    add_column :messages, :transcript_prompt_bytes, :integer
    add_column :messages, :envelope_prompt_bytes, :integer
    add_column :messages, :stable_prompt_sha256, :string
  end

end
