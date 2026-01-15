class ApiKeysController < ApplicationController

  before_action :set_key_request, only: [ :approve, :confirm_approve, :deny ]

  def index
    render inertia: "api_keys/index", props: {
      api_keys: Current.user.api_keys.by_creation.map { |k| api_key_json(k) }
    }
  end

  def create
    api_key = ApiKey.generate_for(Current.user, name: params[:name])

    render inertia: "api_keys/show", props: {
      api_key: api_key_json(api_key),
      raw_token: api_key.raw_token
    }
  end

  def destroy
    Current.user.api_keys.find(params[:id]).destroy!
    redirect_to api_keys_path, notice: "API key revoked"
  end

  # OAuth-style approval flow
  def approve
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

  def confirm_approve
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

  def deny
    if @key_request.pending?
      @key_request.deny!
    end
    redirect_to api_keys_path, notice: "Request denied"
  end

  private

  def set_key_request
    @key_request = ApiKeyRequest.find_by!(request_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to api_keys_path, alert: "Invalid request"
  end

  def api_key_json(key)
    {
      id: key.id,
      name: key.name,
      prefix: key.display_prefix,
      created_at: key.created_at.strftime("%b %d, %Y"),
      last_used_at: key.last_used_at&.strftime("%b %d, %Y at %l:%M %p"),
      last_used_ip: key.last_used_ip
    }
  end

end
