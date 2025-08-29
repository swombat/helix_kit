require "test_helper"

class AccountRegistrationFlowTest < ActionDispatch::IntegrationTest

  test "complete user registration flow with account creation" do
    # Track initial state
    initial_user_count = User.count
    initial_account_count = Account.count
    initial_account_user_count = AccountUser.count

    # Step 1: Visit signup page
    get signup_path
    assert_response :success
    assert_equal "registrations/signup", inertia_component

    # Step 2: Submit email for registration
    email = "newuser@example.com"
    assert_difference "User.count", 1 do
      assert_difference "Account.count", 1 do
        assert_difference "AccountUser.count", 1 do
          post signup_path, params: { email_address: email }
        end
      end
    end
    assert_redirected_to check_email_path
    assert_equal "Please check your email to confirm your account.", flash[:notice]

    # Step 3: Verify database state after registration
    user = User.last
    account = Account.last
    account_user = AccountUser.last

    # User should be created without password but with confirmation token
    assert_equal email, user.email_address
    assert_nil user.password_digest
    assert_not user.confirmed?
    assert_not_nil user.confirmation_token
    assert_not_nil user.confirmation_sent_at
    # CRITICAL: User should have default_account_id set to their personal account
    assert_equal account.id, user.default_account_id

    # Personal Account should be created with correct attributes
    assert_equal "#{email}'s Account", account.name
    assert account.personal?
    assert_not_nil account.slug
    assert_equal user, account.owner

    # AccountUser should link user to their personal account with correct role
    assert_equal user, account_user.user
    assert_equal account, account_user.account
    assert_equal "owner", account_user.role
    assert_not account_user.confirmed?
    assert_not_nil account_user.confirmation_token
    assert_not_nil account_user.confirmation_sent_at

    # Step 4: Visit confirmation link - check both token approaches
    user_token = user.confirmation_token
    account_user_token = account_user.confirmation_token

    assert_not_nil user_token, "User should have confirmation token"
    assert_not_nil account_user_token, "AccountUser should have confirmation token"

    # Use the user token for now to match existing working test pattern
    token = user_token

    get email_confirmation_path(token: token)
    assert_redirected_to set_password_path
    assert_equal "Email confirmed! Please set your password.", flash[:notice]

    # Step 5: Verify confirmation state
    user.reload
    account_user.reload

    # Both User and AccountUser should be confirmed
    assert account_user.confirmed?
    assert_nil account_user.confirmation_token
    assert user.confirmed? # This should work via the account_user confirmation

    # User confirmation token should be cleared
    assert_nil user.confirmation_token

    # User should still not have a password
    assert_nil user.password_digest

    # Step 6: Access set password page
    follow_redirect!
    assert_response :success

    # Step 7: Set password
    password = "securepassword123"
    patch set_password_path, params: {
      password: password,
      password_confirmation: password
    }
    assert_redirected_to root_path
    assert_equal "Account setup complete! Welcome!", flash[:notice]

    # Step 8: Verify user can now login
    user.reload
    assert_not_nil user.password_digest
    assert user.authenticate(password)
    assert user.can_login?

    # Step 9: Logout and test login
    delete logout_path

    post login_path, params: {
      email_address: email,
      password: password
    }
    assert_redirected_to root_path
    assert_equal "You have been signed in.", flash[:notice]

    # Verify session state by accessing authenticated content
    get root_path
    assert_response :success
  end

  test "existing unconfirmed user re-registration preserves account relationships" do
    # Step 1: Create existing unconfirmed user with account
    email = "existing@example.com"
    user = User.create!(
      email_address: email,
      confirmed_at: nil
    )
    account = user.personal_account
    account_user = user.account_users.first
    original_token = account_user.confirmation_token
    original_account_id = account.id

    # Verify initial state
    assert_not user.confirmed?
    assert_not account_user.confirmed?
    assert_equal account.id, user.default_account_id

    # Store counts for comparison (there may be fixture data)
    user_count = User.count
    account_count = Account.count
    account_user_count = AccountUser.count

    # Step 2: Try to register again with same email
    assert_equal user_count, User.count, "User count should remain the same"
    assert_equal account_count, Account.count, "Account count should remain the same"
    assert_equal account_user_count, AccountUser.count, "AccountUser count should remain the same"

    post signup_path, params: { email_address: email }

    # Verify counts didn't change
    assert_equal user_count, User.count
    assert_equal account_count, Account.count
    assert_equal account_user_count, AccountUser.count
    assert_redirected_to check_email_path
    assert_equal "Confirmation email resent. Please check your inbox.", flash[:notice]

    # Step 3: Verify tokens were updated but relationships preserved
    user.reload
    account_user.reload

    # New confirmation token should be generated
    assert_not_equal original_token, account_user.confirmation_token
    assert_not_nil account_user.confirmation_sent_at

    # Account relationship should be preserved
    assert_equal original_account_id, account.id
    assert_equal account.id, user.default_account_id
    assert_equal user, account.owner

    # User and AccountUser should still be unconfirmed
    assert_not user.confirmed?
    assert_not account_user.confirmed?

    # Step 4: Confirm with new token
    new_token = account_user.confirmation_token
    get email_confirmation_path(token: new_token)
    assert_redirected_to set_password_path

    user.reload
    account_user.reload

    # Both should be confirmed now
    assert user.confirmed?
    assert account_user.confirmed?
    assert_nil account_user.confirmation_token
  end

  test "confirmed user with account cannot re-register" do
    # Create a confirmed user with complete account structure
    email = "fullyconfirmed@example.com"
    user = User.create!(
      email_address: email,
      password: "password123",
      confirmed_at: Time.current
    )

    # Ensure user has account structure (mimics what happens in production)
    account = user.personal_account
    account_user = user.account_users.first
    account_user.update!(confirmed_at: Time.current)

    assert user.confirmed?
    assert account_user.confirmed?
    assert_not_nil user.password_digest

    # Try to register with same email - should reject
    post signup_path, params: { email_address: email }

    assert_redirected_to signup_path
    follow_redirect!
    errors = inertia_shared_props["errors"]
    assert errors.present?
    assert errors["email_address"].present?
    assert errors["email_address"].any? { |e| e.match?(/already registered/i) }
  end

  test "account creation with proper owner assignment" do
    email = "owner@example.com"

    # Register user
    post signup_path, params: { email_address: email }

    user = User.last
    account = Account.last
    account_user = AccountUser.last

    # Verify account ownership structure
    assert_equal "owner", account_user.role
    assert account_user.owner?
    assert account_user.admin?
    assert account_user.can_manage?

    # Verify account type and constraints
    assert account.personal?
    assert_equal user, account.owner
    assert_equal [ user ], account.users.to_a

    # Verify user has correct default account
    assert_equal account, user.default_account

    # Confirm the account user
    account_user.confirm!

    # Verify user is now considered confirmed
    user.reload
    assert user.confirmed?
    assert user.member_of?(account)
    assert user.owns?(account)
    assert user.can_manage?(account)
  end

  test "database state consistency after each registration step" do
    email = "consistency@example.com"

    # Step 1: Registration
    post signup_path, params: { email_address: email }

    user = User.last
    account = Account.last
    account_user = AccountUser.last

    # Verify ALL database relationships are correct
    assert_equal user.id, account_user.user_id
    assert_equal account.id, account_user.account_id
    assert_equal account.id, user.default_account_id

    # Verify counts
    assert_equal 1, user.accounts.count
    assert_equal 1, user.account_users.count
    assert_equal 1, account.users.count
    assert_equal 1, account.account_users.count

    # Step 2: Email confirmation
    token = account_user.confirmation_token
    get email_confirmation_path(token: token)

    user.reload
    account_user.reload

    # Verify confirmation doesn't break relationships
    assert_equal account.id, user.default_account_id
    assert_equal 1, user.accounts.count
    assert_equal 1, account.users.count
    assert account_user.confirmed?

    # Step 3: Password setting
    follow_redirect!
    patch set_password_path, params: {
      password: "password123",
      password_confirmation: "password123"
    }

    user.reload

    # Verify password setting doesn't break anything
    assert_equal account.id, user.default_account_id
    assert_not_nil user.password_digest
    assert user.can_login?
    assert_equal 1, user.accounts.count
    assert_equal 1, account.users.count
  end

  test "update_column calls work correctly without runtime errors" do
    # This test specifically verifies the update_column bug doesn't occur
    email = "updatecolumn@example.com"

    # Register user - this triggers multiple update_column calls
    assert_difference "User.count", 1 do
      post signup_path, params: { email_address: email }
    end

    user = User.last
    account = user.personal_account

    # Verify update_column for default_account_id worked
    assert_not_nil user.default_account_id
    assert_equal account.id, user.default_account_id

    # Confirm email - this also triggers update_column calls
    account_user = user.account_users.first
    token = account_user.confirmation_token

    # This should not raise any runtime errors from update_column
    assert_nothing_raised do
      get email_confirmation_path(token: token)
    end

    assert_redirected_to set_password_path

    user.reload
    # Verify update_column for confirmation_token clearing worked
    assert_nil user.confirmation_token
  end

  test "user default_account_id is properly maintained throughout flow" do
    # This test specifically targets the update_column bug
    email = "defaultaccount@example.com"

    # Step 1: Registration
    post signup_path, params: { email_address: email }

    user = User.last
    account = Account.last

    # Immediately after creation, default_account_id should be set
    assert_not_nil user.default_account_id
    assert_equal account.id, user.default_account_id

    # Reload from database to ensure it's persisted
    user = User.find(user.id)
    assert_equal account.id, user.default_account_id

    # Step 2: Email confirmation shouldn't affect default_account_id
    account_user = user.account_users.first
    token = account_user.confirmation_token
    get email_confirmation_path(token: token)

    user.reload
    assert_equal account.id, user.default_account_id

    # Step 3: Password setting shouldn't affect default_account_id
    follow_redirect!
    patch set_password_path, params: {
      password: "password123",
      password_confirmation: "password123"
    }

    user.reload
    assert_equal account.id, user.default_account_id

    # Step 4: Login shouldn't affect default_account_id
    delete logout_path
    post login_path, params: {
      email_address: email,
      password: "password123"
    }

    user.reload
    assert_equal account.id, user.default_account_id
  end

  test "confirmation token management between user and account_user" do
    email = "tokens@example.com"

    # Step 1: Registration creates tokens
    post signup_path, params: { email_address: email }

    user = User.last
    account_user = AccountUser.last

    # Both should have confirmation tokens initially
    user_token = user.confirmation_token
    account_user_token = account_user.confirmation_token

    assert_not_nil user_token
    assert_not_nil account_user_token

    # Step 2: Confirm via AccountUser token (new system)
    get email_confirmation_path(token: account_user_token)
    assert_redirected_to set_password_path

    user.reload
    account_user.reload

    # AccountUser should be confirmed with token cleared
    assert account_user.confirmed?
    assert_nil account_user.confirmation_token

    # User token should also be cleared for consistency
    assert_nil user.confirmation_token

    # User should be considered confirmed via account_user
    assert user.confirmed?
  end

  test "confirmation token management with legacy user token" do
    # Test backward compatibility for old confirmation tokens
    email = "legacy@example.com"

    # Create user via normal registration to get proper tokens
    post signup_path, params: { email_address: email }

    user = User.last
    account = user.personal_account
    account_user = user.account_users.first

    # Store the user's confirmation token for legacy confirmation
    legacy_user_token = user.confirmation_token

    assert_not_nil account
    assert_not_nil account_user
    assert_equal account.id, user.default_account_id
    assert_not_nil legacy_user_token

    # Confirm via legacy User token (testing backward compatibility path)
    get email_confirmation_path(token: legacy_user_token)
    assert_redirected_to set_password_path

    user.reload
    account_user.reload

    # Both should be confirmed
    assert user.confirmed?
    assert account_user.confirmed?

    # Tokens should be cleared
    assert_nil user.confirmation_token
    assert_nil account_user.confirmation_token
  end

  test "re-registration with existing unconfirmed user updates tokens correctly" do
    email = "reregister@example.com"

    # Step 1: Create unconfirmed user
    post signup_path, params: { email_address: email }

    user = User.last
    account_user = AccountUser.last
    original_user_token = user.confirmation_token
    original_account_user_token = account_user.confirmation_token
    original_account_id = user.default_account_id

    # Wait a moment to ensure timestamps will be different
    sleep 0.01

    # Step 2: Re-register same email
    assert_no_difference "User.count" do
      assert_no_difference "Account.count" do
        assert_no_difference "AccountUser.count" do
          post signup_path, params: { email_address: email }
        end
      end
    end

    user.reload
    account_user.reload

    # Tokens should be updated
    assert_not_equal original_user_token, user.confirmation_token
    assert_not_equal original_account_user_token, account_user.confirmation_token

    # Account relationship should be preserved
    assert_equal original_account_id, user.default_account_id

    # Timestamps should be updated
    assert user.confirmation_sent_at > 1.second.ago
    assert account_user.confirmation_sent_at > 1.second.ago

    # New token should work
    new_token = account_user.confirmation_token
    get email_confirmation_path(token: new_token)
    assert_redirected_to set_password_path
  end

  test "personal account creation enforces single user constraint" do
    email = "single@example.com"

    # Create user with personal account
    post signup_path, params: { email_address: email }

    user = User.last
    account = user.personal_account

    assert account.personal?
    assert_equal 1, account.users.count

    # Verify we cannot add another user to personal account
    other_user = User.create!(
      email_address: "other@example.com",
      confirmed_at: Time.current
    )

    assert_raises ActiveRecord::RecordInvalid do
      account.add_user!(other_user, role: "owner", skip_confirmation: true)
    end

    # Account should still have only one user
    assert_equal 1, account.users.count
    assert_equal user, account.users.first
  end

  test "invalid email prevents user and account creation" do
    invalid_emails = [
      "",
      "invalid",
      "@example.com",
      "user@",
      "user space@example.com"
    ]

    invalid_emails.each do |invalid_email|
      assert_no_difference "User.count" do
        assert_no_difference "Account.count" do
          assert_no_difference "AccountUser.count" do
            post signup_path, params: { email_address: invalid_email }
          end
        end
      end

      assert_redirected_to signup_path
      follow_redirect!

      errors = inertia_shared_props["errors"]
      assert errors.present?
      assert errors["email_address"].present?
    end
  end

  test "session management during registration flow" do
    email = "session@example.com"

    # Step 1: Registration redirects to check email (not authenticated)
    post signup_path, params: { email_address: email }
    assert_redirected_to check_email_path

    user = User.last
    account_user = user.account_users.first

    # Step 2: Email confirmation redirects to set password
    get email_confirmation_path(token: user.confirmation_token)
    assert_redirected_to set_password_path
    # Email confirmation should redirect to set password
    assert_redirected_to set_password_path

    # Step 3: Setting password should authenticate
    follow_redirect!
    patch set_password_path, params: {
      password: "password123",
      password_confirmation: "password123"
    }

    # Now should be authenticated - verify by accessing root path
    follow_redirect!
    assert_response :success

    # Verify logout works
    delete logout_path
    assert_redirected_to root_path
  end

  test "personal account slug generation and uniqueness" do
    # Test that account slugs are generated correctly and uniquely
    emails = [
      "user1@example.com",
      "user2@example.com",
      "user-1@example.com"  # This could generate similar slug
    ]

    slugs = []

    emails.each do |email|
      post signup_path, params: { email_address: email }

      account = Account.last

      # Should have a slug
      assert_not_nil account.slug
      assert account.slug.present?

      # Should be unique
      assert_not_includes slugs, account.slug
      slugs << account.slug

      # Should be based on email
      expected_base = "#{email}'s Account".parameterize
      assert account.slug.start_with?(expected_base.split("-").first)
    end
  end

  test "account user role validation during registration" do
    email = "roletest@example.com"

    post signup_path, params: { email_address: email }

    user = User.last
    account = user.personal_account
    account_user = user.account_users.first

    # Should be owner of personal account
    assert_equal "owner", account_user.role
    assert account_user.owner?

    # Personal accounts should only allow owner role
    account_user.role = "member"
    assert_not account_user.valid?
    assert account_user.errors[:role].present?

    account_user.role = "admin"
    assert_not account_user.valid?
    assert account_user.errors[:role].present?

    # Owner should still be valid
    account_user.role = "owner"
    assert account_user.valid?
  end

  test "user confirmation status via account_users" do
    email = "confirmstatus@example.com"

    # Create unconfirmed user
    post signup_path, params: { email_address: email }

    user = User.last
    account_user = user.account_users.first

    # Should be unconfirmed
    assert_not user.confirmed?
    assert_not account_user.confirmed?

    # Confirm the account_user
    account_user.confirm!
    user.reload

    # User should be considered confirmed via account_user
    assert user.confirmed?
    assert account_user.confirmed?

    # User's own confirmed_at should still be nil (confirmation is via account_user)
    assert_nil user.confirmed_at
    assert_not_nil account_user.confirmed_at
  end

  test "update_column operations are resilient and work correctly" do
    # This test specifically targets the update_column bug scenario
    # where calling update_column with incorrect parameters would cause runtime errors
    email = "updatecolumntest@example.com"

    # Step 1: Normal registration creates user with account
    post signup_path, params: { email_address: email }

    user = User.last
    account = user.personal_account
    account_user = user.account_users.first

    # Verify the critical update_column call in set_user_default_account worked
    assert_not_nil user.default_account_id, "default_account_id should be set by update_column"
    assert_equal account.id, user.default_account_id

    # Step 2: Email confirmation triggers more update_column calls
    account_user_token = account_user.confirmation_token

    # Confirm via AccountUser token
    get email_confirmation_path(token: account_user_token)
    assert_redirected_to set_password_path

    user.reload
    account_user.reload

    # Verify update_column calls for token clearing worked
    assert_nil user.confirmation_token, "User confirmation_token should be cleared by update_column"
    assert_nil account_user.confirmation_token, "AccountUser confirmation_token should be cleared by update"

    # Verify user is properly confirmed
    assert user.confirmed?
    assert account_user.confirmed?

    # Step 3: Verify database integrity after all update_column operations
    # These would fail if update_column was called with wrong parameters
    assert_equal account.id, user.default_account_id
    assert_equal user, account.owner
    assert_equal account, user.default_account
    assert user.member_of?(account)
    assert user.owns?(account)
  end

end
