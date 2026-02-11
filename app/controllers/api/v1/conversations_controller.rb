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
