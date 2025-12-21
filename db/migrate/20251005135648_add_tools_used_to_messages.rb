class AddToolsUsedToMessages < ActiveRecord::Migration[8.0]

  def change
    add_column :messages, :tools_used, :text, array: true, default: []
    add_index :messages, :tools_used, using: :gin
  end

end
