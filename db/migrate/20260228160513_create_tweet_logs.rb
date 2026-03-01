class CreateTweetLogs < ActiveRecord::Migration[8.1]

  def change
    create_table :tweet_logs do |t|
      t.references :x_integration, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: true
      t.string :tweet_id, null: false
      t.text :text, null: false
      t.timestamps
    end

    add_index :tweet_logs, :tweet_id, unique: true
  end

end
