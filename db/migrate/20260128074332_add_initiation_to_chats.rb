class AddInitiationToChats < ActiveRecord::Migration[8.1]

  def change
    add_reference :chats, :initiated_by_agent, foreign_key: { to_table: :agents }
    add_column :chats, :initiation_reason, :text
  end

end
