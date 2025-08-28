# Testing Quick Reference

## Test Types and Commands

### Unit Tests (Vitest)
- **Location**: `app/frontend/**/*.test.js`
- **Run**: `npm test`
- **What**: Component logic, utilities, isolated component behavior
- **Environment**: jsdom (simulated browser)

### Component Tests (Playwright CT)
- **Location**: `playwright/tests/pages/*.pw.js`
- **Run**: `npm run test:ct`
- **What**: Page components in real browsers, UI interactions
- **Environment**: Real browsers (Chrome, Firefox, Safari)

### Rails Tests
- **Location**: `test/controllers/`, `test/models/`
- **Run**: `rails test`
- **What**: Backend logic, API endpoints, authentication

## Quick Commands

```bash
# Run all Vitest unit tests
npm test

# Run Vitest with UI
npm run test:ui

# Run all Playwright component tests
npm run test:ct

# Run Playwright with UI for debugging
npm run test:ct-ui

# Run specific Playwright test
npx playwright test -c playwright-ct.config.js playwright/tests/pages/login-simple.pw.js

# Run Rails tests
rails test
```

## Creating New Tests

### For a new Svelte component (unit test):
1. Create `app/frontend/lib/components/my-component.test.js`
2. Use `@testing-library/svelte` for rendering
3. Mock Inertia if needed (see existing mocks)

### For a new page component (Playwright):
1. Create `playwright/tests/pages/my-page.pw.js`
2. Import component from `app/frontend/lib/components/`
3. Test UI rendering and interactions
4. See `login-simple.pw.js` for patterns

### For a new Rails controller:
1. Create `test/controllers/my_controller_test.rb`
2. Test API responses and authentication
3. Use fixtures for test data

## Test File Naming

- **Unit tests**: `component-name.test.js`
- **Playwright tests**: `page-name.pw.js`
- **Rails tests**: `controller_name_test.rb`

## Coverage Goals

Each page/feature should have:
1. **Unit tests** for component logic
2. **Playwright CT** for UI behavior
3. **Rails tests** for API endpoints
4. **E2E tests** (optional) for critical user flows