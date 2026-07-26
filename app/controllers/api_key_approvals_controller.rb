class ApiKeyApprovalsController < ApplicationController

  before_action :set_key_request

  def show
    if @key_request.expired?
      redirect_to external_access_path, alert: "This request has expired"
      return
    end

    if @key_request.approved? || @key_request.denied?
      redirect_to external_access_path, alert: "This request has already been processed"
      return
    end

    render inertia: "api_keys/approve", props: {
      client_name: @key_request.client_name,
      token: params[:token],
      expires_at: @key_request.expires_at.iso8601,
      accounts: Current.user.confirmed_accounts.enabled.map { |account| { id: account.id, name: account.name } },
      selected_account_id: current_account&.id
    }
  end

  def create
    if @key_request.expired? || !@key_request.pending?
      redirect_to external_access_path, alert: "This request is no longer valid"
      return
    end

    account = find_current_user_account!(params[:account_id])
    key_name = params[:key_name].presence || "#{@key_request.client_name} Key"
    @key_request.approve!(user: Current.user, account: account, key_name: key_name)

    render inertia: "api_keys/approved", props: {
      client_name: @key_request.client_name,
      manage_path: account_api_keys_path(account)
    }
  end

  def destroy
    @key_request.deny! if @key_request.pending?
    redirect_to external_access_path, notice: "Request denied"
  end

  private

  def set_key_request
    @key_request = ApiKeyRequest.find_by!(request_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to external_access_path, alert: "Invalid request"
  end

  def external_access_path
    account = @key_request&.api_key&.account || current_account
    account ? account_api_keys_path(account) : root_path
  end

end
