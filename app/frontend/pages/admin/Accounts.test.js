import { render, fireEvent, screen } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import Accounts from './accounts.svelte';
import { router } from '@inertiajs/svelte';

describe('Accounts Admin Page Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const mockAccounts = [
    {
      id: 1,
      name: 'Acme Corporation',
      account_type: 'organization',
      users_count: 5,
      owner: {
        id: 1,
        email: 'owner@acme.com',
        name: 'John Doe',
      },
      created_at: '2024-01-15T10:00:00Z',
      updated_at: '2024-01-20T15:30:00Z',
      users: [
        {
          id: 1,
          email: 'owner@acme.com',
          name: 'John Doe',
          role: 'owner',
          created_at: '2024-01-15T10:00:00Z',
        },
        {
          id: 2,
          email: 'admin@acme.com',
          name: 'Jane Smith',
          role: 'admin',
          created_at: '2024-01-16T09:00:00Z',
        },
        {
          id: 3,
          email: 'member@acme.com',
          name: null,
          role: 'member',
          created_at: '2024-01-17T14:00:00Z',
        },
      ],
    },
    {
      id: 2,
      name: 'Personal Account',
      account_type: 'personal',
      users_count: 1,
      owner: {
        id: 4,
        email: 'user@personal.com',
        name: 'Alice Brown',
      },
      created_at: '2024-02-01T08:00:00Z',
      updated_at: '2024-02-01T08:00:00Z',
      users: [
        {
          id: 4,
          email: 'user@personal.com',
          name: 'Alice Brown',
          role: 'owner',
          created_at: '2024-02-01T08:00:00Z',
        },
      ],
    },
    {
      id: 3,
      name: 'Empty Organization',
      account_type: 'organization',
      users_count: 0,
      owner: null,
      created_at: '2024-03-01T12:00:00Z',
      updated_at: '2024-03-01T12:00:00Z',
      users: [],
    },
  ];

  const selectedAccount = mockAccounts[0];

  describe('Component Rendering', () => {
    it('renders accounts list with search input', () => {
      render(Accounts, { accounts: mockAccounts });

      expect(screen.getByRole('heading', { name: 'Accounts' })).toBeInTheDocument();
      expect(screen.getByRole('searchbox')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Search accounts...')).toBeInTheDocument();
    });

    it('renders all accounts in the list', () => {
      render(Accounts, { accounts: mockAccounts });

      // Check that all account names are displayed
      expect(screen.getByText('Acme Corporation')).toBeInTheDocument();
      expect(screen.getByText('Personal Account')).toBeInTheDocument();
      expect(screen.getByText('Empty Organization')).toBeInTheDocument();
    });

    it('displays account type and user count for each account', () => {
      render(Accounts, { accounts: mockAccounts });

      // Check account type and user count display
      expect(screen.getByText('Organization • 5 users')).toBeInTheDocument();
      expect(screen.getByText('Personal • 1 user')).toBeInTheDocument();
      expect(screen.getByText('Organization • 0 users')).toBeInTheDocument();
    });

    it('displays owner information when available', () => {
      render(Accounts, { accounts: mockAccounts });

      expect(screen.getByText('Owner: owner@acme.com')).toBeInTheDocument();
      expect(screen.getByText('Owner: user@personal.com')).toBeInTheDocument();
    });

    it('shows empty state when no accounts', () => {
      render(Accounts, { accounts: [] });

      expect(screen.getByText('No accounts found')).toBeInTheDocument();
    });

    it('shows selection prompt when no account selected', () => {
      render(Accounts, { accounts: mockAccounts });

      expect(screen.getByRole('heading', { name: 'Select an account' })).toBeInTheDocument();
      expect(screen.getByText('Choose an account from the list to view details')).toBeInTheDocument();
    });
  });

  describe('Search Functionality', () => {
    it('filters accounts by name', async () => {
      render(Accounts, { accounts: mockAccounts });

      const searchInput = screen.getByPlaceholderText('Search accounts...');
      await fireEvent.input(searchInput, { target: { value: 'acme' } });

      expect(screen.getByText('Acme Corporation')).toBeInTheDocument();
      expect(screen.queryByText('Personal Account')).not.toBeInTheDocument();
      expect(screen.queryByText('Empty Organization')).not.toBeInTheDocument();
    });

    it('filters accounts by owner email', async () => {
      render(Accounts, { accounts: mockAccounts });

      const searchInput = screen.getByPlaceholderText('Search accounts...');
      await fireEvent.input(searchInput, { target: { value: 'personal.com' } });

      expect(screen.getByText('Personal Account')).toBeInTheDocument();
      expect(screen.queryByText('Acme Corporation')).not.toBeInTheDocument();
      expect(screen.queryByText('Empty Organization')).not.toBeInTheDocument();
    });

    it('is case insensitive', async () => {
      render(Accounts, { accounts: mockAccounts });

      const searchInput = screen.getByPlaceholderText('Search accounts...');
      await fireEvent.input(searchInput, { target: { value: 'ACME' } });

      expect(screen.getByText('Acme Corporation')).toBeInTheDocument();
    });

    it('shows no matches state when search returns no results', async () => {
      render(Accounts, { accounts: mockAccounts });

      const searchInput = screen.getByPlaceholderText('Search accounts...');
      await fireEvent.input(searchInput, { target: { value: 'nonexistent' } });

      expect(screen.getByText('No accounts match your search')).toBeInTheDocument();
      expect(screen.queryByText('Acme Corporation')).not.toBeInTheDocument();
    });

    it('clears search filter when search is empty', async () => {
      render(Accounts, { accounts: mockAccounts });

      const searchInput = screen.getByPlaceholderText('Search accounts...');

      // First filter
      await fireEvent.input(searchInput, { target: { value: 'acme' } });
      expect(screen.queryByText('Personal Account')).not.toBeInTheDocument();

      // Clear search
      await fireEvent.input(searchInput, { target: { value: '' } });
      expect(screen.getByText('Personal Account')).toBeInTheDocument();
    });
  });

  describe('Account Selection', () => {
    it('calls router.visit when account is selected', async () => {
      render(Accounts, { accounts: mockAccounts });

      const accountButtons = screen
        .getAllByRole('button')
        .filter((button) => button.textContent.includes('Acme Corporation'));
      const accountButton = accountButtons[0]; // Get the first (sidebar) button
      await fireEvent.click(accountButton);

      expect(router.visit).toHaveBeenCalledWith('/admin/accounts?account_id=1', {
        preserveState: true,
        preserveScroll: true,
        only: ['selected_account'],
      });
    });

    it('highlights selected account', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      const accountButtons = screen
        .getAllByRole('button')
        .filter((button) => button.textContent.includes('Acme Corporation'));
      const selectedAccountButton = accountButtons[0]; // Get the sidebar button
      expect(selectedAccountButton).toHaveClass('bg-primary/10', 'border-l-4', 'border-l-primary');
    });

    it('does not highlight unselected accounts', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      const accountButtons = screen
        .getAllByRole('button')
        .filter((button) => button.textContent.includes('Personal Account'));
      const unselectedButton = accountButtons[0]; // Get the sidebar button
      expect(unselectedButton).not.toHaveClass('bg-primary/10');
    });
  });

  describe('Account Details Display', () => {
    it('renders account header with name and badge', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      expect(screen.getByRole('heading', { name: 'Acme Corporation' })).toBeInTheDocument();
      // Look for Organization badge specifically (not in the account info section)
      const organizationTexts = screen.getAllByText('Organization');
      expect(organizationTexts.length).toBeGreaterThan(0);
    });

    it('displays formatted creation and update dates', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      expect(screen.getByText('Created Jan 15, 2024')).toBeInTheDocument();
      expect(screen.getByText('Updated Jan 20, 2024')).toBeInTheDocument();
    });

    it('renders account information card', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      expect(screen.getByRole('heading', { name: 'Account Information' })).toBeInTheDocument();
      expect(screen.getByText('Account ID')).toBeInTheDocument();
      expect(screen.getByText('1')).toBeInTheDocument();
      expect(screen.getByText('Type')).toBeInTheDocument();
      // Organization appears in multiple places, so check it exists
      const organizationTexts = screen.getAllByText('Organization');
      expect(organizationTexts.length).toBeGreaterThan(0);
    });

    it('displays owner information when available', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      expect(screen.getByText('Owner')).toBeInTheDocument();
      // John Doe and owner@acme.com appear in multiple places
      const johnDoeTexts = screen.getAllByText('John Doe');
      expect(johnDoeTexts.length).toBeGreaterThan(0);
      const ownerEmails = screen.getAllByText('owner@acme.com');
      expect(ownerEmails.length).toBeGreaterThan(0);
    });

    it('handles account without owner gracefully', () => {
      const accountWithoutOwner = { ...mockAccounts[2], owner: null };
      render(Accounts, { accounts: mockAccounts, selected_account: accountWithoutOwner });

      expect(screen.getByRole('heading', { name: 'Empty Organization' })).toBeInTheDocument();
      expect(screen.queryByText('Owner')).not.toBeInTheDocument();
    });

    it('renders statistics card with user count', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      expect(screen.getByRole('heading', { name: 'Statistics' })).toBeInTheDocument();
      expect(screen.getByText('Total Users')).toBeInTheDocument();
      expect(screen.getByText('3')).toBeInTheDocument(); // Number of users in the account
    });
  });

  describe('Users List Display', () => {
    it('renders users table with headers', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      expect(screen.getByRole('heading', { name: 'Users (3)' })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: 'Email' })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: 'Name' })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: 'Role' })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: 'Joined' })).toBeInTheDocument();
    });

    it('displays all users in the table', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      // Check that user emails are displayed in the table
      const ownerEmails = screen.getAllByText('owner@acme.com');
      expect(ownerEmails.length).toBeGreaterThan(0);
      expect(screen.getByText('admin@acme.com')).toBeInTheDocument();
      expect(screen.getByText('member@acme.com')).toBeInTheDocument();
    });

    it('displays user names or dash when not available', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      // Check user names in the table
      const johnDoeTexts = screen.getAllByText('John Doe');
      expect(johnDoeTexts.length).toBeGreaterThan(0);
      expect(screen.getByText('Jane Smith')).toBeInTheDocument();
      expect(screen.getByText('-')).toBeInTheDocument(); // For user without name
    });

    it('renders role badges with correct variants', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      // Check that role badges are rendered
      const ownerBadge = screen.getByText('owner');
      const adminBadge = screen.getByText('admin');
      const memberBadge = screen.getByText('member');

      expect(ownerBadge).toBeInTheDocument();
      expect(adminBadge).toBeInTheDocument();
      expect(memberBadge).toBeInTheDocument();

      // Owner badge should have default variant (different styling)
      expect(ownerBadge.closest('span')).toHaveClass('bg-primary');
      // Other roles should have secondary variant
      expect(adminBadge.closest('span')).toHaveClass('bg-secondary');
      expect(memberBadge.closest('span')).toHaveClass('bg-secondary');
    });

    it('formats user join dates correctly', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      // Dates appear in both statistics and user table, check they exist
      const jan15Dates = screen.getAllByText('Jan 15, 2024');
      expect(jan15Dates.length).toBeGreaterThan(0);
      expect(screen.getByText('Jan 16, 2024')).toBeInTheDocument();
      expect(screen.getByText('Jan 17, 2024')).toBeInTheDocument();
    });

    it('shows empty users message when account has no users', () => {
      const emptyAccount = { ...mockAccounts[2], users: [] };
      render(Accounts, { accounts: mockAccounts, selected_account: emptyAccount });

      expect(screen.getByText('No users in this account.')).toBeInTheDocument();
      expect(screen.queryByRole('table')).not.toBeInTheDocument();
    });

    it('displays correct user count in header', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      expect(screen.getByRole('heading', { name: 'Users (3)' })).toBeInTheDocument();
    });

    it('handles zero user count correctly', () => {
      const emptyAccount = { ...mockAccounts[2], users: [] };
      render(Accounts, { accounts: mockAccounts, selected_account: emptyAccount });

      expect(screen.getByRole('heading', { name: 'Users (0)' })).toBeInTheDocument();
      expect(screen.getByText('0')).toBeInTheDocument(); // In statistics section
    });
  });

  describe('Badge Component Integration', () => {
    it('renders account type badge with outline variant', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      // Find the badge specifically (first Organization text should be the badge)
      const organizationElements = screen.getAllByText('Organization');
      expect(organizationElements.length).toBeGreaterThan(0);
      const accountTypeBadge = organizationElements[0];
      expect(accountTypeBadge.closest('span')).toHaveClass('text-foreground'); // outline variant
    });

    it('displays personal account badge correctly', () => {
      const personalAccount = mockAccounts[1];
      render(Accounts, { accounts: mockAccounts, selected_account: personalAccount });

      // Personal Account appears in multiple places, check it exists
      const personalAccountTexts = screen.getAllByText('Personal Account');
      expect(personalAccountTexts.length).toBeGreaterThan(0);
    });
  });

  describe('Card Component Integration', () => {
    it('renders account information card', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      const infoCard = screen.getByRole('heading', { name: 'Account Information' }).closest('[class*="border"]');
      expect(infoCard).toBeInTheDocument();
      expect(infoCard).toHaveClass('border'); // Card component styling
    });

    it('renders statistics card', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      const statsCard = screen.getByRole('heading', { name: 'Statistics' }).closest('[class*="border"]');
      expect(statsCard).toBeInTheDocument();
      expect(statsCard).toHaveClass('border'); // Card component styling
    });

    it('renders users card', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      const usersCard = screen.getByRole('heading', { name: 'Users (3)' }).closest('[class*="border"]');
      expect(usersCard).toBeInTheDocument();
      expect(usersCard).toHaveClass('border'); // Card component styling
    });
  });

  describe('Date Formatting', () => {
    it('formats dates in US locale', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      // Check formatted dates in multiple places
      expect(screen.getByText('Created Jan 15, 2024')).toBeInTheDocument();
      expect(screen.getByText('Updated Jan 20, 2024')).toBeInTheDocument();
      // Jan 15, 2024 and Jan 20, 2024 appear in statistics section too
      const jan15Dates = screen.getAllByText('Jan 15, 2024');
      expect(jan15Dates.length).toBeGreaterThan(0);
      const jan20Dates = screen.getAllByText('Jan 20, 2024');
      expect(jan20Dates.length).toBeGreaterThan(0);
    });

    it('handles same creation and update dates', () => {
      const personalAccount = mockAccounts[1];
      render(Accounts, { accounts: mockAccounts, selected_account: personalAccount });

      // Should show both created and updated even if they're the same
      expect(screen.getByText('Created Feb 1, 2024')).toBeInTheDocument();
      expect(screen.getByText('Updated Feb 1, 2024')).toBeInTheDocument();
    });
  });

  describe('Layout and Responsive Design', () => {
    it('has proper layout structure with sidebar and main content', () => {
      const { container } = render(Accounts, { accounts: mockAccounts });

      const layout = container.querySelector('.flex.h-\\[calc\\(100vh-4rem\\)\\]');
      expect(layout).toBeInTheDocument();

      const sidebar = container.querySelector('aside.w-96');
      expect(sidebar).toBeInTheDocument();

      const mainContent = container.querySelector('main.flex-1');
      expect(mainContent).toBeInTheDocument();
    });

    it('sidebar has proper scrollable area', () => {
      const { container } = render(Accounts, { accounts: mockAccounts });

      const scrollableArea = container.querySelector('.flex-1.overflow-y-auto');
      expect(scrollableArea).toBeInTheDocument();
    });

    it('main content is scrollable', () => {
      const { container } = render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      const mainContent = container.querySelector('main.flex-1.overflow-y-auto');
      expect(mainContent).toBeInTheDocument();
    });
  });

  describe('Interactive Elements', () => {
    it('account buttons are clickable', () => {
      render(Accounts, { accounts: mockAccounts });

      const accountButtons = screen
        .getAllByRole('button')
        .filter(
          (button) =>
            button.textContent.includes('Corporation') ||
            button.textContent.includes('Personal') ||
            button.textContent.includes('Organization')
        );

      expect(accountButtons.length).toBe(3);
      accountButtons.forEach((button) => {
        expect(button).toBeEnabled();
      });
    });

    it('search input is functional', async () => {
      render(Accounts, { accounts: mockAccounts });

      const searchInput = screen.getByPlaceholderText('Search accounts...');
      expect(searchInput).toBeEnabled();

      await fireEvent.input(searchInput, { target: { value: 'test' } });
      expect(searchInput).toHaveValue('test');
    });
  });

  describe('Account Type Handling', () => {
    it('displays different account types correctly', () => {
      render(Accounts, { accounts: mockAccounts });

      expect(screen.getByText('Organization • 5 users')).toBeInTheDocument();
      expect(screen.getByText('Personal • 1 user')).toBeInTheDocument();
    });

    it('handles singular vs plural user count', () => {
      render(Accounts, { accounts: mockAccounts });

      expect(screen.getByText('Personal • 1 user')).toBeInTheDocument(); // Singular
      expect(screen.getByText('Organization • 5 users')).toBeInTheDocument(); // Plural
      expect(screen.getByText('Organization • 0 users')).toBeInTheDocument(); // Zero (plural)
    });
  });

  describe('Edge Cases', () => {
    it('handles account with missing name', () => {
      const accountsWithMissingName = [{ ...mockAccounts[0], name: null }];
      render(Accounts, { accounts: accountsWithMissingName });

      // Should not crash, even if name is null
      const { container } = render(Accounts, { accounts: accountsWithMissingName });
      expect(container).toBeInTheDocument();
    });

    it('handles account with missing owner email', () => {
      const accountsWithMissingOwnerEmail = [
        {
          ...mockAccounts[0],
          owner: { ...mockAccounts[0].owner, email: null },
        },
      ];
      render(Accounts, { accounts: accountsWithMissingOwnerEmail });

      // Should still render the account
      expect(screen.getByText('Acme Corporation')).toBeInTheDocument();
    });

    it('handles users without names in table', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: selectedAccount });

      // User without name should show dash
      expect(screen.getByText('-')).toBeInTheDocument();
    });

    it('handles selected_account being null', () => {
      render(Accounts, { accounts: mockAccounts, selected_account: null });

      expect(screen.getByRole('heading', { name: 'Select an account' })).toBeInTheDocument();
      expect(screen.queryByRole('heading', { name: 'Account Information' })).not.toBeInTheDocument();
    });

    it('handles empty accounts array', () => {
      render(Accounts, { accounts: [] });

      expect(screen.getByText('No accounts found')).toBeInTheDocument();
      expect(screen.queryByRole('button')).not.toBeInTheDocument();
    });

    it('handles account with undefined users array', () => {
      const accountWithUndefinedUsers = {
        ...selectedAccount,
        users: undefined,
      };
      render(Accounts, { accounts: mockAccounts, selected_account: accountWithUndefinedUsers });

      expect(screen.getByText('Total Users')).toBeInTheDocument();
      expect(screen.getByText('0')).toBeInTheDocument(); // Should default to 0
      expect(screen.getByRole('heading', { name: 'Users (0)' })).toBeInTheDocument();
    });
  });

  describe('Personal Account Type Display', () => {
    it('displays personal account correctly in detail view', () => {
      const personalAccount = mockAccounts[1];
      render(Accounts, { accounts: mockAccounts, selected_account: personalAccount });

      // Personal Account appears in multiple places (sidebar, header, badge)
      const personalAccountTexts = screen.getAllByText('Personal Account');
      expect(personalAccountTexts.length).toBeGreaterThan(0);
      // Look for Personal in the account info section specifically
      const personalTexts = screen.getAllByText('Personal');
      expect(personalTexts.length).toBeGreaterThan(0);
    });

    it('shows personal account owner information', () => {
      const personalAccount = mockAccounts[1];
      render(Accounts, { accounts: mockAccounts, selected_account: personalAccount });

      // Alice Brown and user@personal.com appear in multiple places
      const aliceBrownTexts = screen.getAllByText('Alice Brown');
      expect(aliceBrownTexts.length).toBeGreaterThan(0);
      const userEmails = screen.getAllByText('user@personal.com');
      expect(userEmails.length).toBeGreaterThan(0);
    });
  });

  describe('Component State Management', () => {
    it('maintains search state during component lifecycle', async () => {
      const { rerender } = render(Accounts, { accounts: mockAccounts });

      const searchInput = screen.getByPlaceholderText('Search accounts...');
      await fireEvent.input(searchInput, { target: { value: 'acme' } });

      // Rerender with new props
      rerender({ accounts: mockAccounts, selected_account: selectedAccount });

      // Search should persist
      expect(searchInput).toHaveValue('acme');
      expect(screen.getByText('Acme Corporation')).toBeInTheDocument();
      expect(screen.queryByText('Personal Account')).not.toBeInTheDocument();
    });

    it('updates filtered list reactively when search changes', async () => {
      render(Accounts, { accounts: mockAccounts });

      const searchInput = screen.getByPlaceholderText('Search accounts...');

      // Initial state - all accounts visible
      expect(screen.getByText('Acme Corporation')).toBeInTheDocument();
      expect(screen.getByText('Personal Account')).toBeInTheDocument();

      // Filter to one account
      await fireEvent.input(searchInput, { target: { value: 'personal' } });
      expect(screen.queryByText('Acme Corporation')).not.toBeInTheDocument();
      expect(screen.getByText('Personal Account')).toBeInTheDocument();

      // Change filter to different account
      await fireEvent.input(searchInput, { target: { value: 'empty' } });
      expect(screen.queryByText('Personal Account')).not.toBeInTheDocument();
      expect(screen.getByText('Empty Organization')).toBeInTheDocument();
    });
  });
});
