# Playwright Component Testing Strategy

## Overview

This document outlines our testing strategy for Playwright Component Testing in this Rails + Svelte + Inertia.js application. We use Playwright Component Testing to test page-level components (like login and signup forms) in real browsers while mocking the backend interactions.

## Directory Structure

```
playwright/
├── tests/
│   └── pages/              # Page-level component tests
│       ├── login.pw.js
│       ├── login-simple.pw.js
│       └── signup.pw.js
├── mocks/
│   ├── mock-inertia.js    # Mock Inertia.js functionality
│   └── mock-routes.js      # Mock route helpers
├── MockLink.svelte         # Mock Link component
└── index.js                # Test setup
```

## What We Test vs What We Don't

### ✅ What Playwright Component Tests ARE Good For:

1. **UI Rendering**
   - Verifying all form fields are present
   - Checking text content and labels
   - Ensuring buttons and links are visible

2. **User Interactions**
   - Form field input and validation
   - Button clicks and state changes
   - Navigation link verification

3. **HTML Attributes**
   - Required field validation
   - Input types (email, password, etc.)
   - Link href attributes

4. **Component State**
   - Form values persist correctly
   - Fields can be cleared/reset
   - UI responds to user input

### ❌ What Playwright Component Tests ARE NOT Good For:

1. **Backend Integration**
   - Actual API calls and responses
   - Authentication flow with real backend
   - Database state changes

2. **Full Inertia.js Lifecycle**
   - Page transitions
   - Server-side validation responses
   - Session management

For these, use **E2E tests** with Playwright against a running Rails server.

## Testing Pattern for New Forms

When adding tests for a new form component, follow this pattern:

### 1. Create a Simple Test File

Create `playwright/tests/pages/your-form-simple.pw.js`:

```javascript
import { test, expect } from '@playwright/experimental-ct-svelte';
import YourForm from '../../../app/frontend/lib/components/your-form.svelte';

test.describe('Your Form Tests', () => {
  test('should render form with all fields', async ({ mount }) => {
    const component = await mount(YourForm);
    
    // Check all elements are present
    await expect(component).toContainText('Expected Title');
    
    // Check form fields
    await expect(component.locator('input[type="email"]')).toBeVisible();
    await expect(component.locator('button[type="submit"]')).toBeVisible();
  });

  test('should accept input in form fields', async ({ mount }) => {
    const component = await mount(YourForm);
    
    const emailInput = component.locator('input[type="email"]');
    
    // Fill and verify
    await emailInput.fill('test@example.com');
    await expect(emailInput).toHaveValue('test@example.com');
  });

  test('should validate required fields', async ({ mount }) => {
    const component = await mount(YourForm);
    
    const emailInput = component.locator('input[type="email"]');
    
    // Check validation attributes
    await expect(emailInput).toHaveAttribute('required', '');
    await expect(emailInput).toHaveAttribute('type', 'email');
  });
});
```

### 2. Mock Backend Interactions (Optional)

If you want to test form submission behavior, add route mocking in `beforeEach`:

```javascript
test.beforeEach(async ({ page }) => {
  // Mock API endpoint
  await page.route('**/your-endpoint', async (route) => {
    const request = route.request();
    const postData = request.postDataJSON();
    
    // Return mock response based on input
    if (postData?.email === 'test@example.com') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          success: true
        })
      });
    }
  });
});
```

## Mocking Strategy

### Inertia.js Forms

Our mock (`playwright/mock-inertia.js`) provides a simplified version of Inertia's `useForm` that:
- Acts as a Svelte store (subscribable)
- Maintains form state (data, errors, processing)
- Can make HTTP requests (though they won't integrate with the component without additional wiring)

### Routes

The mock routes (`playwright/mock-routes.js`) provide simple functions that return URL strings:
```javascript
export const loginPath = () => '/login';
export const signupPath = () => '/signup';
```

### Link Component

The mock Link component (`playwright/MockLink.svelte`) renders as a simple anchor tag:
```svelte
<a {href} class={className} data-method={method} on:click>
  <slot />
</a>
```

## Running Tests

```bash
# Run all Playwright component tests
npm run test:ct

# Run with UI mode for debugging
npm run test:ct-ui

# Run specific test file
npx playwright test -c playwright-ct.config.js playwright/tests/pages/login-simple.pw.js

# Run only on Chrome
npx playwright test -c playwright-ct.config.js --project chromium
```

## Best Practices

1. **Keep Tests Simple**: Focus on UI behavior, not backend logic
2. **Use Descriptive Names**: Test descriptions should clearly state what's being tested
3. **Test User Perspective**: Test what users see and interact with
4. **Avoid Testing Implementation**: Don't test internal component state or methods
5. **Separate Concerns**: Use simple tests for UI, E2E tests for full flows

## Limitations and Workarounds

### Current Limitations:

1. **Form Submission**: The mocked `useForm` doesn't fully integrate with components, so tests waiting for actual HTTP responses will timeout
2. **Inertia Navigation**: Page transitions don't work since we're testing in isolation
3. **Server-Side Validation**: Can't test real validation messages from Rails

### Workarounds:

1. **For Form Testing**: Test that fields accept input and have correct validation attributes, but don't test the full submission flow
2. **For Navigation**: Test that links have correct href attributes, not actual navigation
3. **For Validation**: Test HTML5 validation attributes, not server responses

## When to Use What

| Test Type | Use For | Tool |
|-----------|---------|------|
| **Unit Tests** | Component logic, utilities | Vitest |
| **Component Tests** | UI rendering, user interactions | Playwright CT |
| **E2E Tests** | Full user flows with backend | Playwright E2E |

## Example Test Coverage

For a typical form page, aim for:

### Component Tests (Playwright CT):
- ✅ All form fields render
- ✅ Fields accept and display input
- ✅ Required fields have validation attributes
- ✅ Navigation links point to correct URLs
- ✅ Submit button is present and enabled

### E2E Tests (Separate):
- ✅ Successful form submission
- ✅ Server validation errors display
- ✅ Navigation after submission
- ✅ Session/auth state changes

## Adding Tests for New Pages

1. Create test file in `playwright/tests/pages/`
2. Import the page component from `app/frontend/lib/components/`
3. Write simple UI tests following the patterns above
4. Run tests to verify they pass
5. Add any page-specific mocks if needed

Remember: These tests are for verifying the component renders and responds to user input correctly, not for testing the full application flow.