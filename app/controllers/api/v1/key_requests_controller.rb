module Api
  module V1
    class KeyRequestsController < ActionController::API

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Request not found" }, status: :not_found
      end

      def create
        request_record = ApiKeyRequest.create_request(client_name: params[:client_name])

        render json: {
          request_token: request_record.request_token,
          approval_url: api_key_approval_url(request_record.request_token),
          poll_url: api_v1_key_request_url(request_record.request_token),
          expires_at: request_record.expires_at.iso8601
        }, status: :created
      end

      def show
        request_record = ApiKeyRequest.find_by!(request_token: params[:id])

        response = {
          status: request_record.status_for_client,
          client_name: request_record.client_name
        }

        if request_record.approved?
          raw_token = request_record.retrieve_approved_token!
          if raw_token
            response[:api_key] = raw_token
            response[:user_email] = request_record.api_key.user.email_address
          end
        end

        render json: response
      end

    end
  end
end
