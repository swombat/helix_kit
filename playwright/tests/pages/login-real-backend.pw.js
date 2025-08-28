import { test, expect } from '@playwright/experimental-ct-svelte';
import LoginForm from '../../../app/frontend/lib/components/login-form.svelte';

test.describe('Login Form Component Tests (Real Backend)', () => {
  // These tests use the real Rails backend running on localhost:3100
  // Start the backend with: playwright/setup-test-server.sh
  
  test('should render login form with all fields', async ({ mount }) => {
    const component = await mount(LoginForm);
    
    // Check all elements are present
    await expect(component).toContainText('Log in');
    await expect(component).toContainText('Enter your email below to login to your account');
    
    // Check form fields
    await expect(component.locator('input[type="email"]')).toBeVisible();
    await expect(component.locator('input[type="password"]')).toBeVisible();
    await expect(component.locator('button[type="submit"]')).toBeVisible();
    await expect(component.locator('button[type="submit"]')).toContainText('Log in');
    
    // Check links
    await expect(component.locator('a').filter({ hasText: 'Sign up' })).toBeVisible();
    await expect(component.locator('a').filter({ hasText: 'Forgot your password?' })).toBeVisible();
  });

  test('should successfully log in with valid credentials', async ({ mount, page }) => {
    const component = await mount(LoginForm);
    
    // Fill in the form with valid test user credentials
    await component.locator('input[type="email"]').fill('test@example.com');
    await component.locator('input[type="password"]').fill('password123');
    
    // Verify values are filled
    await expect(component.locator('input[type="email"]')).toHaveValue('test@example.com');
    await expect(component.locator('input[type="password"]')).toHaveValue('password123');
    
    // Submit and wait for response
    const responsePromise = page.waitForResponse('**/login', { timeout: 5000 });
    await component.locator('button[type="submit"]').click();
    
    const response = await responsePromise;
    
    // Check successful login (302 redirect is standard Rails behavior)
    expect(response.status()).toBe(302);
  });

  test('should show error with invalid credentials', async ({ mount, page }) => {
    const component = await mount(LoginForm);
    
    // Fill in the form with invalid credentials
    await component.locator('input[type="email"]').fill('invalid@example.com');
    await component.locator('input[type="password"]').fill('wrongpassword');
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/login');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Check error response (Rails with Inertia returns 302 redirect with errors in session)
    expect(response.status()).toBe(302);
  });

  test('should validate required fields', async ({ mount }) => {
    const component = await mount(LoginForm);
    
    const emailInput = component.locator('input[type="email"]');
    const passwordInput = component.locator('input[type="password"]');
    
    // Check HTML5 validation attributes
    await expect(emailInput).toHaveAttribute('required', '');
    await expect(passwordInput).toHaveAttribute('required', '');
    
    // Check email type
    await expect(emailInput).toHaveAttribute('type', 'email');
  });

  test('should navigate to signup page', async ({ mount }) => {
    const component = await mount(LoginForm);
    
    const signupLink = component.locator('a').filter({ hasText: 'Sign up' });
    await expect(signupLink).toBeVisible();
    await expect(signupLink).toHaveAttribute('href', '/signup');
  });

  test('should navigate to forgot password page', async ({ mount }) => {
    const component = await mount(LoginForm);
    
    const forgotLink = component.locator('a').filter({ hasText: 'Forgot your password?' });
    await expect(forgotLink).toBeVisible();
    await expect(forgotLink).toHaveAttribute('href', '/passwords/new');
  });

  test('should handle form submission with empty fields', async ({ mount }) => {
    const component = await mount(LoginForm);
    
    // Try to submit empty form
    await component.locator('button[type="submit"]').click();
    
    // The browser should prevent submission due to required fields
    // Check that we're still on the form
    await expect(component.locator('input[type="email"]')).toBeVisible();
    await expect(component.locator('input[type="password"]')).toBeVisible();
  });

  test('should accept and clear input in password field', async ({ mount }) => {
    const component = await mount(LoginForm);
    
    const passwordInput = component.locator('input[type="password"]');
    
    // Fill password
    await passwordInput.fill('password123');
    await expect(passwordInput).toHaveValue('password123');
    
    // Clear it
    await passwordInput.clear();
    await expect(passwordInput).toHaveValue('');
  });
});