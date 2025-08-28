import { test, expect } from '@playwright/experimental-ct-svelte';
import LoginForm from '../../../app/frontend/lib/components/login-form.svelte';

test.describe('Login Form Component Tests (Simplified)', () => {
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

  test('should accept input in form fields', async ({ mount }) => {
    const component = await mount(LoginForm);
    
    const emailInput = component.locator('input[type="email"]');
    const passwordInput = component.locator('input[type="password"]');
    
    // Fill in the form
    await emailInput.fill('test@example.com');
    await passwordInput.fill('password123');
    
    // Verify values are filled
    await expect(emailInput).toHaveValue('test@example.com');
    await expect(passwordInput).toHaveValue('password123');
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

  test('should have correct navigation links', async ({ mount }) => {
    const component = await mount(LoginForm);
    
    const signupLink = component.locator('a').filter({ hasText: 'Sign up' });
    await expect(signupLink).toBeVisible();
    await expect(signupLink).toHaveAttribute('href', '/signup');
    
    const forgotLink = component.locator('a').filter({ hasText: 'Forgot your password?' });
    await expect(forgotLink).toBeVisible();
    await expect(forgotLink).toHaveAttribute('href', '/passwords/new');
  });

  test('should have submit button', async ({ mount }) => {
    const component = await mount(LoginForm);
    
    const submitButton = component.locator('button[type="submit"]');
    await expect(submitButton).toBeVisible();
    await expect(submitButton).toContainText('Log in');
    
    // Verify button is clickable
    await expect(submitButton).toBeEnabled();
  });

  test('should clear password field on reset', async ({ mount }) => {
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