class ChatsController < ApplicationController

  before_action :set_chat, except: [ :index, :create ]

  def index
    @chats = current_account.chats.includes(:messages).order(created_at: :desc)
    render inertia: "Chats/Index", props: { chats: @chats }
  end

  def show
    @messages = @chat.messages.includes(:user, files_attachments: :blob)
    render inertia: "Chats/Show", props: {
      chat: @chat,
      messages: @messages
    }
  end

  def create
    @chat = current_account.chats.create!(chat_params)
    redirect_to [ @chat.account, @chat ]
  end

  def destroy
    @chat.destroy!
    redirect_to account_chats_path(current_account)
  end

  private

  def set_chat
    @chat = current_account.chats.find(params[:id])
  end

  def chat_params
    params.require(:chat).permit(:model_id).with_defaults(model_id: "openrouter/auto")
  end

end
