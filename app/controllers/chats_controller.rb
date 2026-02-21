class ChatsController < ApplicationController

  require_feature_enabled :chats
  before_action :set_chat, except: [ :index, :create, :new ]

  def index
    @chats = sidebar_chats

    render inertia: "chats/new", props: {
      chats: Chat.cached_json_for(Array(@chats), as: :sidebar_json),
      models: available_models,
      agents: available_agents(as: :list),
      account: current_account.as_json,
      file_upload_config: file_upload_config
    }
  end

  def new
    @chats = sidebar_chats

    render inertia: "chats/new", props: {
      chats: Chat.cached_json_for(@chats, as: :sidebar_json),
      account: current_account.as_json,
      models: available_models,
      agents: available_agents(as: :list),
      file_upload_config: file_upload_config
    }
  end

  def show
    props = { account: current_account.as_json }

    if inertia_prop_requested?(:chats)
      chats = sidebar_chats
      props[:chats] = Chat.cached_json_for(chats, as: :sidebar_json)
    end

    if inertia_prop_requested?(:messages)
      messages = @chat.messages_page
      has_more = messages.any? && @chat.messages.where("id < ?", messages.first.id).exists?
      props[:messages] = messages.collect(&:as_json)
      props[:has_more_messages] = has_more
      props[:oldest_message_id] = messages.first&.to_param
    end

    props[:chat] = chat_json_with_whiteboard if inertia_prop_requested?(:chat)
    props[:models] = available_models if inertia_prop_requested?(:models)
    props[:agents] = @chat.group_chat? ? @chat.agents.as_json(as: :list) : [] if inertia_prop_requested?(:agents)
    props[:available_agents] = available_agents(as: :list) if inertia_prop_requested?(:available_agents)
    props[:addable_agents] = addable_agents_for_chat(as: :list) if inertia_prop_requested?(:addable_agents)
    props[:file_upload_config] = file_upload_config if inertia_prop_requested?(:file_upload_config)
    props[:telegram_deep_link] = telegram_deep_link_for_chat if inertia_prop_requested?(:telegram_deep_link)

    render inertia: "chats/show", props: props
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

  def update
    @chat = current_account.chats.find(params[:id])

    if @chat.update(chat_params)
      redirect_to account_chat_path(current_account, @chat)
    else
      redirect_back_or_to account_chat_path(current_account, @chat), alert: @chat.errors.full_messages.to_sentence
    end
  end

  def destroy
    audit("destroy_chat", @chat)
    @chat.destroy!
    redirect_to account_chats_path(current_account)
  end

  private

  def sidebar_chats
    base_scope = current_account.chats

    if params[:show_deleted].present? && can_manage_account?
      chats = base_scope.with_discarded
    else
      chats = base_scope.kept
    end

    # Filter out agent-only chats unless site admin has toggled them on
    unless params[:show_agent_only].present? && Current.user&.site_admin
      chats = chats.not_agent_only
    end

    if params[:show_deleted].present? && can_manage_account?
      chats.latest
    else
      chats.active.latest + chats.archived.latest
    end
  end

  def set_chat
    # Use with_discarded to allow admins to find discarded chats for restore
    @chat = current_account.chats.with_discarded.find(params[:id])
  end

  def chat_params
    params.fetch(:chat, {})
      .permit(:model_id, :web_access, :manual_responses, :title)
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

  def available_agents(as: nil)
    if as.present?
      current_account.agents.active.as_json(as: as)
    else
      current_account.agents.active.as_json
    end
  end

  def addable_agents_for_chat(as: nil)
    return [] unless @chat.group_chat?
    scope = current_account.agents.active.where.not(id: @chat.agent_ids)
    as.present? ? scope.as_json(as: as) : scope.as_json
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

  def telegram_deep_link_for_chat
    telegram_agent = @chat.agents.detect(&:telegram_configured?)
    return nil unless telegram_agent

    existing_sub = telegram_agent.telegram_subscriptions.find_by(user: Current.user, blocked: false)
    return nil if existing_sub

    telegram_agent.telegram_deep_link_for(Current.user)
  end

  def can_manage_account?
    current_account.manageable_by?(Current.user)
  end

  def inertia_partial_request?
    request.headers["X-Inertia-Partial-Component"].present?
  end

  def inertia_partial_props
    @inertia_partial_props ||= (request.headers["X-Inertia-Partial-Data"] || "").split(",").map(&:strip)
  end

  def inertia_prop_requested?(prop)
    return true unless inertia_partial_request?
    return true if inertia_partial_props.empty?

    inertia_partial_props.include?(prop.to_s)
  end

end
