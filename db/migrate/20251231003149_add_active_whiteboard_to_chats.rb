class AddActiveWhiteboardToChats < ActiveRecord::Migration[8.1]

  def change
    add_reference :chats, :active_whiteboard, foreign_key: { to_table: :whiteboards }
  end

end
