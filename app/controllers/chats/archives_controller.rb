class Chats::ArchivesController < ApplicationController

  include ChatScoped

  # POST /accounts/:account_id/chats/:chat_id/archive
  def create
    @chat.archive!
    audit("archive_chat", @chat)
    redirect_back_or_to account_chats_path(current_account), notice: "Chat archived"
  end

  # DELETE /accounts/:account_id/chats/:chat_id/archive
  def destroy
    @chat.unarchive!
    audit("unarchive_chat", @chat)
    redirect_back_or_to account_chats_path(current_account), notice: "Chat restored from archive"
  end

end
