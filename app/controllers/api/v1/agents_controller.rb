module Api
  module V1
    class AgentsController < BaseController

      def index
        agents = current_api_account.agents.active.by_name
        render json: { agents: agents.map { |a| agent_json(a) } }
      end

      def show
        agent = current_api_account.agents.find(params[:id])
        render json: { agent: agent_json(agent) }
      end

      private

      def agent_json(agent)
        {
          id: agent.to_param,
          name: agent.name,
          model: agent.model_label,
          colour: agent.colour,
          icon: agent.icon,
          active: agent.active?
        }
      end

    end
  end
end
