module Api
  module V1
    class WhiteboardsController < BaseController

      rescue_from ActiveRecord::StaleObjectError do
        render json: { error: "Whiteboard was modified by another user" }, status: :conflict
      end

      def index
        whiteboards = current_api_account.whiteboards.active.by_name
        render json: { whiteboards: whiteboards.map { |w| whiteboard_summary(w) } }
      end

      def show
        whiteboard = current_api_account.whiteboards.active.find(params[:id])
        render json: {
          whiteboard: {
            id: whiteboard.to_param,
            name: whiteboard.name,
            content: whiteboard.content,
            summary: whiteboard.summary,
            lock_version: whiteboard.lock_version,
            last_edited_at: whiteboard.last_edited_at&.iso8601,
            editor_name: whiteboard.editor_name
          }
        }
      end

      def update
        whiteboard = current_api_account.whiteboards.active.find(params[:id])

        whiteboard.lock_version = params[:lock_version] if params[:lock_version].present?
        whiteboard.update!(content: params[:content], last_edited_by: current_api_user)

        render json: { whiteboard: { id: whiteboard.to_param, lock_version: whiteboard.lock_version } }
      end

      private

      def whiteboard_summary(whiteboard)
        {
          id: whiteboard.to_param,
          name: whiteboard.name,
          summary: whiteboard.summary,
          content_length: whiteboard.content.to_s.length,
          lock_version: whiteboard.lock_version
        }
      end

    end
  end
end
