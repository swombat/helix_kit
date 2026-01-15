class AddSummaryToChats < ActiveRecord::Migration[8.1]

  def change
    add_column :chats, :summary, :text
    add_column :chats, :summary_generated_at, :datetime
  end

end
