import { test, expect } from '@playwright/experimental-ct-svelte';
import MembersPage from '../../../app/frontend/pages/accounts/Members.svelte';

test.describe('Team Members Page Tests', () => {
  test('should render members page with active members', async ({ mount }) => {
    const props = {
      account: {
        id: 1,
        name: 'Test Team Account',
        personal: false,
      },
      members: [
        {
          id: 1,
          role: 'owner',
          display_name: 'John Doe',
          confirmed_at: '2024-01-01T10:00:00Z',
          invitation_pending: false,
          can_remove: false,
          user: {
            id: 1,
            email_address: 'john@example.com',
          },
        },
        {
          id: 2,
          role: 'admin',
          display_name: 'Jane Smith',
          confirmed_at: '2024-01-02T10:00:00Z',
          invitation_pending: false,
          can_remove: true,
          user: {
            id: 2,
            email_address: 'jane@example.com',
          },
        },
        {
          id: 3,
          role: 'member',
          display_name: 'Bob Wilson',
          confirmed_at: '2024-01-03T10:00:00Z',
          invitation_pending: false,
          can_remove: true,
          user: {
            id: 3,
            email_address: 'bob@example.com',
          },
        },
      ],
      can_manage: true,
      current_user_id: 1,
    };

    const page = await mount(MembersPage, { props });

    // Check page title
    await expect(page).toContainText('Team Members');

    // Check active members section
    await expect(page).toContainText('Active Members (3)');

    // Check that all members are displayed
    await expect(page).toContainText('John Doe');
    await expect(page).toContainText('jane@example.com');
    await expect(page).toContainText('Bob Wilson');

    // Check role badges
    await expect(page).toContainText('owner');
    await expect(page).toContainText('admin');
    await expect(page).toContainText('member');

    // Check that current user is marked as "You"
    await expect(page).toContainText('You');

    // Check invite member button is present for team accounts
    await expect(page.locator('button:has-text("Invite Member")')).toBeVisible();
  });

  test('should render members page with pending invitations', async ({ mount }) => {
    const props = {
      account: {
        id: 1,
        name: 'Test Team Account',
        personal: false,
      },
      members: [
        {
          id: 1,
          role: 'owner',
          display_name: 'John Doe',
          confirmed_at: '2024-01-01T10:00:00Z',
          invitation_pending: false,
          can_remove: false,
          user: {
            id: 1,
            email_address: 'john@example.com',
          },
        },
        {
          id: 2,
          role: 'admin',
          display_name: 'pending@example.com',
          invited_at: '2024-01-10T10:00:00Z',
          invitation_pending: true,
          can_remove: true,
          user: {
            id: 2,
            email_address: 'pending@example.com',
          },
          invited_by: {
            full_name: 'John Doe',
          },
        },
      ],
      can_manage: true,
      current_user_id: 1,
    };

    const page = await mount(MembersPage, { props });

    // Check active members section
    await expect(page).toContainText('Active Members (1)');

    // Check pending invitations section
    await expect(page).toContainText('Pending Invitations (1)');

    // Check pending invitation details
    await expect(page).toContainText('pending@example.com');
    await expect(page).toContainText('John Doe'); // Invited by

    // Check resend and cancel buttons for pending invitations
    await expect(page.locator('button:has-text("Resend")')).toBeVisible();
    await expect(page.locator('button:has-text("Cancel")')).toBeVisible();
  });

  test('should show invite member form when invite button is clicked', async ({ mount }) => {
    const props = {
      account: {
        id: 1,
        name: 'Test Team Account',
        personal: false,
      },
      members: [
        {
          id: 1,
          role: 'owner',
          display_name: 'John Doe',
          confirmed_at: '2024-01-01T10:00:00Z',
          invitation_pending: false,
          can_remove: false,
          user: {
            id: 1,
            email_address: 'john@example.com',
          },
        },
      ],
      can_manage: true,
      current_user_id: 1,
    };

    const page = await mount(MembersPage, { props });

    // Click invite member button
    await page.locator('button:has-text("Invite Member")').click();

    // Check that invite form appears
    await expect(page).toContainText('Invite Team Member');
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('select, [role="combobox"]')).toBeVisible(); // Role selector
    await expect(page.locator('button:has-text("Send Invitation")')).toBeVisible();
    await expect(page.locator('button:has-text("Cancel")')).toBeVisible();
  });

  test('should not show invite button for personal accounts', async ({ mount }) => {
    const props = {
      account: {
        id: 1,
        name: 'Personal Account',
        personal: true,
      },
      members: [
        {
          id: 1,
          role: 'owner',
          display_name: 'John Doe',
          confirmed_at: '2024-01-01T10:00:00Z',
          invitation_pending: false,
          can_remove: false,
          user: {
            id: 1,
            email_address: 'john@example.com',
          },
        },
      ],
      can_manage: true,
      current_user_id: 1,
    };

    const page = await mount(MembersPage, { props });

    // Should not show invite member button for personal accounts
    await expect(page.locator('button:has-text("Invite Member")')).not.toBeVisible();
  });

  test('should not show invite button when user cannot manage', async ({ mount }) => {
    const props = {
      account: {
        id: 1,
        name: 'Test Team Account',
        personal: false,
      },
      members: [
        {
          id: 1,
          role: 'owner',
          display_name: 'John Doe',
          confirmed_at: '2024-01-01T10:00:00Z',
          invitation_pending: false,
          can_remove: false,
          user: {
            id: 1,
            email_address: 'john@example.com',
          },
        },
        {
          id: 2,
          role: 'member',
          display_name: 'Jane Smith',
          confirmed_at: '2024-01-02T10:00:00Z',
          invitation_pending: false,
          can_remove: false,
          user: {
            id: 2,
            email_address: 'jane@example.com',
          },
        },
      ],
      can_manage: false,
      current_user_id: 2,
    };

    const page = await mount(MembersPage, { props });

    // Should not show invite member button when user cannot manage
    await expect(page.locator('button:has-text("Invite Member")')).not.toBeVisible();

    // Should not show remove buttons
    await expect(page.locator('button:has-text("Remove")')).not.toBeVisible();
  });

  test('should show remove buttons only for removable members', async ({ mount }) => {
    const props = {
      account: {
        id: 1,
        name: 'Test Team Account',
        personal: false,
      },
      members: [
        {
          id: 1,
          role: 'owner',
          display_name: 'John Doe',
          confirmed_at: '2024-01-01T10:00:00Z',
          invitation_pending: false,
          can_remove: false, // Owner cannot be removed (last owner)
          user: {
            id: 1,
            email_address: 'john@example.com',
          },
        },
        {
          id: 2,
          role: 'admin',
          display_name: 'Jane Smith',
          confirmed_at: '2024-01-02T10:00:00Z',
          invitation_pending: false,
          can_remove: true, // Admin can be removed
          user: {
            id: 2,
            email_address: 'jane@example.com',
          },
        },
      ],
      can_manage: true,
      current_user_id: 1,
    };

    const page = await mount(MembersPage, { props });

    // Should show only one remove button (for Jane Smith)
    const removeButtons = page.locator('button:has-text("Remove")');
    await expect(removeButtons).toHaveCount(1);
  });

  test('should handle empty members list', async ({ mount }) => {
    const props = {
      account: {
        id: 1,
        name: 'Test Team Account',
        personal: false,
      },
      members: [],
      can_manage: true,
      current_user_id: 1,
    };

    const page = await mount(MembersPage, { props });

    // Check that empty state message is displayed
    await expect(page).toContainText('No active members found');

    // Should still show invite button
    await expect(page.locator('button:has-text("Invite Member")')).toBeVisible();
  });

  test('should fill and submit invitation form', async ({ mount }) => {
    const props = {
      account: {
        id: 1,
        name: 'Test Team Account',
        personal: false,
      },
      members: [
        {
          id: 1,
          role: 'owner',
          display_name: 'John Doe',
          confirmed_at: '2024-01-01T10:00:00Z',
          invitation_pending: false,
          can_remove: false,
          user: {
            id: 1,
            email_address: 'john@example.com',
          },
        },
      ],
      can_manage: true,
      current_user_id: 1,
    };

    const page = await mount(MembersPage, { props });

    // Open invite form
    await page.locator('button:has-text("Invite Member")').click();

    // Fill in the form
    await page.locator('input[type="email"]').fill('newmember@example.com');

    // Check that form is ready to submit
    const submitButton = page.locator('button:has-text("Send Invitation")');
    await expect(submitButton).toBeEnabled();

    // Form should be fillable and submittable
    await expect(page.locator('input[type="email"]')).toHaveValue('newmember@example.com');
  });
});
