class Messages::RetriesController < ApplicationController

  require_feature_enabled :chats

  before_action :set_message_and_chat
  before_action :require_respondable_chat

  def create
    AiResponseJob.perform_later(@chat)

    respond_to do |format|
      format.html { redirect_to account_chat_path(@chat.account, @chat) }
      format.json { head :ok }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "Retry failed: #{e.message}" }
      format.json { head :internal_server_error }
    end
  end

  private

  def set_message_and_chat
    @message = Message.find(params[:message_id])
    @chat = current_account.chats.find(@message.chat_id)
  end

  def require_respondable_chat
    return if @chat.respondable?

    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "This conversation is archived or deleted and cannot receive new messages" }
      format.json { render json: { error: "This conversation is archived or deleted" }, status: :unprocessable_entity }
    end
  end

end
