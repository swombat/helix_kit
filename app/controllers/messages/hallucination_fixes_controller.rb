class Messages::HallucinationFixesController < Messages::BaseController

  def create
    @message.fix_hallucinated_tool_calls!
    redirect_to account_chat_path(@chat.account, @chat)
  rescue StandardError => e
    redirect_to account_chat_path(@chat.account, @chat), alert: "Failed to fix: #{e.message}"
  end

end
