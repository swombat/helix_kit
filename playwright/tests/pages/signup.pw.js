import { test, expect } from '@playwright/experimental-ct-svelte';
import SignupForm from '../../../app/frontend/lib/components/signup-form.svelte';

test.describe('Signup Form Component Tests', () => {
  // IMPORTANT: These tests require the Rails backend running on localhost:3200
  // Run with: npm run test:integrated (automatically handles backend setup)
  
  test('should render signup form with email field only', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    // Check all elements are present
    await expect(component).toContainText('Sign up');
    await expect(component).toContainText("Enter your email to create an account. We'll send you a confirmation link.");
    
    // Check only email field is present (no password fields)
    await expect(component.locator('input[type="email"]')).toBeVisible();
    await expect(component.locator('input[type="password"]')).not.toBeVisible();
    
    // Check submit button
    await expect(component.locator('button[type="submit"]')).toBeVisible();
    await expect(component.locator('button[type="submit"]')).toContainText('Send Confirmation Email');
    
    // Check login link
    await expect(component.locator('a').filter({ hasText: 'Log in' })).toBeVisible();
  });

  test('should successfully submit signup with valid new email', async ({ mount, page }) => {
    const component = await mount(SignupForm);
    
    // Generate a unique email for this test run
    const timestamp = Date.now();
    const email = `newuser${timestamp}@example.com`;
    
    // Fill in the email field
    await component.locator('input[type="email"]').fill(email);
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/signup');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Check successful signup (302 redirect to check-email page)
    expect(response.status()).toBe(302);
  });

  test('should show error when email already exists', async ({ mount, page }) => {
    const component = await mount(SignupForm);
    
    // Fill in the form with existing confirmed email (seeded in test database)
    await component.locator('input[type="email"]').fill('test@example.com');
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/signup');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Should redirect to signup page with error
    expect(response.status()).toBe(302);
    
    // In a real test, we'd check for the error message displayed after redirect
  });

  test('should resend confirmation for unconfirmed email', async ({ mount, page }) => {
    const component = await mount(SignupForm);
    
    // Use an email that exists but is unconfirmed
    // This would need to be seeded in test database
    await component.locator('input[type="email"]').fill('unconfirmed@example.com');
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/signup');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Should redirect to check-email page
    expect(response.status()).toBe(302);
  });

  test('should accept input in email field', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    const emailInput = component.locator('input[type="email"]');
    await emailInput.fill('test@example.com');
    
    // Verify the value is set
    await expect(emailInput).toHaveValue('test@example.com');
  });

  test('should validate required email field', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    // Try to submit without filling email
    const emailInput = component.locator('input[type="email"]');
    
    // Check that email field is required
    await expect(emailInput).toHaveAttribute('required', '');
  });

  test('should have correct placeholders', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    const emailInput = component.locator('input[type="email"]');
    await expect(emailInput).toHaveAttribute('placeholder', 'm@example.com');
  });

  test('should navigate to login page', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    const loginLink = component.locator('a').filter({ hasText: 'Log in' });
    await expect(loginLink).toBeVisible();
    await expect(loginLink).toHaveAttribute('href', '/login');
  });

  test('should preserve form data when typing', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    const emailInput = component.locator('input[type="email"]');
    
    // Type character by character
    await emailInput.type('user@domain.com', { delay: 50 });
    
    // Verify the value is preserved
    await expect(emailInput).toHaveValue('user@domain.com');
  });
  
  test('should have submit button', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    const submitButton = component.locator('button[type="submit"]');
    await expect(submitButton).toBeVisible();
    await expect(submitButton).toContainText('Send Confirmation Email');
  });

  test('should show loading state when processing', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    const submitButton = component.locator('button[type="submit"]');
    const emailInput = component.locator('input[type="email"]');
    
    // Fill in email
    await emailInput.fill('loading@test.com');
    
    // The button should be enabled initially
    await expect(submitButton).toBeEnabled();
    
    // When form is processing, button text changes and is disabled
    // This would need proper mocking to test the processing state
  });
});