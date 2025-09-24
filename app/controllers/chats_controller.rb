class ChatsController < ApplicationController

  before_action :set_chat, except: [ :index, :create ]

  def index
    @chats = current_account.chats.includes(:messages).latest

    render inertia: "chats/index", props: {
      chats: @chats.as_json,
      models: Chat::MODELS,
      account: current_account.as_json
    }
  end

  def show
    @chats = current_account.chats.latest
    @messages = @chat.messages.sorted.includes(:user)

    render inertia: "chats/show", props: {
      chat: @chat.as_json,
      chats: @chats.as_json(as: :sidebar_json),
      messages: @messages.all.collect(&:as_json),
      account: current_account.as_json
    }
  end

  def create
    @chat = current_account.chats.create_with_message!(
      chat_params,
      message_content: params[:message],
      user: Current.user
    )
    redirect_to account_chat_path(current_account, @chat)
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
    params.fetch(:chat, {})
      .permit(:model_id)
      .with_defaults(model_id: "openrouter/auto")
  end

end
