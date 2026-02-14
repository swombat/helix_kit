module ChatScoped

  extend ActiveSupport::Concern

  included do
    require_feature_enabled :chats
    before_action :set_chat
  end

  private

  def set_chat
    # Use with_discarded to allow admins to find discarded chats for restore
    @chat = current_account.chats.with_discarded.find(params[:chat_id])
  end

  def require_respondable_chat
    return if @chat.respondable?

    respond_to do |format|
      format.html { redirect_back_or_to account_chat_path(@chat.account, @chat), alert: "This conversation is archived or deleted and cannot receive new messages" }
      format.json { render json: { error: "This conversation is archived or deleted" }, status: :unprocessable_entity }
    end
  end

end
