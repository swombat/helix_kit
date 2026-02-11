class Messages::HallucinationFixesController < ApplicationController

  require_feature_enabled :chats

  before_action :set_message_and_chat

  def create
    @message.fix_hallucinated_tool_calls!
    redirect_to account_chat_path(@chat.account, @chat)
  rescue StandardError => e
    redirect_to account_chat_path(@chat.account, @chat), alert: "Failed to fix: #{e.message}"
  end

  private

  def set_message_and_chat
    @message = Message.find(params[:message_id])
    @chat = if Current.user.site_admin
      Chat.find(@message.chat_id)
    else
      Chat.where(id: @message.chat_id, account_id: Current.user.account_ids).first!
    end
  end

end
