class ApiKeysController < ApplicationController

  before_action :require_account

  def index
    unless params[:account_id]
      redirect_to account_api_keys_path(current_account)
      return
    end

    render inertia: "api_keys/index", props: {
      account: current_account,
      api_keys: managed_api_keys.by_creation.map { |k| api_key_json(k) }
    }
  end

  def create
    api_key = ApiKey.generate_for(Current.user, account: current_account, name: params[:name])

    render inertia: "api_keys/show", props: {
      account: current_account,
      api_key: api_key_json(api_key),
      raw_token: api_key.raw_token
    }
  end

  def destroy
    managed_api_keys.find(params[:id]).destroy!
    redirect_to account_api_keys_path(current_account), notice: "External access key revoked"
  end

  private

  def managed_api_keys
    Current.user.api_keys.where(account: current_account)
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
