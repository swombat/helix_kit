require "test_helper"

module Api
  module V1
    class KeyRequestsControllerTest < ActionDispatch::IntegrationTest

      test "creates key request" do
        post api_v1_key_requests_url, params: { client_name: "Claude Code" }
        assert_response :created

        json = JSON.parse(response.body)
        assert json["request_token"].present?
        assert json["approval_url"].present?
        assert json["poll_url"].present?
        assert json["expires_at"].present?
      end

      test "creates key request with client name" do
        post api_v1_key_requests_url, params: { client_name: "My CLI Tool" }
        assert_response :created

        request = ApiKeyRequest.last
        assert_equal "My CLI Tool", request.client_name
      end

      test "shows pending request status" do
        request_record = ApiKeyRequest.create_request(client_name: "Claude Code")

        get api_v1_key_request_url(request_record.request_token)
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal "pending", json["status"]
        assert_equal "Claude Code", json["client_name"]
      end

      test "shows approved request with token" do
        user = users(:confirmed_user)
        request_record = ApiKeyRequest.create_request(client_name: "Claude Code")
        request_record.approve!(user: user, key_name: "Test")

        get api_v1_key_request_url(request_record.request_token)
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal "approved", json["status"]
        assert json["api_key"].start_with?("hx_")
        assert_equal user.email_address, json["user_email"]
      end

      test "returns token only once" do
        user = users(:confirmed_user)
        request_record = ApiKeyRequest.create_request(client_name: "Claude Code")
        request_record.approve!(user: user, key_name: "Test")

        # First request gets the token
        get api_v1_key_request_url(request_record.request_token)
        json = JSON.parse(response.body)
        assert json["api_key"].present?

        # Second request does not get the token
        get api_v1_key_request_url(request_record.request_token)
        json = JSON.parse(response.body)
        assert_nil json["api_key"]
        assert_equal "approved", json["status"]
      end

      test "expired request returns expired status" do
        request_record = ApiKeyRequest.create_request(client_name: "Claude Code")
        request_record.update_column(:expires_at, 1.minute.ago)

        get api_v1_key_request_url(request_record.request_token)
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal "expired", json["status"]
      end

      test "denied request returns denied status" do
        request_record = ApiKeyRequest.create_request(client_name: "Claude Code")
        request_record.deny!

        get api_v1_key_request_url(request_record.request_token)
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal "denied", json["status"]
      end

      test "returns 404 for unknown request token" do
        get api_v1_key_request_url("nonexistent_token")
        assert_response :not_found

        json = JSON.parse(response.body)
        assert_equal "Request not found", json["error"]
      end

    end
  end
end
