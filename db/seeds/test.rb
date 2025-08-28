# Test-specific seed data for Playwright Component Tests
# This file is only loaded when RAILS_ENV=test

# Create a test user for login tests
User.find_or_create_by(email_address: 'test@example.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
end

# Create another user for testing duplicate email
User.find_or_create_by(email_address: 'existing@example.com') do |user|
  user.password = 'password123' 
  user.password_confirmation = 'password123'
end

puts "Test seed data created:"
puts "  - test@example.com (password: password123)"
puts "  - existing@example.com (password: password123)"