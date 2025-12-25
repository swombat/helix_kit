class CreateAiModels < ActiveRecord::Migration[8.1]

  def change
    # Create the ai_models table for RubyLLM 1.9+
    create_table :ai_models do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      t.jsonb :modalities, default: {}
      t.jsonb :capabilities, default: []
      t.jsonb :pricing, default: {}
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index [ :provider, :model_id ], unique: true
      t.index :provider
      t.index :family
      t.index :capabilities, using: :gin
      t.index :modalities, using: :gin
    end

    # Rename existing model_id string columns to model_id_string
    rename_column :chats, :model_id, :model_id_string
    rename_column :messages, :model_id, :model_id_string

    # Add foreign key references to ai_models
    add_reference :chats, :ai_model, foreign_key: true
    add_reference :messages, :ai_model, foreign_key: true
  end

end
