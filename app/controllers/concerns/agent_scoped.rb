module AgentScoped

  extend ActiveSupport::Concern

  included do
    require_feature_enabled :agents
    before_action :set_agent
  end

  private

  def set_agent
    @agent = current_account.agents.find(params[:agent_id])
  end

end
