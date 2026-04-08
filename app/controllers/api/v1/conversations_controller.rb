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
            group_chat: chat.group_chat?,
            agents: chat.group_chat? ? chat.agents.map { |a| { id: a.to_param, name: a.name } } : [],
            created_at: chat.created_at.iso8601,
            updated_at: chat.updated_at.iso8601,
            transcript: chat.transcript_for_api
          }
        }
      end

      def create
        agent_ids = resolve_agent_ids
        is_group = agent_ids.present?

        chat_attrs = {
          account: current_api_account,
          model_id: params[:model_id] || "openrouter/auto",
          title: params[:title],
          manual_responses: is_group
        }

        chat = Chat.create_with_message!(
          chat_attrs,
          message_content: params[:message],
          user: current_api_user,
          agent_ids: agent_ids
        )

        render json: {
          conversation: {
            id: chat.to_param,
            title: chat.title_or_default,
            group_chat: chat.group_chat?,
            agents: chat.group_chat? ? chat.agents.map { |a| { id: a.to_param, name: a.name } } : [],
            created_at: chat.created_at.iso8601
          }
        }, status: :created
      end

      private

      def resolve_agent_ids
        return nil if params[:agent_ids].blank?

        obfuscated_ids = Array(params[:agent_ids])
        real_ids = obfuscated_ids.filter_map { |oid| Agent.decode_id(oid) }
        agents = current_api_account.agents.active.where(id: real_ids)

        if agents.length != obfuscated_ids.length
          missing = obfuscated_ids.length - agents.length
          raise ActiveRecord::RecordNotFound, "#{missing} agent(s) not found or inactive"
        end

        agents.pluck(:id)
      end

      def conversation_json(chat)
        {
          id: chat.to_param,
          title: chat.title_or_default,
          summary: chat.summary,
          summary_stale: chat.summary_stale?,
          model: chat.model_label,
          group_chat: chat.group_chat?,
          message_count: chat.message_count,
          updated_at: chat.updated_at.iso8601
        }
      end

    end
  end
end
