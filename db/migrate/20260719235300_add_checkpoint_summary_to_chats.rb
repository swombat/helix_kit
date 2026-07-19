class AddCheckpointSummaryToChats < ActiveRecord::Migration[8.1]

  def change
    add_column :chats, :checkpoint_summary, :text
  end

end
