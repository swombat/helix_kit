class ChatsController < ApplicationController

  require_feature_enabled :chats
  before_action :set_chat, except: [ :index, :create, :new ]
  before_action :require_admin, only: [ :discard, :restore ]
  before_action :require_site_admin, only: [ :moderate_all ]

  def index
    # Show active chats first (kept and not archived), then archived chats at the bottom
    # Optionally include discarded chats if admin requests them
    base_scope = current_account.chats

    if params[:show_deleted].present? && can_manage_account?
      # Admin view: show all including discarded
      @chats = base_scope.with_discarded.latest
    else
      # Normal view: kept chats, active first then archived
      active_chats = base_scope.kept.active.latest
      archived_chats = base_scope.kept.archived.latest
      @chats = active_chats + archived_chats
    end

    render inertia: "chats/new", props: {
      chats: Array(@chats).map(&:cached_json),
      models: available_models,
      agents: available_agents,
      account: current_account.as_json,
      file_upload_config: file_upload_config
    }
  end

  def new
    # Same ordering as index: active first, then archived
    base_scope = current_account.chats
    active_chats = base_scope.kept.active.latest
    archived_chats = base_scope.kept.archived.latest
    @chats = active_chats + archived_chats

    render inertia: "chats/new", props: {
      chats: @chats.map(&:cached_json),
      account: current_account.as_json,
      models: available_models,
      agents: available_agents,
      file_upload_config: file_upload_config
    }
  end

  def show
    # Same ordering as index: active first, then archived
    base_scope = current_account.chats
    active_chats = base_scope.kept.active.latest
    archived_chats = base_scope.kept.archived.latest
    @chats = active_chats + archived_chats

    # Use paginated messages - load most recent 30 by default
    @messages = @chat.messages_page
    @has_more = @messages.any? && @chat.messages.where("id < ?", @messages.first.id).exists?

    render inertia: "chats/show", props: {
      chat: chat_json_with_whiteboard,
      chats: @chats.map(&:cached_json),
      messages: @messages.collect(&:as_json),
      has_more_messages: @has_more,
      oldest_message_id: @messages.first&.to_param,
      account: current_account.as_json,
      models: available_models,
      agents: @chat.group_chat? ? @chat.agents.as_json : [],
      available_agents: available_agents,
      file_upload_config: file_upload_config,
      telegram_deep_link: telegram_deep_link_for_chat
    }
  end

  def older_messages
    @messages = @chat.messages_page(before_id: params[:before_id])
    @has_more = @messages.any? && @chat.messages.where("id < ?", @messages.first.id).exists?

    render json: {
      messages: @messages.collect(&:as_json),
      has_more: @has_more,
      oldest_id: @messages.first&.to_param
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

  def assign_agent
    if @chat.manual_responses?
      redirect_back_or_to account_chat_path(current_account, @chat),
        alert: "This chat is already assigned to an agent"
      return
    end

    agent = current_account.agents.find(params[:agent_id])

    previous_model = @chat.model_label || @chat.model_id || "an AI model"

    @chat.transaction do
      @chat.agents << agent
      @chat.update!(manual_responses: true)

      @chat.messages.create!(
        role: "user",
        content: "[System Notice] This conversation is now being handled by #{agent.name}. " \
                 "The previous messages were with #{previous_model}, a base AI model that had no system prompt, " \
                 "identity, or memories. You are now taking over this conversation with your " \
                 "full capabilities and personality."
      )
    end

    audit("assign_agent_to_chat", @chat, agent_id: agent.id)
    redirect_to account_chat_path(current_account, @chat)
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
      redirect_to account_chat_path(current_account, @chat)
    else
      redirect_back_or_to account_chat_path(current_account, @chat), alert: @chat.errors.full_messages.to_sentence
    end
  end

  # Archive a chat - any account member can do this
  def archive
    @chat.archive!
    audit("archive_chat", @chat)
    redirect_back_or_to account_chats_path(current_account), notice: "Chat archived"
  end

  # Unarchive a chat - any account member can do this
  def unarchive
    @chat.unarchive!
    audit("unarchive_chat", @chat)
    redirect_back_or_to account_chats_path(current_account), notice: "Chat restored from archive"
  end

  # Soft delete a chat - only admins can do this
  def discard
    @chat.discard!
    audit("discard_chat", @chat)
    redirect_to account_chats_path(current_account), notice: "Chat deleted"
  end

  # Restore a soft-deleted chat - only admins can do this
  def restore
    @chat.undiscard!
    audit("restore_chat", @chat)
    redirect_back_or_to account_chats_path(current_account), notice: "Chat restored"
  end

  # Queue moderation for all unmoderated messages in the chat - site admins only
  def moderate_all
    count = @chat.queue_moderation_for_all_messages
    audit("moderate_all_messages", @chat, count: count)

    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(current_account, @chat), notice: "Queued moderation for #{count} messages" }
      format.json { render json: { queued: count } }
    end
  end

  def destroy
    audit("destroy_chat", @chat)
    @chat.destroy!
    redirect_to account_chats_path(current_account)
  end

  private

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

  def require_admin
    unless can_manage_account?
      redirect_back_or_to account_chats_path(current_account), alert: "You don't have permission to perform this action"
    end
  end

  def require_site_admin
    unless Current.user&.site_admin
      redirect_back_or_to account_chats_path(current_account), alert: "You don't have permission to perform this action"
    end
  end

end
