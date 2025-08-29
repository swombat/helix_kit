# Testing Strategy

## ⚠️ CRITICAL: Pre-Commit Testing Requirements

**Before ANY change can be considered complete, you MUST run:**

```bash
# 1. Run Rails backend tests
rails test

# 2. Run Playwright component tests (REAL backend - NO mocking!)
npm test

# 3. Run Vitest unit tests
npm run test:unit

# All three test suites MUST pass before committing changes!
```

## Overview

The testing strategy for Helix Kit follows a multi-layered approach to ensure reliability across the full stack. Rails uses Minitest for backend testing, and Playwright Component Testing for frontend testing.

## Current Testing Setup

### Rails Testing (Minitest)

The application uses Rails' default Minitest framework for backend testing.

When doing Ruby tests, NEVER use mocks or stubs.

If an external API is being tested, use VCR to record the responses and use them in the tests.

NEVER use mocks and stubs in Ruby tests!

NEVER skip tests or delete tests without the user's explicit approval.

**Run all tests:**
```bash
rails test
```

**Run specific test files:**
```bash
rails test test/models/user_test.rb
rails test test/controllers/sessions_controller_test.rb
```

**Run specific test methods:**
```bash
rails test test/models/user_test.rb:15  # Run test at line 15
```

**Reset database and run tests:**
```bash
rails test:db
```

### Test Organization

```
test/
├── application_system_test_case.rb  # Base class for system tests
├── test_helper.rb                   # Test configuration
├── controllers/                     # Controller tests
├── models/                          # Model tests  
├── mailers/                         # Mailer tests
├── integration/                     # Integration tests
├── system/                          # System/browser tests
├── fixtures/                        # Test data
└── helpers/                         # Helper tests
```

## Testing Layers

### 1. Unit Tests (Models)

Only test model logic if it's requested by the user (e.g. for very complex models or services/utilities). Otherwise, let the controller tests cover it.

```ruby
# test/models/user_test.rb
class UserTest < ActiveSupport::TestCase
  test "should not save user without email" do
    user = User.new
    assert_not user.save
  end
  
  test "should hash password on save" do
    user = User.new(email: "test@example.com", password: "password")
    user.save
    assert user.password_digest.present?
    assert_not_equal "password", user.password_digest
  end
end
```

### 2. Controller Tests

Test request/response cycle, authentication, and authorization. DO NOT USE MOCKS OR STUBS.

```ruby
# test/controllers/sessions_controller_test.rb
class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get login page" do
    get login_path
    assert_response :success
  end
  
  test "should redirect after successful login" do
    user = users(:one)
    post login_path, params: { email: user.email, password: "password" }
    assert_redirected_to root_path
  end
end
```

## Frontend Testing

### Playwright Component Testing (IMPLEMENTED)

We use Playwright Component Testing to test Svelte components in real browsers. **ALL tests MUST run against the real Rails backend. Backend mocking is FORBIDDEN.**

```bash
# Run all component tests (REAL backend required)
npm test  # Automatically starts Rails, runs tests, cleans up

# Debug tests with UI
npm run test:ui
```

Test files are located in `playwright/tests/pages/`:
- `*.pw.js` - ALL tests hit the real Rails API (no mocking allowed!)

### Vitest Unit Testing

For testing application-specific Svelte components and JavaScript utilities in isolation.

**IMPORTANT: Testing Strategy for UI Components**

#### What We Test
- **Application components** (in `/app/frontend/pages/`, `/app/frontend/lib/components/`)
- **Custom utilities and helpers**
- **Application-specific business logic**

#### What We DON'T Test
- **Shadcn-svelte components** (in `/app/frontend/lib/components/ui/`)
  - These are third-party components that we assume work correctly
  - We do NOT edit these components directly
  - If customization is needed: create a new component that wraps or extends the shadcn component, then test the wrapper
  - Example: Instead of modifying `/ui/button/button.svelte`, create `/lib/components/CustomButton.svelte` and test that

**Run tests:**
```bash
npm run test:unit     # Run unit tests
npm run test:unit:ui  # Open Vitest UI for debugging
```

```javascript
// Example: Testing an application component (NOT a shadcn component)
// app/frontend/lib/components/signup-form.test.js
import { render, fireEvent } from '@testing-library/svelte';
import SignupForm from './signup-form.svelte';

test('signup form submits with email', async () => {
  const { getByLabelText, getByRole } = render(SignupForm);
  
  const emailInput = getByLabelText('Email');
  await fireEvent.input(emailInput, { target: { value: 'test@example.com' } });
  
  const submitButton = getByRole('button', { name: 'Sign up' });
  await fireEvent.click(submitButton);
  
  // Assert expected behavior
});
```

#### 2. Playwright for E2E Testing
For testing complete user journeys across the full stack.

```javascript
// test/e2e/user-flow.spec.js
import { test, expect } from '@playwright/test';

test('complete user registration flow', async ({ page }) => {
  await page.goto('/signup');
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="password"]', 'password123');
  await page.click('button[type="submit"]');
  
  await expect(page).toHaveURL('/dashboard');
  await expect(page.locator('.welcome-message')).toBeVisible();
});
```

## Testing Best Practices

### 1. Test Pyramid
- Many integration tests (component interactions)
- Few system/E2E tests (full workflows)

### 2. Test Data Management
- Use fixtures for consistent test data
- Do not use Factories. Use fixtures instead.
- Clean database between tests

### 3. Test Coverage Goals
- Controllers: Cover all actions and edge cases
- System: Cover critical user paths
- Frontend: Test component behavior and interactions

## Writing Effective Tests

### Good Test Principles
1. **Isolated** - Tests should not depend on each other
2. **Repeatable** - Same result every time
3. **Fast** - Quick feedback loop
4. **Clear** - Easy to understand what failed and why
5. **Complete** - Cover happy paths and edge cases

NEVER use mocks and stubs in Ruby tests!

### Test Naming Conventions
```ruby
# Rails/Minitest
test "should [expected behavior] when [condition]" do
  # test implementation
end

# JavaScript/Vitest
describe('Component', () => {
  it('should [expected behavior] when [condition]', () => {
    // test implementation
  });
});
```

## Running Tests in Different Environments

### Development
```bash
# Run all tests
rails test

# Run with verbose output
rails test -v

# Run specific test suite
rails test:models
rails test:controllers
```

### CI/CD Pipeline
```bash
# Setup test database
RAILS_ENV=test rails db:setup

# Run tests with coverage
COVERAGE=true rails test

# Run system tests headlessly
HEADLESS=true rails test:system
```

### Debugging Tests

#### Rails Tests
```ruby
# Add byebug for debugging
require 'byebug'

test "debugging example" do
  user = User.create(email: "test@example.com")
  byebug  # Execution stops here
  assert user.valid?
end
```

#### Frontend Tests (Future)
```javascript
// Add debug statements
test('component state', () => {
  const component = render(MyComponent);
  console.log(component.debug());  // Print component tree
});
```

## Test Database Management

### Database Cleaner Strategy
- Transactions for unit tests (automatic rollback)
- Truncation for system tests (clean slate)
- Seeds for consistent test data

### Fixtures
Located in `test/fixtures/`, provide static test data:

```yaml
# test/fixtures/users.yml
one:
  email: user1@example.com
  password_digest: <%= BCrypt::Password.create("password") %>

two:
  email: user2@example.com
  password_digest: <%= BCrypt::Password.create("password") %>
```
