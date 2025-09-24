class AddStreamingToMessages < ActiveRecord::Migration[8.0]

  def change
    add_column :messages, :streaming, :boolean, default: false, null: false
    add_index :messages, :streaming
  end

end
