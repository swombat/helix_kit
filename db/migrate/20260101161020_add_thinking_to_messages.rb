class AddThinkingToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :thinking, :text
  end
end
