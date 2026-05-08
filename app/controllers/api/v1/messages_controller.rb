module Api
  module V1
    class MessagesController < BaseController

      def create
        chat = conversations_scope.find(params[:conversation_id])

        unless chat.respondable?
          return render json: { error: "Conversation is archived or deleted" }, status: :unprocessable_entity
        end

        message = if current_api_agent
          chat.messages.create!(
            content: params[:content],
            role: "assistant",
            agent: current_api_agent
          )
        else
          chat.messages.create!(
            content: params[:content],
            role: "user",
            user: current_api_user
          )
        end

        ai_response_triggered = !current_api_agent && !chat.manual_responses?
        AiResponseJob.perform_later(chat) if ai_response_triggered

        render json: {
          message: { id: message.to_param, content: message.content, created_at: message.created_at.iso8601 },
          ai_response_triggered: ai_response_triggered
        }, status: :created
      end

      private

      def conversations_scope
        return current_api_agent.chats if current_api_agent

        current_api_account.chats
      end

    end
  end
end
