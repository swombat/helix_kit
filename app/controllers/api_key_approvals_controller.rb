class ApiKeyApprovalsController < ApplicationController

  before_action :set_key_request

  def show
    if @key_request.expired?
      redirect_to api_keys_path, alert: "This request has expired"
      return
    end

    if @key_request.approved? || @key_request.denied?
      redirect_to api_keys_path, alert: "This request has already been processed"
      return
    end

    render inertia: "api_keys/approve", props: {
      client_name: @key_request.client_name,
      token: params[:token],
      expires_at: @key_request.expires_at.iso8601
    }
  end

  def create
    if @key_request.expired? || !@key_request.pending?
      redirect_to api_keys_path, alert: "This request is no longer valid"
      return
    end

    key_name = params[:key_name].presence || "#{@key_request.client_name} Key"
    @key_request.approve!(user: Current.user, key_name: key_name)

    render inertia: "api_keys/approved", props: {
      client_name: @key_request.client_name
    }
  end

  def destroy
    @key_request.deny! if @key_request.pending?
    redirect_to api_keys_path, notice: "Request denied"
  end

  private

  def set_key_request
    @key_request = ApiKeyRequest.find_by!(request_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to api_keys_path, alert: "Invalid request"
  end

end
