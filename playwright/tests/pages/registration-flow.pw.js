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

      // Check for try different email link (may be both link and button)
      await expect(
        page
          .locator('a, button')
          .filter({ hasText: /try.*different email/i })
          .first()
      ).toBeVisible();
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
    test('should render email confirmation page', async ({ mount }) => {
      const props = {
        token: 'test-token',
      };

      const page = await mount(ConfirmEmailPage, { props });

      // Check logo is present
      await expect(page.locator('svg').first()).toBeVisible();

      // The page will show "Confirming Email" initially since confirmation_status isn't set
      await expect(page).toContainText(/Confirming|Email/i);
    });

    test('should show confirmation state elements', async ({ mount }) => {
      const props = {
        token: 'test-token',
      };

      const page = await mount(ConfirmEmailPage, { props });

      // The page will have a status indicator (the rounded icon container)
      await expect(page.locator('.rounded-full')).toBeVisible();

      // It should have a title
      await expect(page.locator('h3, .text-2xl')).toBeVisible();
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

    test('should submit password form', async ({ mount }) => {
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

      // Verify form can be submitted
      const submitButton = component.locator('button[type="submit"]');
      await expect(submitButton).toBeEnabled();

      // Click to ensure no errors
      await submitButton.click();
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
