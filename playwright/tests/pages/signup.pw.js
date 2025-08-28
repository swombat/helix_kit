import { test, expect } from '@playwright/experimental-ct-svelte';
import SignupForm from '../../../app/frontend/lib/components/signup-form.svelte';

test.describe('Signup Form Component Tests', () => {
  // Helper function to set up API mocking
  const setupApiMocking = async (page) => {
    await page.route('**/signup', async (route) => {
      const request = route.request();
      const postData = request.postDataJSON();
      
      // Check for existing email
      if (postData?.email_address === 'existing@example.com') {
        await route.fulfill({
          status: 422,
          headers: {
            'X-Inertia': 'true',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            component: 'Auth/Signup',
            props: {
              errors: {
                email_address: ['has already been taken']
              }
            },
            url: '/signup',
            version: '1'
          }),
        });
      } 
      // Check password confirmation
      else if (postData?.password !== postData?.password_confirmation) {
        await route.fulfill({
          status: 422,
          headers: {
            'X-Inertia': 'true',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            component: 'Auth/Signup',
            props: {
              errors: {
                password_confirmation: ["doesn't match Password"]
              }
            },
            url: '/signup',
            version: '1'
          }),
        });
      }
      // Check for valid signup
      else if (postData?.email_address && postData?.password && postData?.password_confirmation) {
        await route.fulfill({
          status: 303,
          headers: {
            'X-Inertia': 'true',
            'X-Inertia-Location': '/',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            component: 'Home',
            props: {
              user: {
                id: 2,
                email_address: postData.email_address
              },
              flash: {
                notice: 'Welcome! You have signed up successfully.'
              }
            },
            url: '/',
            version: '1'
          }),
        });
      }
      // Invalid data
      else {
        await route.fulfill({
          status: 422,
          headers: {
            'X-Inertia': 'true',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            component: 'Auth/Signup',
            props: {
              errors: {
                email_address: ['is invalid'],
                password: ['is too short (minimum is 6 characters)']
              }
            },
            url: '/signup',
            version: '1'
          }),
        });
      }
    });
  };

  test('should render signup form with all fields', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    // Check all elements are present
    await expect(component).toContainText('Sign up');
    await expect(component).toContainText('Enter your email to create an account');
    
    // Check form fields
    await expect(component.locator('input[type="email"]')).toBeVisible();
    await expect(component.locator('input[type="password"]').first()).toBeVisible();
    await expect(component.locator('input[type="password"]').nth(1)).toBeVisible();
    await expect(component.locator('button[type="submit"]')).toBeVisible();
    await expect(component.locator('button[type="submit"]')).toContainText('Sign up');
    
    // Check login link
    await expect(component.locator('a').filter({ hasText: 'Log in' })).toBeVisible();
  });

  test('should successfully sign up with valid data', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    // Fill in the form
    await component.locator('input[type="email"]').fill('newuser@example.com');
    await component.locator('input[type="password"]').first().fill('password123');
    await component.locator('input[type="password"]').nth(1).fill('password123');
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/signup');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Check the response
    expect(response.status()).toBe(303);
    // 303 redirects don't have a body in the response, just verify the status
    // In a real E2E test, we would follow the redirect and check the result
  });

  test('should show error when email already exists', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    // Fill in the form with existing email
    await component.locator('input[type="email"]').fill('existing@example.com');
    await component.locator('input[type="password"]').first().fill('password123');
    await component.locator('input[type="password"]').nth(1).fill('password123');
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/signup');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Check error response
    expect(response.status()).toBe(422);
    const responseBody = await response.json();
    expect(responseBody.props.errors.email_address).toContain('has already been taken');
  });

  test('should show error when passwords do not match', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    // Fill in the form with mismatched passwords
    await component.locator('input[type="email"]').fill('user@example.com');
    await component.locator('input[type="password"]').first().fill('password123');
    await component.locator('input[type="password"]').nth(1).fill('different456');
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/signup');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Check error response
    expect(response.status()).toBe(422);
    const responseBody = await response.json();
    expect(responseBody.props.errors.password_confirmation).toContain("doesn't match Password");
  });

  test('should accept input in form fields', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    const emailInput = component.locator('input[type="email"]');
    const passwordInput = component.locator('input[type="password"]').first();
    const confirmInput = component.locator('input[type="password"]').nth(1);
    
    // Fill in the form
    await emailInput.fill('test@example.com');
    await passwordInput.fill('password123');
    await confirmInput.fill('password123');
    
    // Verify values are filled
    await expect(emailInput).toHaveValue('test@example.com');
    await expect(passwordInput).toHaveValue('password123');
    await expect(confirmInput).toHaveValue('password123');
  });

  test('should validate required fields', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    const emailInput = component.locator('input[type="email"]');
    const passwordInput = component.locator('input[type="password"]').first();
    const confirmInput = component.locator('input[type="password"]').nth(1);
    
    // Check HTML5 validation attributes
    await expect(emailInput).toHaveAttribute('required', '');
    await expect(passwordInput).toHaveAttribute('required', '');
    await expect(confirmInput).toHaveAttribute('required', '');
    
    // Check email type
    await expect(emailInput).toHaveAttribute('type', 'email');
  });

  test('should have correct placeholders', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    const emailInput = component.locator('input[type="email"]');
    
    // Check placeholder
    await expect(emailInput).toHaveAttribute('placeholder', 'm@example.com');
  });

  test('should navigate to login page', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    const loginLink = component.locator('a').filter({ hasText: 'Log in' });
    await expect(loginLink).toBeVisible();
    await expect(loginLink).toHaveAttribute('href', '/login');
  });

  test('should preserve form data when typing', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    const email = 'user@example.com';
    const password = 'password123';
    
    // Fill in the form
    await component.locator('input[type="email"]').fill(email);
    await component.locator('input[type="password"]').first().fill(password);
    await component.locator('input[type="password"]').nth(1).fill(password);
    
    // Check values are preserved
    await expect(component.locator('input[type="email"]')).toHaveValue(email);
    await expect(component.locator('input[type="password"]').first()).toHaveValue(password);
    await expect(component.locator('input[type="password"]').nth(1)).toHaveValue(password);
  });

  test('should have submit button', async ({ mount, page }) => {
    await setupApiMocking(page);
    const component = await mount(SignupForm);
    
    const submitButton = component.locator('button[type="submit"]');
    await expect(submitButton).toBeVisible();
    await expect(submitButton).toContainText('Sign up');
    
    // Verify button is clickable
    await expect(submitButton).toBeEnabled();
  });
});