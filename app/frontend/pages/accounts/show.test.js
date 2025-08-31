import { render } from '@testing-library/svelte';
import { describe, it, expect, beforeEach } from 'vitest';
import ShowAccount from './show.svelte';

// Mock Inertia router and page
vi.mock('@inertiajs/svelte', () => {
  const mockRouter = {
    visit: vi.fn(),
  };

  const mockPage = {
    props: {},
  };

  return {
    router: mockRouter,
    page: {
      subscribe: (callback) => {
        callback(mockPage);
        return () => {};
      },
    },
    __mockRouter: mockRouter,
    __mockPage: mockPage,
  };
});

// Mock routes
vi.mock('@/routes', () => ({
  editAccountPath: (id) => `/accounts/${id}/edit`,
}));

describe('Show Account Page', () => {
  let mockRouter, mockPage;

  beforeEach(async () => {
    vi.clearAllMocks();
    const inertia = await import('@inertiajs/svelte');
    mockRouter = inertia.__mockRouter;
    mockPage = inertia.__mockPage;
    mockPage.props = {};
  });

  describe('Personal Account Display', () => {
    const personalAccount = {
      id: 1,
      name: "John Doe's Account",
      personal: true,
      team: false,
      created_at: '2024-01-15T10:00:00Z',
      users: [{ id: 1, name: 'John Doe' }],
    };

    it('renders personal account information correctly', () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
        members: [],
      };

      const { container } = render(ShowAccount);

      // Should render without error
      expect(container.querySelector('.container')).toBeInTheDocument();
    });

    it('shows conversion option for personal accounts', () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
        members: [],
      };

      const { container } = render(ShowAccount);

      // Should have conversion button for personal accounts
      const buttons = container.querySelectorAll('button');
      expect(buttons.length).toBeGreaterThan(0);
    });

    it('displays user count for personal accounts', () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
        members: [
          {
            id: 1,
            display_name: 'John Doe',
            invitation_pending: false,
            user: { email_address: 'john@example.com' },
            role: 'owner',
          },
        ],
      };

      const { container } = render(ShowAccount);

      // Should have usage section with user count
      const usageCard = container.querySelectorAll('[class*="card"]')[1]; // Second card is usage
      expect(usageCard).toBeInTheDocument();
    });
  });

  describe('Team Account Display', () => {
    const teamAccount = {
      id: 2,
      name: 'Development Team',
      personal: false,
      team: true,
      created_at: '2024-01-10T10:00:00Z',
      users: [
        { id: 1, name: 'John Doe' },
        { id: 2, name: 'Jane Smith' },
      ],
    };

    it('renders team account information correctly', () => {
      mockPage.props = {
        account: teamAccount,
        can_be_personal: false,
        members: [
          {
            id: 1,
            display_name: 'John Doe',
            invitation_pending: false,
            user: { email_address: 'john@example.com' },
            role: 'owner',
          },
          {
            id: 2,
            display_name: 'Jane Smith',
            invitation_pending: false,
            user: { email_address: 'jane@example.com' },
            role: 'member',
          },
        ],
      };

      const { container } = render(ShowAccount);

      // Should show team name somewhere
      expect(container.textContent).toContain('Development Team');
      // Should have members table for team accounts
      expect(container.querySelector('table')).toBeInTheDocument();
    });

    it('shows conversion note for multi-user teams', () => {
      mockPage.props = {
        account: teamAccount,
        can_be_personal: false,
        members: [
          {
            id: 1,
            display_name: 'John Doe',
            invitation_pending: false,
            user: { email_address: 'john@example.com' },
            role: 'owner',
          },
          {
            id: 2,
            display_name: 'Jane Smith',
            invitation_pending: false,
            user: { email_address: 'jane@example.com' },
            role: 'member',
          },
        ],
      };

      const { container } = render(ShowAccount);

      // Should show a note about conversion restrictions
      const noteElement = container.querySelector('[class*="amber"]');
      expect(noteElement).toBeInTheDocument();
    });

    it('shows conversion option for single-user teams', () => {
      const singleUserTeam = {
        ...teamAccount,
        users: [{ id: 1, name: 'John Doe' }],
      };

      mockPage.props = {
        account: singleUserTeam,
        can_be_personal: true,
        members: [
          {
            id: 1,
            display_name: 'John Doe',
            invitation_pending: false,
            user: { email_address: 'john@example.com' },
            role: 'owner',
          },
        ],
      };

      const { container } = render(ShowAccount);

      // Should show conversion note for single-user team
      const noteElement = container.querySelector('[class*="blue"]');
      expect(noteElement).toBeInTheDocument();
    });
  });

  describe('Edit Button Navigation', () => {
    it('navigates to edit page when edit button clicked', async () => {
      const account = {
        id: 1,
        name: 'Test Account',
        personal: true,
        team: false,
        created_at: '2024-01-15T10:00:00Z',
        users: [],
      };

      mockPage.props = {
        account,
        can_be_personal: false,
        members: [],
      };

      const { container } = render(ShowAccount);

      // Find edit button - it has a Gear icon
      const buttons = container.querySelectorAll('button');
      const editButton = Array.from(buttons).find((btn) => btn.textContent.includes('Edit'));
      await editButton.click();

      expect(mockRouter.visit).toHaveBeenCalledWith('/accounts/1/edit');
    });

    it('navigates to edit page when conversion buttons clicked', async () => {
      const personalAccount = {
        id: 1,
        name: 'Test Account',
        personal: true,
        team: false,
        created_at: '2024-01-15T10:00:00Z',
        users: [],
      };

      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
        members: [],
      };

      const { container } = render(ShowAccount);

      // Find convert button
      const buttons = container.querySelectorAll('button');
      const convertButton = Array.from(buttons).find((btn) => btn.textContent.includes('Convert'));
      await convertButton?.click();

      expect(mockRouter.visit).toHaveBeenCalledWith('/accounts/1/edit');
    });
  });

  describe('Date Formatting', () => {
    it('displays creation date', () => {
      const account = {
        id: 1,
        name: 'Test Account',
        personal: true,
        team: false,
        created_at: '2024-01-15T10:00:00Z',
        users: [],
      };

      mockPage.props = {
        account,
        can_be_personal: false,
        members: [],
      };

      const { container } = render(ShowAccount);

      // Should display date somewhere
      expect(container.textContent).toContain('2024');
    });
  });

  describe('Account Usage Information', () => {
    it('handles missing users array gracefully', () => {
      const accountWithoutUsers = {
        id: 1,
        name: 'Test Account',
        personal: true,
        team: false,
        created_at: '2024-01-15T10:00:00Z',
        users_count: 1,
      };

      mockPage.props = {
        account: accountWithoutUsers,
        can_be_personal: false,
        members: [],
      };

      const { container } = render(ShowAccount);

      // Should render without error
      expect(container.querySelector('.container')).toBeInTheDocument();
    });

    it('shows zero users when no user data available', () => {
      const accountWithNoUserData = {
        id: 1,
        name: 'Test Account',
        personal: true,
        team: false,
        created_at: '2024-01-15T10:00:00Z',
      };

      mockPage.props = {
        account: accountWithNoUserData,
        can_be_personal: false,
        members: [],
      };

      const { container } = render(ShowAccount);

      // Should render without error when no user data
      expect(container.querySelector('.container')).toBeInTheDocument();
    });
  });

  describe('Account ID Display', () => {
    it('displays account ID', () => {
      const account = {
        id: 42,
        name: 'Test Account',
        personal: true,
        team: false,
        created_at: '2024-01-15T10:00:00Z',
        users: [],
      };

      mockPage.props = {
        account,
        can_be_personal: false,
        members: [],
      };

      const { container } = render(ShowAccount);

      // Should display account ID somewhere
      expect(container.textContent).toContain('42');
      // Should have monospace font element
      expect(container.querySelector('.font-mono')).toBeInTheDocument();
    });
  });
});
