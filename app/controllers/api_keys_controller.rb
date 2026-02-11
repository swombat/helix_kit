class ApiKeysController < ApplicationController

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

  private

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
