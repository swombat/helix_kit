module Api
  module V1
    class ConversationsController < BaseController

      def index
        chats = conversations_scope.kept.active.latest.limit(100)
        render json: { conversations: chats.map { |c| conversation_json(c) } }
      end

      def show
        chat = conversations_scope.find(params[:id])
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
        if current_api_agent
          chat = create_agent_scoped_conversation!

          render json: {
            conversation: {
              id: chat.to_param,
              title: chat.title_or_default,
              group_chat: chat.group_chat?,
              agents: chat.agents.map { |a| { id: a.to_param, name: a.name } },
              created_at: chat.created_at.iso8601
            }
          }, status: :created
          return
        end

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

      def conversations_scope
        return current_api_agent.chats if current_api_agent

        current_api_account.chats
      end

      def create_agent_scoped_conversation!
        agent_ids = ([ current_api_agent.id ] + Array(resolve_agent_ids)).uniq

        current_api_account.chats.transaction do
          chat = current_api_account.chats.new(
            model_id: params[:model_id] || current_api_agent.model_id || "openrouter/auto",
            title: params[:title],
            manual_responses: true,
            initiated_by_agent: current_api_agent,
            initiation_reason: params[:reason]
          )
          chat.agent_ids = agent_ids
          chat.save!

          if params[:message].present?
            chat.messages.create!(
              role: "assistant",
              agent: current_api_agent,
              content: params[:message]
            )
          end

          chat
        end
      end

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
