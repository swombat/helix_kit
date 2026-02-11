module Api
  module V1
    class MessagesController < BaseController

      def create
        chat = current_api_account.chats.find(params[:conversation_id])

        unless chat.respondable?
          return render json: { error: "Conversation is archived or deleted" }, status: :unprocessable_entity
        end

        message = chat.messages.create!(
          content: params[:content],
          role: "user",
          user: current_api_user
        )

        AiResponseJob.perform_later(chat) unless chat.manual_responses?

        render json: {
          message: { id: message.to_param, content: message.content, created_at: message.created_at.iso8601 },
          ai_response_triggered: !chat.manual_responses?
        }, status: :created
      end

    end
  end
end
