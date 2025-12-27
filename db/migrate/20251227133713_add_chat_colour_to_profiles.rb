class AddChatColourToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :chat_colour, :string
  end
end
