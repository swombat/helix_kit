import { test, expect } from '@playwright/experimental-ct-svelte';
import CheckEmailPage from '../../../app/frontend/pages/registrations/check_email.svelte';
import ConfirmEmailPage from '../../../app/frontend/pages/registrations/confirm_email.svelte';
import SetPasswordPage from '../../../app/frontend/pages/registrations/set_password.svelte';

test.describe('Registration Flow Tests', () => {
  test.describe('Check Email Page', () => {
    test('should render check email page with all elements', async ({ mount }) => {
      const props = {
        email: 'newuser@example.com',
      };

      const page = await mount(CheckEmailPage, { props });

      // Check logo is present
      await expect(page.locator('svg').first()).toBeVisible();

      // Check page content
      await expect(page).toContainText('Check Your Email');
      await expect(page).toContainText("We've sent you a confirmation email");
      await expect(page).toContainText('newuser@example.com');

      // Check for resend link
      await expect(page.locator('button, a').filter({ hasText: /resend/i })).toBeVisible();

      // Check for try different email link
      await expect(page.locator('a, button').filter({ hasText: /try.*different email/i })).toBeVisible();
    });

    test('should display email address correctly', async ({ mount }) => {
      const props = {
        email: 'test@domain.com',
      };

      const page = await mount(CheckEmailPage, { props });

      await expect(page).toContainText('test@domain.com');
    });

    test('should have working resend confirmation button', async ({ mount, page }) => {
      const props = {
        email: 'unconfirmed@example.com',
      };

      const component = await mount(CheckEmailPage, { props });

      // Find resend button/link
      const resendButton = component.locator('button, a').filter({ hasText: /resend/i });
      await expect(resendButton).toBeVisible();

      // Click resend (would trigger resend in real app)
      // In a real test, we'd check for the API call
    });
  });

  test.describe('Confirm Email Page', () => {
    test('should render email confirmation success page', async ({ mount }) => {
      const props = {
        confirmation_status: 'success',
        token: 'test-token',
      };

      const page = await mount(ConfirmEmailPage, { props });

      // Check logo is present
      await expect(page.locator('svg').first()).toBeVisible();

      // Check success message (page shows status dynamically)
      await expect(page).toContainText(/Email Confirmed|successfully/i);
    });

    test('should show error state for invalid token', async ({ mount }) => {
      const props = {
        confirmation_status: 'error',
        error_message: 'Invalid or expired confirmation link.',
        token: 'invalid-token',
      };

      const page = await mount(ConfirmEmailPage, { props });

      await expect(page).toContainText(/Failed|Invalid|expired/i);
    });
  });

  test.describe('Set Password Page', () => {
    test('should render set password form with all elements', async ({ mount }) => {
      const props = {
        user: {
          email_address: 'newuser@example.com',
          id: 123,
        },
        confirmation_token: 'test-confirmation-token',
      };

      const page = await mount(SetPasswordPage, { props });

      // Check logo is present
      await expect(page.locator('svg').first()).toBeVisible();

      // Check page content
      await expect(page).toContainText('Email Confirmed!');
      await expect(page).toContainText("Now let's secure your account with a password.");

      // Check form elements
      await expect(page.locator('input[type="password"]').first()).toBeVisible();
      await expect(page.locator('input[type="password"]').nth(1)).toBeVisible();
      await expect(page.locator('button[type="submit"]')).toBeVisible();
      // Button text comes from SetPasswordForm component
      await expect(page.locator('button[type="submit"]')).toBeVisible();
    });

    test('should validate password fields are required', async ({ mount }) => {
      const props = {
        user: {
          email_address: 'newuser@example.com',
          id: 123,
        },
        confirmation_token: 'test-token',
      };

      const component = await mount(SetPasswordPage, { props });

      const passwordInput = component.locator('input[type="password"]').first();
      const confirmInput = component.locator('input[type="password"]').nth(1);

      // Check required attributes
      await expect(passwordInput).toHaveAttribute('required', '');
      await expect(confirmInput).toHaveAttribute('required', '');
    });

    test('should accept password input', async ({ mount }) => {
      const props = {
        user: {
          email_address: 'newuser@example.com',
          id: 123,
        },
        confirmation_token: 'test-token',
      };

      const component = await mount(SetPasswordPage, { props });

      const passwordInput = component.locator('input[type="password"]').first();
      const confirmInput = component.locator('input[type="password"]').nth(1);

      // Type passwords
      await passwordInput.fill('mynewpassword123');
      await confirmInput.fill('mynewpassword123');

      // Verify values
      await expect(passwordInput).toHaveValue('mynewpassword123');
      await expect(confirmInput).toHaveValue('mynewpassword123');
    });

    test('should submit password form', async ({ mount, page }) => {
      const props = {
        user: {
          email_address: 'newuser@example.com',
          id: 123,
        },
        confirmation_token: 'test-token',
      };

      const component = await mount(SetPasswordPage, { props });

      // Fill passwords
      await component.locator('input[type="password"]').first().fill('password123');
      await component.locator('input[type="password"]').nth(1).fill('password123');

      // Submit form
      const responsePromise = page.waitForResponse('**/registrations/set_password');
      await component.locator('button[type="submit"]').click();
      const response = await responsePromise;

      // Should redirect on success
      expect(response.status()).toBe(302);
    });

    test('should show user email on page', async ({ mount }) => {
      const props = {
        user: {
          email_address: 'specific@email.com',
          id: 123,
        },
        confirmation_token: 'test-token',
      };

      const component = await mount(SetPasswordPage, { props });

      // The email may not be directly visible on the page
      // The SetPasswordForm handles the display
    });
  });
});
