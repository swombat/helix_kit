class AiModel < ApplicationRecord

  acts_as_model chats: :chats, chat_class: "Chat", chats_foreign_key: :ai_model_id

end
