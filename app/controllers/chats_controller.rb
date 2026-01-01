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
      chat: chat_json_with_whiteboard,
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

  def fork
    new_title = params[:title].presence || "#{@chat.title_or_default} (Fork)"
    forked_chat = @chat.fork_with_title!(new_title)
    audit("fork_chat", forked_chat, source_chat_id: @chat.id)
    redirect_to account_chat_path(current_account, forked_chat)
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
      acceptable_extensions: Message::ACCEPTABLE_EXTENSIONS,
      max_size: Message::MAX_FILE_SIZE
    }
  end

  def available_agents
    current_account.agents.active.as_json
  end

  def chat_json_with_whiteboard
    json = @chat.as_json
    if @chat.active_whiteboard && !@chat.active_whiteboard.deleted?
      json[:active_whiteboard] = {
        id: @chat.active_whiteboard.id,
        name: @chat.active_whiteboard.name,
        content: @chat.active_whiteboard.content,
        revision: @chat.active_whiteboard.revision,
        last_edited_at: @chat.active_whiteboard.last_edited_at&.strftime("%b %d at %l:%M %p"),
        editor_name: @chat.active_whiteboard.editor_name
      }
    end
    json
  end

end
