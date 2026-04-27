class AddContextTokensToChats < ActiveRecord::Migration[8.0]

  def up
    add_column :chats, :context_tokens, :integer, default: 0, null: false
    Chat.reset_column_information
    Chat.find_each(&:recalculate_context_tokens!)
  end

  def down
    remove_column :chats, :context_tokens
  end

end
