import { test, expect } from '@playwright/experimental-ct-svelte';
import NewPasswordPage from '../../../app/frontend/pages/passwords/new.svelte';
import EditPasswordPage from '../../../app/frontend/pages/passwords/edit.svelte';

test.describe('Password Reset Flow Tests', () => {
  test.describe('Request Password Reset Page', () => {
    test('should render password reset request page with all elements', async ({ mount }) => {
      const page = await mount(NewPasswordPage);

      // Check logo is present
      await expect(page.locator('svg').first()).toBeVisible();

      // Check page content
      await expect(page).toContainText('Forgot password?');
      await expect(page).toContainText('Enter your email below to receive a password reset link');

      // Check form elements
      await expect(page.locator('input[type="email"]')).toBeVisible();
      await expect(page.locator('button[type="submit"]')).toBeVisible();
      await expect(page.locator('button[type="submit"]')).toContainText('Send password reset link');

      // Check back to login link
      await expect(page.locator('a').filter({ hasText: 'Log in' })).toBeVisible();
    });

    test('should submit password reset request for existing user', async ({ mount, page }) => {
      const component = await mount(NewPasswordPage);

      // Fill in email for existing user
      await component.locator('input[type="email"]').fill('test@example.com');

      // Submit the form
      const responsePromise = page.waitForResponse('**/passwords');
      await component.locator('button[type="submit"]').click();
      const response = await responsePromise;

      // Should redirect with success
      expect(response.status()).toBe(302);
    });

    test('should handle non-existent email gracefully', async ({ mount, page }) => {
      const component = await mount(NewPasswordPage);

      // Fill in non-existent email
      await component.locator('input[type="email"]').fill('nonexistent@example.com');

      // Submit the form
      const responsePromise = page.waitForResponse('**/passwords');
      await component.locator('button[type="submit"]').click();
      const response = await responsePromise;

      // Should still redirect (for security, don't reveal if email exists)
      expect(response.status()).toBe(302);
    });

    test('should validate email field is required', async ({ mount }) => {
      const component = await mount(NewPasswordPage);

      const emailInput = component.locator('input[type="email"]');

      // Check HTML5 validation
      await expect(emailInput).toHaveAttribute('required', '');
      await expect(emailInput).toHaveAttribute('type', 'email');
    });

    test('should navigate back to login page', async ({ mount }) => {
      const component = await mount(NewPasswordPage);

      const backLink = component.locator('a').filter({ hasText: 'Log in' });
      await expect(backLink).toBeVisible();
      await expect(backLink).toHaveAttribute('href', '/login');
    });
  });

  test.describe('Reset Password Page (with token)', () => {
    test('should render reset password form with all elements', async ({ mount }) => {
      // Mock props for the password reset page
      const props = {
        password_reset_token: 'test-token-123',
        email: 'needsreset@example.com',
      };

      const page = await mount(EditPasswordPage, { props });

      // Check logo is present
      await expect(page.locator('svg').first()).toBeVisible();

      // Check page content
      await expect(page).toContainText('Update your password');
      await expect(page).toContainText('Enter a new password for your account');

      // Check form elements
      await expect(page.locator('input[type="password"]').first()).toBeVisible();
      await expect(page.locator('input[type="password"]').nth(1)).toBeVisible();
      await expect(page.locator('button[type="submit"]')).toBeVisible();
      await expect(page.locator('button[type="submit"]')).toContainText('Save');
    });

    test('should validate password requirements', async ({ mount }) => {
      const props = {
        password_reset_token: 'test-token-123',
        email: 'needsreset@example.com',
      };

      const component = await mount(EditPasswordPage, { props });

      const passwordInput = component.locator('input[type="password"]').first();
      const confirmInput = component.locator('input[type="password"]').nth(1);

      // Check required attributes
      await expect(passwordInput).toHaveAttribute('required', '');
      await expect(confirmInput).toHaveAttribute('required', '');
    });

    test('should submit new password successfully', async ({ mount, page }) => {
      const props = {
        password_reset_token: 'test-token-123',
        email: 'needsreset@example.com',
      };

      const component = await mount(EditPasswordPage, { props });

      // Fill in new password
      await component.locator('input[type="password"]').first().fill('newpassword123');
      await component.locator('input[type="password"]').nth(1).fill('newpassword123');

      // Submit the form
      const responsePromise = page.waitForResponse('**/passwords/*');
      await component.locator('button[type="submit"]').click();
      const response = await responsePromise;

      // Should redirect on success
      expect(response.status()).toBe(302);
    });

    test('should show password fields can be typed in', async ({ mount }) => {
      const props = {
        password_reset_token: 'test-token-123',
        email: 'needsreset@example.com',
      };

      const component = await mount(EditPasswordPage, { props });

      const passwordInput = component.locator('input[type="password"]').first();
      const confirmInput = component.locator('input[type="password"]').nth(1);

      // Type in password fields
      await passwordInput.fill('testpassword123');
      await confirmInput.fill('testpassword123');

      // Verify values are set
      await expect(passwordInput).toHaveValue('testpassword123');
      await expect(confirmInput).toHaveValue('testpassword123');
    });
  });
});
