class MessagesController < ApplicationController

  require_feature_enabled :chats
  before_action :set_chat, except: :retry
  before_action :set_chat_for_retry, only: :retry

def create
    @message = @chat.messages.build(
      message_params.merge(user: Current.user, role: "user")
    )
    @message.files.attach(params[:files]) if params[:files].present?

    if @message.save
      audit("create_message", @message, **message_params.to_h)
      AiResponseJob.perform_later(@chat)

      respond_to do |format|
        format.html { redirect_to account_chat_path(@chat.account, @chat) }
        format.json { render json: @message, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "Failed to send message: #{@message.errors.full_messages.join(', ')}" }
        format.json { render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  rescue StandardError => e
    error "Message creation failed: #{e.message}"
    error e.backtrace.join("\n")
    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "Failed to send message: #{e.message}" }
      format.json { render json: { errors: [ e.message ] }, status: :unprocessable_entity }
    end
  end

  def retry
    # Find the last user message to retry from
    AiResponseJob.perform_later(@chat)

    head :ok
  end

  private

  def set_chat
    @chat = current_account.chats.find(params[:chat_id])
  end

  def set_chat_for_retry
    @message = Message.find(params[:id])
    @chat = current_account.chats.find(@message.chat_id)
  end

def message_params
    params.require(:message).permit(:content, :model_id)
  end

end
