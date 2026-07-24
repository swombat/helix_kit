class Agents::PromoteController < ApplicationController

  before_action :set_agent
  before_action :require_account_owner!

  def show
    render inertia: "agents/promote", props: promotion_props
  end

  def github_access
    token = params.require(:github_pat).to_s.strip
    login = AgentRepoCreator.validate_token!(token)
    current_account.update!(github_pat: token, github_login: login)

    redirect_to promote_account_agent_path(current_account, @agent), notice: "GitHub access saved for @#{login}"
  rescue AgentRepoCreator::GitHubError => e
    redirect_to promote_account_agent_path(current_account, @agent), alert: e.message
  end

  def begin
    if @agent.external? || @agent.migrating?
      redirect_to hosting_settings_path, alert: "Promotion is already in progress"
      return
    end

    Agents::HostedProvisioning.new(
      agent: @agent,
      user: @agent.account.owner || Current.user
    ).prepare!(runtime: "migrating", started_at: Time.current)

    PromoteAgentJob.perform_later(@agent.id)

    redirect_to hosting_settings_path, notice: "Promoting #{@agent.name} to a hosted sandbox"
  rescue Agents::HostedProvisioning::ConfigurationError => e
    redirect_to hosting_settings_path, alert: e.message
  end

  def regenerate_credentials
    unless @agent.migrating?
      redirect_to promote_account_agent_path(current_account, @agent), alert: "Agent is not waiting for runtime deployment"
      return
    end

    if current_account.github_pat.blank?
      redirect_to promote_account_agent_path(current_account, @agent), alert: "Add GitHub access before regenerating credentials"
      return
    end

    if @agent.github_repo_owner.blank? || @agent.github_repo_name.blank? || @agent.github_deploy_key_priv.blank?
      redirect_to promote_account_agent_path(current_account, @agent), alert: "Agent repo metadata is incomplete; cancel and restart promotion"
      return
    end

    repo_creator = AgentRepoCreator.new(
      account: current_account,
      agent: @agent,
      repo_name: @agent.github_repo_name
    )
    repo = repo_creator.fetch_repo!(owner: @agent.github_repo_owner, name: @agent.github_repo_name)
    outbound_api_key = refresh_outbound_api_key!
    master_key = SecureRandom.base64(32)
    encrypted_credentials = AgentCredentialsEncryptor.new(
      @agent,
      master_key,
      outbound_token: outbound_api_key.raw_token,
      github_deploy_key: @agent.github_deploy_key_priv,
      provider_keys: current_account.ai_provider_keys
    ).encrypt
    deploy_yml = repo_creator.deploy_yml(repo)
    repo_creator.commit_runtime_files!(
      repo,
      identity_files: { "memory/.keep" => "" },
      credentials_yml_enc: encrypted_credentials,
      deploy_yml: deploy_yml
    )

    render inertia: "agents/promote", props: promotion_props.merge(
      generated_credentials: {
        master_key: master_key,
        credentials_yml_enc: encrypted_credentials,
        deploy_yml: deploy_yml,
        repo: repo.to_h,
        regenerated: true
      }
    )
  rescue AgentRepoCreator::GitHubError => e
    redirect_to promote_account_agent_path(current_account, @agent), alert: e.message
  end

  def identity_export
    send_data AgentIdentityExporter.new(@agent).build,
      filename: "#{agent_slug}-identity.tar.gz",
      type: "application/gzip"
  end

  def cancel
    if @agent.born_hosted?
      redirect_to onboarding_account_agent_path(current_account, @agent),
                  alert: "A born-hosted agent cannot be demoted to inline. Delete the agent explicitly if you do not want to continue setup."
      return
    end

    api_key = @agent.outbound_api_key
    @agent.update!(
      runtime: "inline",
      migration_started_at: nil,
      trigger_bearer_token: nil,
      outbound_api_key: nil,
      outbound_api_token: nil,
      restic_password: nil
    )
    api_key&.destroy!

    redirect_to hosting_settings_path, notice: "Promotion cancelled"
  end

  def send_test_request
    chat = current_account.chats.find_or_create_by!(title: "system: agent test for #{@agent.name}") do |record|
      record.model_id = "openrouter/auto"
      record.manual_responses = true
      record.agent_ids = [ @agent.id ]
    end
    chat.agents << @agent unless chat.agents.exists?(@agent.id)

    if @agent.external? || @agent.offline?
      result = ExternalAgentResponseRequest.new(
        agent: @agent,
        chat: chat,
        requested_by: Current.user.email_address,
        initiation_reason: "Promotion wizard test request"
      ).call

      render json: {
        status: result[:status].to_i.between?(200, 299) ? "runtime_reachable" : "transport_failed",
        transport_status: result[:status],
        conversation_id: chat.to_param,
        error: result.dig(:body, "error"),
        runtime_status: result.dig(:body, "status"),
        runtime_stderr: result.dig(:body, "stderr"),
        runtime_stdout: result.dig(:body, "stdout")
      }
    else
      chat.trigger_agent_response!(@agent)
      render json: { status: "requested", conversation_id: chat.to_param }
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def send_orientation
    unless @agent.external? && @agent.health_state == "healthy"
      render json: { error: "Agent must be healthy and externally hosted before orientation" }, status: :unprocessable_entity
      return
    end

    @agent.update!(orientation_requested_at: Time.current)
    result = ExternalAgentOrientationRequest.new(
      agent: @agent,
      requested_by: Current.user.email_address
    ).call

    ok = result[:status].to_i.between?(200, 299)
    @agent.update!(orientation_completed_at: Time.current) if ok
    render json: {
      status: ok ? "orientation_sent" : "transport_failed",
      transport_status: result[:status],
      oriented: result[:oriented],
      oriented_at: result[:oriented_at],
      error: result[:error] || result.dig(:body, "error"),
      runtime_status: result.dig(:body, "status"),
      runtime_stderr: result.dig(:body, "stderr"),
      runtime_stdout: result.dig(:body, "stdout")
    }, status: ok ? :ok : :bad_gateway
  end

  private

  def set_agent
    @agent = current_account.agents.find(params[:id])
  end

  def hosting_settings_path
    edit_account_agent_path(current_account, @agent, tab: "hosting")
  end

  def promotion_props
    {
      account: current_account.as_json,
      agent: @agent.as_json,
      github_configured: false,
      github_login: nil,
      default_repo_name: "#{agent_slug}-agent",
      hosted_agents: true,
      local_dev_endpoint_mode: Agents::Config.publish_ports?,
      github_repo: github_repo_props,
      clone_url: github_ssh_clone_url,
      identity_export_url: identity_export_account_agent_path(current_account, @agent),
      sandbox_status: sandbox_status,
      runtime_interactions: runtime_interactions
    }
  end

  def sandbox_status
    Agents::Sandbox.new(@agent).status
  end

  def runtime_interactions
    @agent.agent_runtime_interactions.recent.limit(10).map(&:as_debug_json)
  end

  def github_repo_props
    return unless @agent.github_repo_owner.present? && @agent.github_repo_name.present?

    {
      owner: @agent.github_repo_owner,
      name: @agent.github_repo_name,
      html_url: @agent.github_repo_url,
      ssh_url: github_ssh_clone_url
    }
  end

  def github_ssh_clone_url
    return unless @agent.github_repo_owner.present? && @agent.github_repo_name.present?

    "git@github.com:#{@agent.github_repo_owner}/#{@agent.github_repo_name}.git"
  end

  def agent_slug
    @agent.name.to_s.parameterize.presence || "agent-#{@agent.id}"
  end

  def refresh_outbound_api_key!
    old_api_key = @agent.outbound_api_key
    outbound_api_key = nil

    @agent.transaction do
      @agent.uuid ||= SecureRandom.uuid_v7
      @agent.trigger_bearer_token ||= "tr_#{SecureRandom.hex(24)}"
      @agent.update!(outbound_api_key: nil) if old_api_key
      old_api_key&.destroy!
      outbound_api_key = ApiKey.generate_for(
        @agent.account.owner || Current.user,
        name: "agent:#{agent_slug}:outbound",
        agent: @agent
      )
      @agent.update!(outbound_api_key: outbound_api_key)
    end

    outbound_api_key
  end

end
