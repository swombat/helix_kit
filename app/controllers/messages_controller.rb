class MessagesController < ApplicationController

  before_action :set_chat

  def create
    @message = @chat.messages.create!(message_params.merge(user: Current.user))
    @message.files.attach(params[:files]) if params[:files]

    AiResponseJob.perform_later(@chat, @message)

    redirect_to [ @chat.account, @chat ]
  end

  private

  def set_chat
    @chat = current_account.chats.find(params[:chat_id])
  end

  def message_params
    params.require(:message).permit(:content).merge(role: "user")
  end

end
