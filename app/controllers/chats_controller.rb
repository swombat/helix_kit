class ChatsController < ApplicationController

  require_feature_enabled :chats
  before_action :set_chat, except: [ :index, :create, :new ]

  def index
    @chats = current_account.chats.includes(:messages).latest

    render inertia: "chats/new", props: {
      chats: @chats.as_json,
      models: available_models,
      agents: available_agents,
      account: current_account.as_json,
      file_upload_config: file_upload_config
    }
  end

  def new
    @chats = current_account.chats.latest

    render inertia: "chats/new", props: {
      chats: @chats.as_json,
      account: current_account.as_json,
      models: available_models,
      agents: available_agents,
      file_upload_config: file_upload_config
    }
  end

  def show
    @chats = current_account.chats.latest
    @messages = @chat.messages.includes(:user, :agent).with_attached_attachments.sorted

    render inertia: "chats/show", props: {
      chat: @chat.as_json,
      chats: @chats.as_json,
      messages: @messages.all.collect(&:as_json),
      account: current_account.as_json,
      models: available_models,
      agents: @chat.group_chat? ? @chat.agents.as_json : [],
      file_upload_config: file_upload_config
    }
  end

  def create
    chat_attrs = chat_params
    chat_attrs[:manual_responses] = true if params[:agent_ids].present?

    # Decode obfuscated agent IDs
    decoded_agent_ids = params[:agent_ids].present? ? Agent.decode_id(params[:agent_ids]) : nil

    @chat = current_account.chats.create_with_message!(
      chat_attrs,
      message_content: params[:message],
      user: Current.user,
      files: params[:files],
      agent_ids: decoded_agent_ids
    )
    audit("create_chat", @chat, **chat_params.to_h)
    redirect_to account_chat_path(current_account, @chat)
  end

  def trigger_agent
    @agent = @chat.agents.find(params[:agent_id])
    @chat.trigger_agent_response!(@agent)

    respond_to do |format|
      format.html { redirect_to account_chat_path(current_account, @chat) }
      format.json { head :ok }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(current_account, @chat), alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def trigger_all_agents
    @chat.trigger_all_agents_response!

    respond_to do |format|
      format.html { redirect_to account_chat_path(current_account, @chat) }
      format.json { head :ok }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(current_account, @chat), alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def update
    @chat = current_account.chats.find(params[:id])

    if @chat.update(chat_params)
      head :ok
    else
      render json: { errors: @chat.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    audit("destroy_chat", @chat)
    @chat.destroy!
    redirect_to account_chats_path(current_account)
  end

  private

  def set_chat
    @chat = current_account.chats.find(params[:id])
  end

  def chat_params
    params.fetch(:chat, {})
      .permit(:model_id, :web_access, :manual_responses)
  end

  def available_models
    @available_models ||= Chat::MODELS
  end

  def file_upload_config
    {
      acceptable_types: Message::ACCEPTABLE_FILE_TYPES.values.flatten,
      max_size: Message::MAX_FILE_SIZE
    }
  end

  def available_agents
    current_account.agents.active.as_json
  end

end
