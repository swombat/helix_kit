require "test_helper"

class ApiKeyRequestTest < ActiveSupport::TestCase

  setup do
    @user = users(:confirmed_user)
  end

  test "creates request with pending status" do
    request = ApiKeyRequest.create_request(client_name: "Claude Code")

    assert_equal "pending", request.status
    assert request.request_token.present?
    assert request.expires_at > Time.current
  end

  test "request_token is unique" do
    request1 = ApiKeyRequest.create_request(client_name: "Client 1")
    request2 = ApiKeyRequest.create_request(client_name: "Client 2")

    assert_not_equal request1.request_token, request2.request_token
  end

  test "approving creates api key and stores encrypted token" do
    request = ApiKeyRequest.create_request(client_name: "Claude Code")
    api_key = request.approve!(user: @user, key_name: "Test Key")

    assert_equal "approved", request.reload.status
    assert_equal api_key, request.api_key
    assert request.approved_token_encrypted.present?
  end

  test "retrieve_approved_token returns token once" do
    request = ApiKeyRequest.create_request(client_name: "Claude Code")
    request.approve!(user: @user, key_name: "Test Key")

    token = request.retrieve_approved_token!
    assert token.start_with?("hx_")

    # Second retrieval returns nil
    assert_nil request.retrieve_approved_token!
  end

  test "retrieved token authenticates correctly" do
    request = ApiKeyRequest.create_request(client_name: "Claude Code")
    api_key = request.approve!(user: @user, key_name: "Test Key")

    token = request.retrieve_approved_token!
    authenticated_key = ApiKey.authenticate(token)

    assert_equal api_key, authenticated_key
  end

  test "expired request returns expired status" do
    request = ApiKeyRequest.create_request(client_name: "Claude Code")
    request.update_column(:expires_at, 1.minute.ago)

    assert_equal "expired", request.status_for_client
    assert request.expired?
    assert_not request.pending?
  end

  test "pending request returns pending status" do
    request = ApiKeyRequest.create_request(client_name: "Claude Code")

    assert_equal "pending", request.status_for_client
    assert request.pending?
    assert_not request.expired?
  end

  test "deny changes status" do
    request = ApiKeyRequest.create_request(client_name: "Claude Code")
    request.deny!

    assert_equal "denied", request.status
    assert request.denied?
  end

  test "approved? returns true for approved requests" do
    request = ApiKeyRequest.create_request(client_name: "Claude Code")
    request.approve!(user: @user, key_name: "Test Key")

    assert request.approved?
  end

  test "validates client_name presence" do
    request = ApiKeyRequest.new(
      request_token: SecureRandom.urlsafe_base64(32),
      status: "pending",
      expires_at: 10.minutes.from_now
    )

    assert_not request.valid?
    assert_includes request.errors[:client_name], "can't be blank"
  end

  test "validates client_name length" do
    request = ApiKeyRequest.new(
      request_token: SecureRandom.urlsafe_base64(32),
      client_name: "a" * 101,
      status: "pending",
      expires_at: 10.minutes.from_now
    )

    assert_not request.valid?
    assert request.errors[:client_name].any? { |e| e.include?("too long") }
  end

  test "validates status inclusion" do
    request = ApiKeyRequest.new(
      request_token: SecureRandom.urlsafe_base64(32),
      client_name: "Test",
      status: "invalid_status",
      expires_at: 10.minutes.from_now
    )

    assert_not request.valid?
    assert request.errors[:status].any? { |e| e.include?("is not included") }
  end

  test "pending scope returns only pending requests" do
    pending_request = ApiKeyRequest.create_request(client_name: "Pending")
    denied_request = ApiKeyRequest.create_request(client_name: "Denied")
    denied_request.deny!

    assert_includes ApiKeyRequest.pending, pending_request
    assert_not_includes ApiKeyRequest.pending, denied_request
  end

end
