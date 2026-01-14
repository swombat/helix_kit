class MessagesController < ApplicationController

  require_feature_enabled :chats
  before_action :set_chat, except: [ :retry, :update ]
  before_action :set_chat_for_retry, only: :retry
  before_action :set_message, only: [ :update ]
  before_action :require_respondable_chat, only: [ :create, :retry ]

  def create
    @message = @chat.messages.build(
      message_params.merge(user: Current.user, role: "user")
    )
    @message.attachments.attach(params[:files]) if params[:files].present?

    if @message.save
      audit("create_message", @message, **message_params.to_h)
      AiResponseJob.perform_later(@chat) unless @chat.manual_responses?

      respond_to do |format|
        format.html { redirect_to account_chat_path(@chat.account, @chat) }
        format.json { render json: @message, status: :created }
      end
    elsif @message.errors.added?(:base, :duplicate_message)
      # Duplicate message - just refresh the page silently
      respond_to do |format|
        format.html { redirect_to account_chat_path(@chat.account, @chat) }
        format.json { render json: { duplicate: true }, status: :ok }
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

  def update
    unless @message.editable_by?(Current.user)
      return head :forbidden
    end

    if @message.update(message_params)
      head :ok
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def retry
    Rails.logger.info "🔄 Retry called for message #{params[:id]}, chat #{@chat.id}"
    AiResponseJob.perform_later(@chat)
    Rails.logger.info "🔄 AiResponseJob enqueued for chat #{@chat.id}"

    respond_to do |format|
      format.html { redirect_to account_chat_path(@chat.account, @chat) }
      format.json { head :ok }
    end
  rescue => e
    Rails.logger.error "🔄 Retry failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "Retry failed: #{e.message}" }
      format.json { head :internal_server_error }
    end
  end

  private

  def set_chat
    @chat = current_account.chats.find(params[:chat_id])
  end

  def set_chat_for_retry
    Rails.logger.info "🔄 set_chat_for_retry: Looking for message #{params[:id]}"
    @message = Message.find(params[:id])
    Rails.logger.info "🔄 set_chat_for_retry: Found message #{@message.id}, chat_id=#{@message.chat_id}"
    @chat = current_account.chats.find(@message.chat_id)
    Rails.logger.info "🔄 set_chat_for_retry: Found chat #{@chat.id}"
  rescue => e
    Rails.logger.error "🔄 set_chat_for_retry failed: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise
  end

  def set_message
    @message = Message.find(params[:id])
    @chat = current_account.chats.find(@message.chat_id)
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def require_respondable_chat
    return if @chat.respondable?

    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "This conversation is archived or deleted and cannot receive new messages" }
      format.json { render json: { error: "This conversation is archived or deleted" }, status: :unprocessable_entity }
    end
  end

end
