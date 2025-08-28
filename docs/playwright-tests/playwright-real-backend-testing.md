# Playwright Component Testing with Real Rails Backend

This document describes how to run Playwright Component Tests against a real Rails backend instead of mocking API responses.

## Overview

Instead of mocking HTTP responses, we can run Playwright Component Tests against an actual Rails test server. This provides true integration testing while still testing components in isolation.

### Benefits

- **Real integration testing**: Tests the actual HTTP flow from component to backend
- **No mocking complexity**: Avoids the need to maintain mock responses
- **Fast execution**: Rails can handle many parallel requests efficiently
- **Real validation**: Tests actual Rails validation and business logic
- **Session handling**: Tests real authentication and session management

## Setup

### Quick Start - Single Command (Recommended)

Run everything with one command that handles the entire flow:

```bash
# Run tests with automatic backend setup and cleanup
npm run test:integrated

# Or with UI for debugging
npm run test:integrated-ui
```

This integrated script automatically:
- Drops and recreates the test database
- Runs migrations and seeds test data
- Starts Rails server on port 3200
- Waits for server to be ready
- Runs all Playwright tests
- Cleans up the Rails server when done

### Manual Setup (Alternative)

If you prefer to run the backend and tests separately:

#### 1. Start the Rails Test Server

```bash
npm run test:backend-setup
# or
./playwright/setup-test-server.sh
```

This keeps the Rails server running until you stop it.

#### 2. Run the Component Tests

In a separate terminal:

```bash
# Run all real backend tests
npm run test:ct-real

# Run with UI for debugging
npm run test:ct-real-ui

# Run specific test
npx playwright test -c playwright-ct.config.js playwright/tests/pages/login-real-backend.pw.js
```

## Architecture

### Component Server (Port 3101)
- Playwright Component Testing server
- Serves the isolated Svelte components
- Runs in the browser

### Rails Test Server (Port 3200)
- Real Rails backend in test environment
- Handles API requests from components
- Uses test database with seeded data


### CORS Configuration
- Configured in `config/initializers/cors.rb`
- Allows requests from Playwright CT server (port 3101)
- Enabled only in test and development environments

### Mock Inertia Adapter
- Located in `playwright/mock-inertia.js`
- Makes real HTTP requests to `http://localhost:3200`
- Handles form submissions and responses
- Maintains reactive form state

## Test Data

The test database is seeded with predictable data (see `db/seeds.rb`):

- `existing@example.com` - For testing duplicate email scenarios
- `test@example.com` - For testing successful login

New signups use timestamp-based emails to avoid conflicts between test runs.

## Writing Tests

### Example Test Structure

```javascript
import { test, expect } from '@playwright/experimental-ct-svelte';
import LoginForm from '../../../app/frontend/lib/components/login-form.svelte';

test.describe('Login Form Component Tests (Real Backend)', () => {
  test('should successfully log in with valid credentials', async ({ mount, page }) => {
    const component = await mount(LoginForm);
    
    // Fill in the form
    await component.locator('input[type="email"]').fill('test@example.com');
    await component.locator('input[type="password"]').fill('password123');
    
    // Submit and wait for real HTTP response
    const responsePromise = page.waitForResponse('**/login');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Check the actual response status
    expect(response.status()).toBe(302); // Rails redirect
  });
});
```

### Key Differences from Mocked Tests

1. **No route mocking**: Tests make real HTTP requests
2. **Real response codes**: Rails returns 302 for redirects (not 303)
3. **Actual validation**: Backend performs real validation
4. **Session state**: Real cookies and session management
5. **Database state**: Tests interact with real (test) database

## Best Practices

1. **Unique test data**: Use timestamps for unique emails in signup tests
2. **Database cleanup**: The setup script recreates the database each run
3. **Predictable seeds**: Use consistent seed data for reliable tests
4. **Response expectations**: Expect Rails standard responses (302 for redirects)
5. **Parallel execution**: Tests can run in parallel against the same server

## Troubleshooting

### Tests timing out
- Ensure Rails server is running: `curl -I http://localhost:3200`
- Check CORS is configured correctly
- Verify ports (Rails: 3200, Playwright CT: 3101)

### Authentication issues
- Check test users exist in database: `rails console -e test`
- Verify passwords in seed data match test expectations

### Port conflicts
- Kill existing processes: `lsof -ti:3200 | xargs kill -9`
- Ensure no other services use ports 3200 or 3101

## Comparison with Mocked Tests

| Aspect | Mocked Tests | Real Backend Tests |
|--------|--------------|-------------------|
| Speed | Faster (no network) | Slightly slower (real HTTP) |
| Complexity | Mock maintenance | Server setup |
| Coverage | UI behavior only | Full stack |
| Reliability | Mock accuracy | Real behavior |
| Debugging | Easier to isolate | More realistic |

## Future Improvements

- Database transactions/rollback per test
- Parallel test database support
- Automatic server startup in test script
- WebSocket/Action Cable testing
- File upload testing