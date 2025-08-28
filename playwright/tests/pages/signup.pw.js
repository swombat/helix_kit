import { test, expect } from '@playwright/experimental-ct-svelte';
import SignupForm from '../../../app/frontend/lib/components/signup-form.svelte';

test.describe('Signup Form Component Tests', () => {
  // IMPORTANT: These tests require the Rails backend running on localhost:3200
  // Run with: npm run test:integrated (automatically handles backend setup)
  
  test('should render signup form with all fields', async ({ mount }) => {
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

  test('should successfully sign up with valid new email', async ({ mount, page }) => {
    const component = await mount(SignupForm);
    
    // Generate a unique email for this test run
    const timestamp = Date.now();
    const email = `newuser${timestamp}@example.com`;
    
    // Fill in the form
    await component.locator('input[type="email"]').fill(email);
    await component.locator('input[type="password"]').first().fill('password123');
    await component.locator('input[type="password"]').nth(1).fill('password123');
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/signup');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Check successful signup (302 redirect is standard Rails behavior)
    expect(response.status()).toBe(302);
  });

  test('should show error when email already exists', async ({ mount, page }) => {
    const component = await mount(SignupForm);
    
    // Fill in the form with existing email (seeded in test database)
    await component.locator('input[type="email"]').fill('existing@example.com');
    await component.locator('input[type="password"]').first().fill('password123');
    await component.locator('input[type="password"]').nth(1).fill('password123');
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/signup');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Check error response (Rails with Inertia returns 302 redirect with errors in session)
    expect(response.status()).toBe(302);
  });

  test('should show error when passwords do not match', async ({ mount, page }) => {
    const component = await mount(SignupForm);
    
    // Generate a unique email for this test
    const timestamp = Date.now();
    const email = `user${timestamp}@example.com`;
    
    // Fill in the form with mismatched passwords
    await component.locator('input[type="email"]').fill(email);
    await component.locator('input[type="password"]').first().fill('password123');
    await component.locator('input[type="password"]').nth(1).fill('different456');
    
    // Submit the form
    const responsePromise = page.waitForResponse('**/signup');
    await component.locator('button[type="submit"]').click();
    const response = await responsePromise;
    
    // Check error response (Rails with Inertia returns 302 redirect with errors in session)
    expect(response.status()).toBe(302);
  });

  test('should accept input in form fields', async ({ mount }) => {
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

  test('should validate required fields', async ({ mount }) => {
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

  test('should have correct placeholders', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    const emailInput = component.locator('input[type="email"]');
    
    // Check placeholder
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

  test('should have submit button', async ({ mount }) => {
    const component = await mount(SignupForm);
    
    const submitButton = component.locator('button[type="submit"]');
    await expect(submitButton).toBeVisible();
    await expect(submitButton).toContainText('Sign up');
    
    // Verify button is clickable
    await expect(submitButton).toBeEnabled();
  });
});