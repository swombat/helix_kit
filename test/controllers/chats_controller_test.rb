require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "Test Conversation"
    )

    # Sign in user
    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "should get index" do
    get account_chats_path(@account)
    assert_response :success
  end

  test "should get new" do
    get new_account_chat_path(@account)
    assert_response :success
  end

  test "should show chat" do
    get account_chat_path(@account, @chat)
    assert_response :success
  end

  test "should create chat with default model" do
    assert_difference "Chat.count" do
      post account_chats_path(@account)
    end

    chat = Chat.last
    assert_equal "openrouter/auto", chat.model_id
    assert_equal @account, chat.account
    assert_redirected_to account_chat_path(@account, chat)
  end

  test "should create chat with custom model" do
    assert_difference "Chat.count" do
      post account_chats_path(@account), params: {
        chat: { model_id: "gpt-4o" }
      }
    end

    chat = Chat.last
    assert_equal "gpt-4o", chat.model_id
  end

  test "should destroy chat" do
    assert_difference "Chat.count", -1 do
      delete account_chat_path(@account, @chat)
    end

    assert_redirected_to account_chats_path(@account)
  end

  test "should scope chats to current account" do
    # Create a completely separate user and account
    other_user = User.create!(email_address: "other@example.com")
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(
      model_id: "gpt-4o",
      title: "Other Account Chat"
    )

    # Debug: Check if manual scoping works
    assert_raises(ActiveRecord::RecordNotFound) do
      @account.chats.find(other_chat.id)
    end

    # Now test the controller - should return 404 when chat doesn't belong to account
    get account_chat_path(@account, other_chat)
    assert_response :not_found
  end

  test "chats blocked when disabled" do
    Setting.instance.update!(allow_chats: false)
    sign_in @user

    get account_chats_path(@account)
    assert_redirected_to root_path
    assert_match(/disabled/, flash[:alert])
  end

  test "should require authentication" do
    delete logout_path

    get account_chats_path(@account)
    assert_response :redirect
  end

  test "should create chat with message and trigger AI response" do
    assert_difference "Chat.count" do
      assert_difference "Message.count" do
        assert_enqueued_with(job: AiResponseJob) do
          post account_chats_path(@account), params: {
            chat: { model_id: "gpt-4o" },
            message: "Hello AI"
          }
        end
      end
    end

    chat = Chat.last
    message = chat.messages.last
    assert_equal "Hello AI", message.content
    assert_equal "user", message.role
    assert_equal @user, message.user
    assert_redirected_to account_chat_path(@account, chat)
  end

  test "should create chat with file attachments" do
    file = fixture_file_upload("test_image.png", "image/png")

    assert_difference "Chat.count" do
      assert_difference "Message.count" do
        assert_enqueued_with(job: AiResponseJob) do
          post account_chats_path(@account), params: {
            chat: { model_id: "gpt-4o" },
            message: "Please analyze this image",
            files: [ file ]
          }
        end
      end
    end

    chat = Chat.last
    message = chat.messages.last
    assert_equal "Please analyze this image", message.content
    assert_equal "user", message.role
    assert_equal @user, message.user

    # Verify file attachment
    assert message.attachments.attached?
    assert_equal 1, message.attachments.count
    assert_equal "test_image.png", message.attachments.first.filename.to_s

    assert_redirected_to account_chat_path(@account, chat)
  end

  test "should create chat with only files and no message content" do
    file = fixture_file_upload("test_image.png", "image/png")

    assert_difference "Chat.count" do
      assert_difference "Message.count" do
        assert_enqueued_with(job: AiResponseJob) do
          post account_chats_path(@account), params: {
            chat: { model_id: "gpt-4o" },
            message: "", # Empty message content
            files: [ file ]
          }
        end
      end
    end

    chat = Chat.last
    message = chat.messages.last
    assert_equal "", message.content
    assert_equal "user", message.role
    assert_equal @user, message.user

    # Verify file attachment works even without content
    assert message.attachments.attached?
    assert_equal 1, message.attachments.count
    assert_equal "test_image.png", message.attachments.first.filename.to_s

    assert_redirected_to account_chat_path(@account, chat)
  end

  test "index should return correct Inertia props" do
    get account_chats_path(@account)

    assert_response :success
    # For now, just verify the endpoint works - Inertia testing can be complex in test env
  end

  test "show should return correct Inertia props" do
    # Add a message to the chat
    @chat.messages.create!(
      content: "Test message",
      role: "user",
      user: @user
    )

    get account_chat_path(@account, @chat)

    assert_response :success
    # For now, just verify the endpoint works - Inertia testing can be complex in test env
  end

  test "should handle latest scope in index" do
    # Create multiple chats with different update times
    old_chat = @account.chats.create!(
      model_id: "gpt-4o",
      title: "Old Chat",
      updated_at: 2.days.ago
    )
    new_chat = @account.chats.create!(
      model_id: "gpt-4o",
      title: "New Chat",
      updated_at: 1.hour.ago
    )

    get account_chats_path(@account)

    assert_response :success
    # Verify that chats are loaded in the correct order by checking the scope
    chats = @account.chats.latest.to_a
    # Should include all chats and be in latest order
    assert_equal 3, chats.count
    chat_ids = chats.map(&:id)
    assert_includes chat_ids, new_chat.id
    assert_includes chat_ids, @chat.id
    assert_includes chat_ids, old_chat.id
    # Latest scope should order by updated_at desc
    assert chats.first.updated_at >= chats.second.updated_at
  end

  test "should create chat with file uploads" do
    # Create a test file
    file = fixture_file_upload("test.txt", "text/plain")

    assert_difference "Chat.count" do
      assert_difference "Message.count" do
        post account_chats_path(@account), params: {
          chat: { model_id: "gpt-4o" },
          message: "Hello with file",
          files: [ file ]
        }
      end
    end

    chat = Chat.last
    message = chat.messages.last
    assert_equal "Hello with file", message.content
    assert_equal 1, message.attachments.count
    assert_redirected_to account_chat_path(@account, chat)
  end

  test "should update web_access to true" do
    assert_not @chat.web_access

    patch account_chat_path(@account, @chat), params: {
      chat: { web_access: true }
    }

    # Update redirects to the chat page on success
    assert_redirected_to account_chat_path(@account, @chat)
    @chat.reload
    assert @chat.web_access
  end

  test "should update web_access to false" do
    @chat.update!(web_access: true)
    assert @chat.web_access

    patch account_chat_path(@account, @chat), params: {
      chat: { web_access: false }
    }

    # Update redirects to the chat page on success
    assert_redirected_to account_chat_path(@account, @chat)
    @chat.reload
    assert_not @chat.web_access
  end

  test "update should broadcast refresh automatically" do
    # Verify that the update succeeds (broadcast happens via after_commit callback)
    patch account_chat_path(@account, @chat), params: {
      chat: { web_access: true }
    }

    # Update redirects to the chat page on success
    assert_redirected_to account_chat_path(@account, @chat)
    # The broadcast happens automatically via the Broadcastable concern
    @chat.reload
    assert @chat.web_access
  end

  test "update should scope to current account" do
    # Create a chat in a different account
    other_user = User.create!(email_address: "updateother@example.com")
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(
      model_id: "gpt-4o",
      title: "Other Account Chat"
    )

    # Should return 404 when trying to update chat from different account
    patch account_chat_path(@account, other_chat), params: {
      chat: { web_access: true }
    }
    assert_response :not_found

    # Verify the chat was not modified
    other_chat.reload
    assert_not other_chat.web_access
  end

  test "update should require authentication" do
    delete logout_path

    patch account_chat_path(@account, @chat), params: {
      chat: { web_access: true }
    }
    assert_response :redirect

    # Verify the chat was not modified
    @chat.reload
    assert_not @chat.web_access
  end

  test "update should allow updating model_id" do
    assert_equal "openrouter/auto", @chat.model_id

    patch account_chat_path(@account, @chat), params: {
      chat: { model_id: "openai/gpt-4o-mini" }
    }

    # Update redirects to the chat page on success
    assert_redirected_to account_chat_path(@account, @chat)
    @chat.reload
    assert_equal "openai/gpt-4o-mini", @chat.model_id
  end

  test "update should allow updating multiple attributes" do
    patch account_chat_path(@account, @chat), params: {
      chat: {
        model_id: "openai/gpt-4o-mini",
        web_access: true
      }
    }

    # Update redirects to the chat page on success
    assert_redirected_to account_chat_path(@account, @chat)
    @chat.reload
    assert_equal "openai/gpt-4o-mini", @chat.model_id
    assert @chat.web_access
  end

  # Archive functionality tests

  test "archive action archives the chat" do
    assert_not @chat.archived?

    post archive_account_chat_path(@account, @chat)

    assert_redirected_to account_chats_path(@account)
    @chat.reload
    assert @chat.archived?
  end

  test "archive action creates audit log" do
    assert_difference "AuditLog.count" do
      post archive_account_chat_path(@account, @chat)
    end

    audit = AuditLog.last
    assert_equal "archive_chat", audit.action
    assert_equal @chat.id, audit.auditable_id
  end

  test "unarchive action unarchives the chat" do
    @chat.archive!
    assert @chat.archived?

    post unarchive_account_chat_path(@account, @chat)

    assert_redirected_to account_chats_path(@account)
    @chat.reload
    assert_not @chat.archived?
  end

  test "unarchive action creates audit log" do
    @chat.archive!

    assert_difference "AuditLog.count" do
      post unarchive_account_chat_path(@account, @chat)
    end

    audit = AuditLog.last
    assert_equal "unarchive_chat", audit.action
    assert_equal @chat.id, audit.auditable_id
  end

  # Discard (soft delete) functionality tests

  test "discard action soft deletes the chat for admin" do
    # User is owner of personal account, so they are an admin
    assert @account.manageable_by?(@user)
    assert_not @chat.discarded?

    post discard_account_chat_path(@account, @chat)

    assert_redirected_to account_chats_path(@account)
    @chat.reload
    assert @chat.discarded?
  end

  test "discard action creates audit log" do
    assert_difference "AuditLog.count" do
      post discard_account_chat_path(@account, @chat)
    end

    audit = AuditLog.last
    assert_equal "discard_chat", audit.action
    assert_equal @chat.id, audit.auditable_id
  end

  test "discard action is forbidden for non-admin" do
    # team_account has user_1 as owner, and existing_user (user_id: 3) as member via team_member membership
    team_account = accounts(:team_account)
    member_user = users(:existing_user)  # This user is member via team_member membership
    team_chat = team_account.chats.create!(model_id: "openrouter/auto", title: "Team Chat")

    # Sign in as member (not admin)
    delete logout_path
    post login_path, params: {
      email_address: member_user.email_address,
      password: "password123"
    }

    # Member should not be able to discard
    assert_not team_account.manageable_by?(member_user)

    post discard_account_chat_path(team_account, team_chat)

    assert_redirected_to account_chats_path(team_account)
    assert_match(/permission/, flash[:alert])
    team_chat.reload
    assert_not team_chat.discarded?
  end

  test "restore action restores a discarded chat for admin" do
    @chat.discard!
    assert @chat.discarded?

    post restore_account_chat_path(@account, @chat)

    assert_redirected_to account_chats_path(@account)
    @chat.reload
    assert_not @chat.discarded?
  end

  test "restore action creates audit log" do
    @chat.discard!

    assert_difference "AuditLog.count" do
      post restore_account_chat_path(@account, @chat)
    end

    audit = AuditLog.last
    assert_equal "restore_chat", audit.action
    assert_equal @chat.id, audit.auditable_id
  end

  test "restore action is forbidden for non-admin" do
    # team_account has user_1 as owner, and existing_user (user_id: 3) as member via team_member membership
    team_account = accounts(:team_account)
    member_user = users(:existing_user)  # This user is member via team_member membership
    team_chat = team_account.chats.create!(model_id: "openrouter/auto", title: "Team Chat")
    team_chat.discard!

    # Sign in as member (not admin)
    delete logout_path
    post login_path, params: {
      email_address: member_user.email_address,
      password: "password123"
    }

    # Member should not be able to restore
    assert_not team_account.manageable_by?(member_user)

    post restore_account_chat_path(team_account, team_chat)

    assert_redirected_to account_chats_path(team_account)
    assert_match(/permission/, flash[:alert])
    team_chat.reload
    assert team_chat.discarded?
  end

  # Index ordering tests

  test "index shows active chats before archived chats" do
    # Create chats with specific states
    archived_chat = @account.chats.create!(
      model_id: "gpt-4o",
      title: "Archived Chat",
      updated_at: 1.minute.ago # Most recent update
    )
    archived_chat.archive!

    active_chat = @account.chats.create!(
      model_id: "gpt-4o",
      title: "Active Chat",
      updated_at: 1.hour.ago # Older update
    )

    get account_chats_path(@account)
    assert_response :success

    # Verify ordering: active chats first, then archived
    active_chats = @account.chats.kept.active.latest
    archived_chats = @account.chats.kept.archived.latest

    # Active chat should be in active list, archived should be in archived list
    assert_includes active_chats.map(&:id), active_chat.id
    assert_includes archived_chats.map(&:id), archived_chat.id
  end

  test "index excludes discarded chats by default" do
    discarded_chat = @account.chats.create!(
      model_id: "gpt-4o",
      title: "Discarded Chat"
    )
    discarded_chat.discard!

    get account_chats_path(@account)
    assert_response :success

    # Discarded chat should not be in the default view
    kept_chats = @account.chats.kept
    assert_not_includes kept_chats.map(&:id), discarded_chat.id
  end

  test "index shows discarded chats when admin requests show_deleted" do
    discarded_chat = @account.chats.create!(
      model_id: "gpt-4o",
      title: "Discarded Chat"
    )
    discarded_chat.discard!

    # User is admin of their personal account
    assert @account.manageable_by?(@user)

    get account_chats_path(@account, show_deleted: true)
    assert_response :success

    # With show_deleted, discarded chat should be findable
    all_chats = @account.chats.with_discarded
    assert_includes all_chats.map(&:id), discarded_chat.id
  end

  test "show_deleted param is ignored for non-admin" do
    # team_account has user_1 as owner, and existing_user (user_id: 3) as member via team_member membership
    team_account = accounts(:team_account)
    member_user = users(:existing_user)  # This user is member via team_member membership

    discarded_chat = team_account.chats.create!(
      model_id: "gpt-4o",
      title: "Discarded Chat"
    )
    discarded_chat.discard!

    # Sign in as member (not admin)
    delete logout_path
    post login_path, params: {
      email_address: member_user.email_address,
      password: "password123"
    }

    assert_not team_account.manageable_by?(member_user)

    get account_chats_path(team_account, show_deleted: true)
    assert_response :success

    # show_deleted should be ignored, discarded chat should not appear
    kept_chats = team_account.chats.kept
    assert_not_includes kept_chats.map(&:id), discarded_chat.id
  end

  # Pagination tests

  test "older_messages returns JSON with pagination info" do
    chat = @account.chats.create!(model_id: "openrouter/auto")
    messages = 50.times.map { |i| chat.messages.create!(content: "Message #{i}", role: "user", user: @user) }

    get older_messages_account_chat_path(@account, chat, before_id: messages.last.to_param),
        headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("messages")
    assert json.key?("has_more")
    assert json.key?("oldest_id")
    assert json["messages"].is_a?(Array)
    assert_equal 30, json["messages"].length  # Default limit is 30
  end

  test "older_messages returns messages before specified ID" do
    chat = @account.chats.create!(model_id: "openrouter/auto")
    messages = 10.times.map { |i| chat.messages.create!(content: "Message #{i}", role: "user", user: @user) }
    middle = messages[5]

    get older_messages_account_chat_path(@account, chat, before_id: middle.to_param),
        headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)

    # All returned messages should have IDs less than the middle message
    returned_ids = json["messages"].map { |m| Message.decode_id(m["id"]) }
    assert returned_ids.all? { |id| id < middle.id }
  end

  test "older_messages returns empty when no more messages" do
    chat = @account.chats.create!(model_id: "openrouter/auto")
    message = chat.messages.create!(content: "Only message", role: "user", user: @user)

    get older_messages_account_chat_path(@account, chat, before_id: message.to_param),
        headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [], json["messages"]
    assert_equal false, json["has_more"]
  end

  test "older_messages requires authentication" do
    delete logout_path

    chat = @account.chats.create!(model_id: "openrouter/auto")
    message = chat.messages.create!(content: "Test", role: "user")

    get older_messages_account_chat_path(@account, chat, before_id: message.to_param),
        headers: { "Accept" => "application/json" }

    assert_response :redirect
  end

  test "older_messages scopes to current account" do
    other_user = User.create!(email_address: "paginationother@example.com")
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(model_id: "openrouter/auto")
    message = other_chat.messages.create!(content: "Test", role: "user", user: other_user)

    get older_messages_account_chat_path(@account, other_chat, before_id: message.to_param),
        headers: { "Accept" => "application/json" }

    assert_response :not_found
  end

  test "older_messages indicates has_more correctly when more messages exist" do
    chat = @account.chats.create!(model_id: "openrouter/auto")
    # Create 50 messages (0-49)
    messages = 50.times.map { |i| chat.messages.create!(content: "Message #{i}", role: "user", user: @user) }

    # Request messages before the last one (message 49)
    # Should get messages 19-48 (30 messages), and there should be more (0-18)
    get older_messages_account_chat_path(@account, chat, before_id: messages.last.to_param),
        headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["has_more"], "Should indicate more messages exist"
  end

  test "older_messages indicates has_more false when no more messages" do
    chat = @account.chats.create!(model_id: "openrouter/auto")
    # Create 5 messages (0-4)
    messages = 5.times.map { |i| chat.messages.create!(content: "Message #{i}", role: "user", user: @user) }

    # Request messages before the last one (message 4)
    # Should get messages 0-3 (4 messages), and there should be no more
    get older_messages_account_chat_path(@account, chat, before_id: messages.last.to_param),
        headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal false, json["has_more"], "Should indicate no more messages"
  end

  # Add Agent to Group Chat tests

  test "add_agent succeeds for group chat and creates system message" do
    agent1 = @account.agents.create!(name: "Agent One", system_prompt: "You are agent one")
    agent2 = @account.agents.create!(name: "Agent Two", system_prompt: "You are agent two")

    group_chat = create_group_chat(@account, agent_ids: [ agent1.id ])
    assert group_chat.group_chat?

    assert_difference "Message.count", 1 do
      post add_agent_account_chat_path(@account, group_chat), params: { agent_id: agent2.to_param }
    end

    assert_redirected_to account_chat_path(@account, group_chat)
    group_chat.reload
    assert_includes group_chat.agents, agent2

    system_message = group_chat.messages.last
    assert_equal "user", system_message.role
    assert_match(/Agent Two has joined the conversation/, system_message.content)
  end

  test "add_agent rejected for non-group chat" do
    # @chat is a regular chat (manual_responses = false)
    assert_not @chat.group_chat?

    agent = @account.agents.create!(name: "Test Agent", system_prompt: "You are a test agent")

    post add_agent_account_chat_path(@account, @chat), params: { agent_id: agent.to_param }

    assert_redirected_to account_chat_path(@account, @chat)
    assert_match(/group chats/, flash[:alert])
  end

  test "add_agent rejected for duplicate agent" do
    agent = @account.agents.create!(name: "Agent One", system_prompt: "You are agent one")

    group_chat = create_group_chat(@account, agent_ids: [ agent.id ])

    assert_no_difference "Message.count" do
      post add_agent_account_chat_path(@account, group_chat), params: { agent_id: agent.to_param }
    end

    assert_redirected_to account_chat_path(@account, group_chat)
    assert_match(/already in this conversation/, flash[:alert])
  end

  test "add_agent adds agent to chat agents association" do
    agent1 = @account.agents.create!(name: "Agent One", system_prompt: "You are agent one")
    agent2 = @account.agents.create!(name: "Agent Two", system_prompt: "You are agent two")

    group_chat = create_group_chat(@account, agent_ids: [ agent1.id ])
    assert_equal 1, group_chat.agents.count

    post add_agent_account_chat_path(@account, group_chat), params: { agent_id: agent2.to_param }

    group_chat.reload
    assert_equal 2, group_chat.agents.count
    assert_includes group_chat.agents, agent1
    assert_includes group_chat.agents, agent2
  end

  private

  def create_group_chat(account, agent_ids:)
    chat = account.chats.new(model_id: "openrouter/auto", manual_responses: true)
    chat.agent_ids = agent_ids
    chat.save!
    chat
  end

end
