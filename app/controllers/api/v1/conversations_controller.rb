module Api
  module V1
    class ConversationsController < BaseController

      def index
        chats = current_api_account.chats.kept.active.latest.limit(100)
        render json: { conversations: chats.map { |c| conversation_json(c) } }
      end

      def show
        chat = current_api_account.chats.find(params[:id])
        render json: {
          conversation: {
            id: chat.to_param,
            title: chat.title_or_default,
            model: chat.model_label,
            created_at: chat.created_at.iso8601,
            updated_at: chat.updated_at.iso8601,
            transcript: chat.transcript_for_api
          }
        }
      end

      def create_message
        chat = current_api_account.chats.find(params[:id])

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

      private

      def conversation_json(chat)
        {
          id: chat.to_param,
          title: chat.title_or_default,
          summary: chat.summary,
          summary_stale: chat.summary_stale?,
          model: chat.model_label,
          message_count: chat.message_count,
          updated_at: chat.updated_at.iso8601
        }
      end

    end
  end
end
