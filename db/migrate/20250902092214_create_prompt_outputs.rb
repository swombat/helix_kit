class CreatePromptOutputs < ActiveRecord::Migration[8.0]

  def change
    create_table :prompt_outputs do |t|
      t.references :account, foreign_key: true  # Nullable for non-account specific outputs
      t.string :prompt_key
      t.text :output
      t.jsonb :output_json, default: {}

      t.timestamps
    end

    add_index :prompt_outputs, :prompt_key
    add_index :prompt_outputs, :created_at
  end

end
