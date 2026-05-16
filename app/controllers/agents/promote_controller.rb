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
      redirect_to promote_account_agent_path(current_account, @agent), alert: "Promotion is already in progress"
      return
    end

    if current_account.github_pat.blank?
      redirect_to promote_account_agent_path(current_account, @agent), alert: "Add GitHub access before creating the agent repo"
      return
    end

    repo_name = params[:repo_name].to_s.parameterize.presence || "#{agent_slug}-agent"
    private_repo = ActiveModel::Type::Boolean.new.cast(params.fetch(:private_repo, true))
    repo_creator = AgentRepoCreator.new(
      account: current_account,
      agent: @agent,
      repo_name: repo_name,
      private_repo: private_repo
    )

    repo = repo_creator.create_repo!
    deploy_key = repo_creator.create_deploy_key!(repo)

    outbound_api_key = nil
    @agent.transaction do
      @agent.uuid ||= SecureRandom.uuid_v7
      outbound_api_key = ApiKey.generate_for(
        @agent.account.owner || Current.user,
        name: "agent:#{agent_slug}:outbound",
        agent: @agent
      )
      @agent.outbound_api_key = outbound_api_key
      @agent.trigger_bearer_token = "tr_#{SecureRandom.hex(24)}"
      @agent.runtime = "migrating"
      @agent.migration_started_at = Time.current
      @agent.github_repo_url = repo.html_url
      @agent.github_repo_owner = repo.owner
      @agent.github_repo_name = repo.name
      @agent.github_deploy_key_id = deploy_key.id
      @agent.github_deploy_key_priv = deploy_key.private_key
      @agent.save!
    end

    master_key = SecureRandom.base64(32)
    encrypted_credentials = AgentCredentialsEncryptor.new(
      @agent,
      master_key,
      outbound_token: outbound_api_key.raw_token,
      github_deploy_key: deploy_key.private_key
    ).encrypt
    deploy_yml = repo_creator.deploy_yml(repo)
    repo_creator.commit_runtime_files!(
      repo,
      identity_files: AgentIdentityExporter.new(@agent).files,
      credentials_yml_enc: encrypted_credentials,
      deploy_yml: deploy_yml
    )

    render inertia: "agents/promote", props: promotion_props.merge(
      generated_credentials: {
        master_key: master_key,
        credentials_yml_enc: encrypted_credentials,
        deploy_yml: deploy_yml,
        repo: repo.to_h
      }
    )
  rescue AgentRepoCreator::GitHubError => e
    redirect_to promote_account_agent_path(current_account, @agent), alert: e.message
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
      github_deploy_key: @agent.github_deploy_key_priv
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
    api_key = @agent.outbound_api_key
    @agent.update!(
      runtime: "inline",
      migration_started_at: nil,
      trigger_bearer_token: nil,
      outbound_api_key: nil
    )
    api_key&.destroy!

    redirect_to edit_account_agent_path(current_account, @agent), notice: "Promotion cancelled"
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
        conversation_id: chat.to_param
      }
    else
      chat.trigger_agent_response!(@agent)
      render json: { status: "requested", conversation_id: chat.to_param }
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_agent
    @agent = current_account.agents.find(params[:id])
  end

  def promotion_props
    {
      account: current_account.as_json,
      agent: @agent.as_json,
      github_configured: current_account.github_pat.present?,
      github_login: current_account.github_login,
      default_repo_name: "#{agent_slug}-agent",
      github_repo: github_repo_props,
      clone_url: github_ssh_clone_url,
      identity_export_url: identity_export_account_agent_path(current_account, @agent)
    }
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
