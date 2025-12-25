class AddToolStatusToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :tool_status, :string
  end
end
