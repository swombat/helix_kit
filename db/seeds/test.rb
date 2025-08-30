# Test-specific seed data for Playwright Component Tests
# This file is only loaded when RAILS_ENV=test

# Create a test user for login tests (fully confirmed with account)
test_user = User.find_or_create_by(email_address: 'test@example.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.first_name = 'Test'
  user.last_name = 'User'
end

# Create personal account for test user if not exists
test_account = Account.find_or_create_by(
  name: "Test User's Account",
  account_type: 0, # personal
  slug: 'test-users-account'
)

# Link test user to account
AccountUser.find_or_create_by(
  user: test_user,
  account: test_account
) do |au|
  au.role = 'owner'
  au.confirmed_at = Time.current
end

# Create another confirmed user for testing duplicate email
existing_user = User.find_or_create_by(email_address: 'existing@example.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.first_name = 'Existing'
  user.last_name = 'User'
end

existing_account = Account.find_or_create_by(
  name: "Existing User's Account",
  account_type: 0,
  slug: 'existing-users-account'
)

AccountUser.find_or_create_by(
  user: existing_user,
  account: existing_account
) do |au|
  au.role = 'owner'
  au.confirmed_at = Time.current
end

# Create an unconfirmed user (signed up but not confirmed email)
unconfirmed_user = User.find_or_create_by(email_address: 'unconfirmed@example.com') do |user|
  user.password = nil # No password set yet
end

unconfirmed_account = Account.find_or_create_by(
  name: "Unconfirmed User's Account",
  account_type: 0,
  slug: 'unconfirmed-users-account'
)

AccountUser.find_or_create_by(
  user: unconfirmed_user,
  account: unconfirmed_account
) do |au|
  au.role = 'owner'
  au.confirmation_token = SecureRandom.hex(32)
  au.confirmation_sent_at = 1.hour.ago
  au.confirmed_at = nil # Not confirmed yet
end

# Create a user who needs password reset
password_reset_user = User.find_or_create_by(email_address: 'needsreset@example.com') do |user|
  user.password = 'oldpassword123'
  user.password_confirmation = 'oldpassword123'
  user.first_name = 'Needs'
  user.last_name = 'Reset'
end

reset_account = Account.find_or_create_by(
  name: "Password Reset User's Account",
  account_type: 0,
  slug: 'password-reset-users-account'
)

AccountUser.find_or_create_by(
  user: password_reset_user,
  account: reset_account
) do |au|
  au.role = 'owner'
  au.confirmed_at = 1.day.ago
end

# Create a user with no password set (e.g., OAuth signup)
no_password_user = User.find_or_create_by(email_address: 'nopassword@example.com') do |user|
  user.first_name = 'No'
  user.last_name = 'Password'
  # No password set
end

no_password_account = Account.find_or_create_by(
  name: "No Password User's Account",
  account_type: 0,
  slug: 'no-password-users-account'
)

AccountUser.find_or_create_by(
  user: no_password_user,
  account: no_password_account
) do |au|
  au.role = 'owner'
  au.confirmed_at = 1.day.ago
end

# Create a team account with multiple users
team_account = Account.find_or_create_by(
  name: "Test Team",
  account_type: 1, # team
  slug: 'test-team'
)

# Add test user as team owner
AccountUser.find_or_create_by(
  user: test_user,
  account: team_account
) do |au|
  au.role = 'owner'
  au.confirmed_at = 1.day.ago
end

# Add existing user as team member
AccountUser.find_or_create_by(
  user: existing_user,
  account: team_account
) do |au|
  au.role = 'member'
  au.confirmed_at = 1.day.ago
end

puts "Test seed data created:"
puts "  - test@example.com (password: password123) - Fully confirmed with account"
puts "  - existing@example.com (password: password123) - Confirmed user"
puts "  - unconfirmed@example.com (no password) - Unconfirmed registration"
puts "  - needsreset@example.com (has password reset token) - For password reset testing"
puts "  - nopassword@example.com (no password set) - OAuth-like user"
puts "  - Test Team account with multiple members"
