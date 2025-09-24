class MessagesController < ApplicationController

  before_action :set_chat, except: :retry
  before_action :set_chat_for_retry, only: :retry

def create
    Rails.logger.info "=== MESSAGE CREATION DEBUG ==="
    Rails.logger.info "Headers: #{request.headers.to_h.select { |k, v| k.start_with?('HTTP_') || k.include?('CSRF') || k.include?('Inertia') }}"
    Rails.logger.info "Request format: #{request.format}"
    Rails.logger.info "Raw params: #{params.inspect}"
    Rails.logger.info "X-Inertia header: #{request.headers['X-Inertia']}"
    Rails.logger.info "X-CSRF-Token header: #{request.headers['X-CSRF-Token']}"

    @message = @chat.messages.build(
      message_params.merge(user: Current.user, role: "user")
    )
    Rails.logger.info "Message built with content: '#{@message.content}'"

    if @message.save
      Rails.logger.info "Message saved successfully with ID: #{@message.id}"
      @message.files.attach(params[:files]) if params[:files]
      AiResponseJob.perform_later(@chat, @message)

      respond_to do |format|
        format.html { redirect_to account_chat_path(@chat.account, @chat) }
        format.json { render json: @message, status: :created }
        # For Inertia requests (which come as HTML but have X-Inertia header)
        format.any { redirect_to account_chat_path(@chat.account, @chat) }
      end
    else
      # Handle validation errors
      respond_to do |format|
        format.html { redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "Failed to send message: #{@message.errors.full_messages.join(', ')}" }
        format.json { render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity }
        # For Inertia requests - still redirect but with error
        format.any do
          if request.headers["X-Inertia"]
            redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "Failed to send message: #{@message.errors.full_messages.join(', ')}"
          else
            render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
          end
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error "Message creation failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "Failed to send message: #{e.message}" }
      format.json { render json: { errors: [ e.message ] }, status: :unprocessable_entity }
      format.any do
        if request.headers["X-Inertia"]
          redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "Failed to send message: #{e.message}"
        else
          render json: { errors: [ e.message ] }, status: :unprocessable_entity
        end
      end
    end
  end

  def retry
    # Find the last user message to retry from
    last_user_message = @chat.messages.where(role: "user").last
    AiResponseJob.perform_later(@chat, last_user_message) if last_user_message

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
    params.require(:message).permit(:content)
  end

end
