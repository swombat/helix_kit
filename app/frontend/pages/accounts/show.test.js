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
      };

      const { getByText } = render(ShowAccount);

      // Should show "Personal Account" as display name
      expect(getByText('Personal Account')).toBeInTheDocument();
      expect(getByText('Personal')).toBeInTheDocument(); // Badge
      expect(getByText('Account Settings')).toBeInTheDocument();
    });

    it('shows conversion option for personal accounts', () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      const { getByRole } = render(ShowAccount);

      const convertButton = getByRole('button', { name: /convert to team account/i });
      expect(convertButton).toBeInTheDocument();
    });

    it('displays user count correctly for personal accounts', () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      const { getByText } = render(ShowAccount);

      // Should show 1 user in the usage section
      const userCountElement = getByText('Total Users').nextElementSibling;
      expect(userCountElement).toHaveTextContent('1');
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
      };

      const { getByText } = render(ShowAccount);

      expect(getByText('Development Team')).toBeInTheDocument();
      expect(getByText('Team')).toBeInTheDocument(); // Badge
      // Check user count in usage section
      const userCountElement = getByText('Total Users').nextElementSibling;
      expect(userCountElement).toHaveTextContent('2');
    });

    it('shows cannot convert message for multi-user teams', () => {
      mockPage.props = {
        account: teamAccount,
        can_be_personal: false,
      };

      const { getByText } = render(ShowAccount);

      // Should show the note in the usage section
      const noteElement = document.querySelector('.bg-amber-50 p');
      expect(noteElement).toHaveTextContent(/Team accounts with multiple users cannot be converted/i);
    });

    it('shows conversion option for single-user teams', () => {
      const singleUserTeam = {
        ...teamAccount,
        users: [{ id: 1, name: 'John Doe' }],
      };

      mockPage.props = {
        account: singleUserTeam,
        can_be_personal: true,
      };

      const { getByText, getByRole } = render(ShowAccount);

      expect(getByText(/You can convert this team account back to personal/i)).toBeInTheDocument();

      const convertButton = getByRole('button', { name: /convert to personal account/i });
      expect(convertButton).toBeInTheDocument();
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
      };

      const { getByRole } = render(ShowAccount);

      const editButton = getByRole('button', { name: /edit account/i });
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
      };

      const { getByRole } = render(ShowAccount);

      const convertButton = getByRole('button', { name: /convert to team account/i });
      await convertButton.click();

      expect(mockRouter.visit).toHaveBeenCalledWith('/accounts/1/edit');
    });
  });

  describe('Date Formatting', () => {
    it('formats creation date correctly', () => {
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
      };

      const { getByText } = render(ShowAccount);

      // Should format date as "Jan 15, 2024"
      expect(getByText(/Jan 15, 2024/i)).toBeInTheDocument();
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
      };

      const { getByText } = render(ShowAccount);

      // Should show user count from users_count field in usage section
      const userCountElement = getByText('Total Users').nextElementSibling;
      expect(userCountElement).toHaveTextContent('1');
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
      };

      const { getByText } = render(ShowAccount);

      // Should show 0 users in usage section
      const userCountElement = getByText('Total Users').nextElementSibling;
      expect(userCountElement).toHaveTextContent('0');
    });
  });

  describe('Account ID Display', () => {
    it('shows account ID in monospace font', () => {
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
      };

      const { getByText } = render(ShowAccount);

      const idElement = getByText('42');
      expect(idElement).toHaveClass('font-mono');
    });
  });
});
