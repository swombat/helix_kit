class WhiteboardsController < ApplicationController

  require_feature_enabled :agents
  before_action :set_whiteboard, only: [ :update ]

  def index
    @whiteboards = current_account.whiteboards.active.by_name
    chat_counts = Chat.where(active_whiteboard_id: @whiteboards.pluck(:id))
                      .group(:active_whiteboard_id)
                      .count

    render inertia: "whiteboards/index", props: {
      whiteboards: @whiteboards.map { |w| whiteboard_json(w, chat_counts[w.id] || 0) },
      account: current_account.as_json
    }
  end

  def update
    if params[:expected_revision].present? && @whiteboard.revision != params[:expected_revision].to_i
      render json: {
        error: "conflict",
        current_content: @whiteboard.content,
        current_revision: @whiteboard.revision
      }, status: :conflict
      return
    end

    if @whiteboard.update(whiteboard_params.merge(last_edited_by: Current.user))
      head :ok
    else
      render json: { errors: @whiteboard.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_whiteboard
    @whiteboard = current_account.whiteboards.active.find(params[:id])
  end

  def whiteboard_params
    params.require(:whiteboard).permit(:content)
  end

  def whiteboard_json(whiteboard, active_chat_count = 0)
    {
      id: whiteboard.id,
      name: whiteboard.name,
      summary: whiteboard.summary,
      content: whiteboard.content,
      content_length: whiteboard.content.to_s.length,
      revision: whiteboard.revision,
      last_edited_at: whiteboard.last_edited_at&.strftime("%b %d at %l:%M %p"),
      editor_name: whiteboard.editor_name,
      active_chat_count: active_chat_count
    }
  end

end
