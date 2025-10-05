class ChatsController < ApplicationController

  require_feature_enabled :chats
  before_action :set_chat, except: [ :index, :create, :new ]

  def index
    @chats = current_account.chats.includes(:messages).latest

    render inertia: "chats/index", props: {
      chats: @chats.as_json,
      models: available_models,
      account: current_account.as_json
    }
  end

  def new
    @chats = current_account.chats.latest

    render inertia: "chats/new", props: {
      chats: @chats.as_json,
      account: current_account.as_json,
      models: available_models
    }
  end

  def show
    @chats = current_account.chats.latest
    @messages = @chat.messages.includes(attachments_attachments: :blob).sorted

    render inertia: "chats/show", props: {
      chat: @chat.as_json,
      chats: @chats.as_json,
      messages: @messages.all.collect(&:as_json),
      account: current_account.as_json,
      models: available_models,
      file_upload_config: {
        acceptable_types: Message::ACCEPTABLE_FILE_TYPES.values.flatten,
        max_size: Message::MAX_FILE_SIZE
      }
    }
  end

  def create
    @chat = current_account.chats.create_with_message!(
      chat_params,
      message_content: params[:message],
      user: Current.user,
      files: params[:files]
    )
    audit("create_chat", @chat, **chat_params.to_h)
    redirect_to account_chat_path(current_account, @chat)
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
      .permit(:model_id)
  end

  def available_models
    @available_models ||= Chat::MODELS
  end

end
