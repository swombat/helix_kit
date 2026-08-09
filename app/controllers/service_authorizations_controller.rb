class ServiceAuthorizationsController < ApplicationController

  skip_before_action :set_current_account, only: :callback

  def create
    definition = Services::Definition.fetch(params.require(:provider))
    management_scope = params.require(:management_scope)
    authorize_management_scope!(management_scope)

    attempt, state = ServiceAuthorizationAttempt.begin!(
      account: current_account,
      user: Current.user,
      provider: definition.key,
      management_scope: management_scope,
      access_profile: params[:access_profile],
      return_path: return_path_for(management_scope)
    )

    redirect_to definition.adapter.authorization_url(
      attempt,
      state: state,
      redirect_uri: service_authorization_callback_url
    ), allow_other_host: true
  rescue Services::Definition::UnknownProvider, KeyError, ArgumentError, NotImplementedError => e
    redirect_back_or_to account_personal_services_path(current_account), alert: e.message
  end

  def callback
    attempt = ServiceAuthorizationAttempt.resolve!(params[:state])
    raise ActiveRecord::RecordNotFound unless attempt.user_id == Current.user.id
    Current.account = attempt.account

    if params[:error].present?
      attempt.consume!
      redirect_to attempt.return_path, alert: "Authorization was denied"
      return
    end

    result = attempt.definition.adapter.exchange_code(
      code: params.require(:code),
      attempt: attempt,
      redirect_uri: service_authorization_callback_url
    )

    connection = persist_connection!(attempt, result)
    attempt.consume!
    audit(:connect_service, connection,
          provider: connection.provider,
          management_scope: connection.management_scope,
          granted_scopes: connection.granted_scopes)
    redirect_to attempt.return_path, notice: "#{attempt.definition.name} connected"
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
    redirect_to root_path, alert: "Invalid or expired authorization"
  rescue Services::DropboxAdapter::Error => e
    redirect_to attempt&.return_path || root_path, alert: e.message
  end

  private

  def authorize_management_scope!(scope)
    case scope
    when "personal"
      true
    when "account_managed"
      raise Account::NotAuthorized unless current_account.service_credentials_manageable_by?(Current.user)
    else
      raise ArgumentError, "Unsupported connection ownership"
    end
  end

  def return_path_for(scope)
    scope == "account_managed" ?
      account_services_path(current_account) :
      account_personal_services_path(current_account)
  end

  def persist_connection!(attempt, result)
    connection = attempt.account.service_connections.find_or_initialize_by(
      provider: attempt.provider,
      external_subject_id: result.fetch(:external_subject_id)
    )

    if connection.persisted? && connection.connected_by_user_id != attempt.user_id
      raise Services::DropboxAdapter::Error, "That external identity is already connected by another account member"
    end

    connection.connected_by_user = attempt.user
    connection.external_identity = result[:external_identity]
    connection.label ||= result[:external_identity]
    connection.management_scope = attempt.management_scope
    connection.credential_kind = result.fetch(:credential_kind)
    connection.credential_payload_hash = result.fetch(:credential_payload)
    connection.credential_metadata = result.fetch(:credential_metadata)
    connection.status = "connected"
    connection.credential_revision += 1 if connection.persisted?
    connection.save!
    connection
  end

end
