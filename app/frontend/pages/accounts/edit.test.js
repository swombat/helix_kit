import { render, fireEvent, waitFor } from '@testing-library/svelte';
import { describe, it, expect, beforeEach } from 'vitest';
import EditAccount from './edit.svelte';

// Mock Inertia router and page
vi.mock('@inertiajs/svelte', () => {
  const mockRouter = {
    visit: vi.fn(),
    put: vi.fn(),
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
  accountPath: (id) => `/accounts/${id}`,
}));

describe('Edit Account Page', () => {
  let mockRouter, mockPage;

  beforeEach(async () => {
    vi.clearAllMocks();
    const inertia = await import('@inertiajs/svelte');
    mockRouter = inertia.__mockRouter;
    mockPage = inertia.__mockPage;
    mockPage.props = {};
  });

  describe('Personal Account Editing', () => {
    const personalAccount = {
      id: 1,
      name: "John Doe's Account",
      personal: true,
      team: false,
      users: [{ id: 1, name: 'John Doe' }],
      users_count: 1,
    };

    it('renders personal account edit interface', () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      const { getByText, getByRole } = render(EditAccount);

      expect(getByText('Edit Account Settings')).toBeInTheDocument();
      expect(getByText('Personal Account')).toBeInTheDocument();
      expect(getByText('Personal')).toBeInTheDocument(); // Badge
      expect(getByRole('button', { name: /convert to team account/i })).toBeInTheDocument();
    });

    it('shows team conversion dialog when convert button clicked', async () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      const { getByRole, getByText, getByLabelText } = render(EditAccount);

      const convertButton = getByRole('button', { name: /convert to team account/i });
      await fireEvent.click(convertButton);

      // Dialog should appear
      expect(getByText('Convert to Team Account')).toBeInTheDocument();
      expect(getByText('Choose a name for your team account')).toBeInTheDocument();
      expect(getByLabelText(/team name/i)).toBeInTheDocument();
    });

    it('handles team conversion submission', async () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      const { getByRole, getByLabelText } = render(EditAccount);

      // Open conversion dialog
      const convertButton = getByRole('button', { name: /convert to team account/i });
      await fireEvent.click(convertButton);

      // Fill in team name
      const teamNameInput = getByLabelText(/team name/i);
      await fireEvent.input(teamNameInput, { target: { value: 'My New Team' } });

      // Submit conversion
      const submitButton = getByRole('button', { name: /^convert$/i });
      expect(submitButton).not.toBeDisabled();

      await fireEvent.click(submitButton);

      expect(mockRouter.put).toHaveBeenCalledWith('/accounts/1', {
        convert_to: 'team',
        account: { name: 'My New Team' },
      });
    });

    it('disables convert button when team name is empty', async () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      const { getByRole } = render(EditAccount);

      // Open conversion dialog
      const convertButton = getByRole('button', { name: /convert to team account/i });
      await fireEvent.click(convertButton);

      // Convert button should be disabled initially
      const submitButton = getByRole('button', { name: /^convert$/i });
      expect(submitButton).toBeDisabled();
    });

    it('cancels team conversion dialog', async () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      const { getByRole, getByText, queryByText } = render(EditAccount);

      // Open conversion dialog
      const convertButton = getByRole('button', { name: /convert to team account/i });
      await fireEvent.click(convertButton);

      expect(getByText('Convert to Team Account')).toBeInTheDocument();

      // Cancel dialog
      const cancelButton = getByRole('button', { name: /cancel/i });
      await fireEvent.click(cancelButton);

      // Dialog should disappear
      expect(queryByText('Convert to Team Account')).not.toBeInTheDocument();
    });
  });

  describe('Team Account Editing', () => {
    const teamAccount = {
      id: 2,
      name: 'Development Team',
      personal: false,
      team: true,
      users: [
        { id: 1, name: 'John Doe' },
        { id: 2, name: 'Jane Smith' },
      ],
      users_count: 2,
    };

    it('renders team account edit interface', () => {
      mockPage.props = {
        account: teamAccount,
        can_be_personal: false,
      };

      const { getByText } = render(EditAccount);

      expect(getByText('Edit Account Settings')).toBeInTheDocument();
      expect(getByText('Development Team')).toBeInTheDocument();
      expect(getByText('Team')).toBeInTheDocument(); // Badge
      expect(getByText('2 users')).toBeInTheDocument();
    });

    it('shows cannot convert message for multi-user teams', () => {
      mockPage.props = {
        account: teamAccount,
        can_be_personal: false,
      };

      const { getByText } = render(EditAccount);

      expect(getByText('Cannot Convert to Personal')).toBeInTheDocument();
      expect(getByText(/Team accounts with multiple users cannot be converted/i)).toBeInTheDocument();
      expect(getByText(/Current team size: 2 users/i)).toBeInTheDocument();
    });
  });

  describe('Single User Team Account', () => {
    const singleUserTeam = {
      id: 3,
      name: 'Solo Team',
      personal: false,
      team: true,
      users: [{ id: 1, name: 'John Doe' }],
      users_count: 1,
    };

    it('shows personal conversion option for single-user teams', () => {
      mockPage.props = {
        account: singleUserTeam,
        can_be_personal: true,
      };

      const { getByText, getByRole } = render(EditAccount);

      expect(getByText('Convert to Personal Account')).toBeInTheDocument();
      expect(getByRole('button', { name: /convert to personal account/i })).toBeInTheDocument();
    });

    it('shows personal conversion dialog when clicked', async () => {
      mockPage.props = {
        account: singleUserTeam,
        can_be_personal: true,
      };

      const { getByRole, getByText } = render(EditAccount);

      const convertButton = getByRole('button', { name: /convert to personal account/i });
      await fireEvent.click(convertButton);

      // Dialog should appear
      expect(getByText('Convert to Personal Account')).toBeInTheDocument();
      expect(getByText(/Are you sure you want to convert this team account/i)).toBeInTheDocument();
      expect(getByText(/You can always convert back to a team account later/i)).toBeInTheDocument();
    });

    it('handles personal conversion submission', async () => {
      mockPage.props = {
        account: singleUserTeam,
        can_be_personal: true,
      };

      const { getByRole } = render(EditAccount);

      // Open conversion dialog
      const convertButton = getByRole('button', { name: /convert to personal account/i });
      await fireEvent.click(convertButton);

      // Submit conversion
      const submitButton = getByRole('button', { name: /^convert$/i });
      await fireEvent.click(submitButton);

      expect(mockRouter.put).toHaveBeenCalledWith('/accounts/3', {
        convert_to: 'personal',
      });
    });

    it('cancels personal conversion dialog', async () => {
      mockPage.props = {
        account: singleUserTeam,
        can_be_personal: true,
      };

      const { getByRole, getByText, queryByText } = render(EditAccount);

      // Open conversion dialog
      const convertButton = getByRole('button', { name: /convert to personal account/i });
      await fireEvent.click(convertButton);

      expect(getByText('Convert to Personal Account')).toBeInTheDocument();

      // Cancel dialog
      const cancelButton = getByRole('button', { name: /cancel/i });
      await fireEvent.click(cancelButton);

      // Dialog should disappear
      expect(queryByText('Convert to Personal Account')).not.toBeInTheDocument();
    });
  });

  describe('Navigation', () => {
    const account = {
      id: 1,
      name: 'Test Account',
      personal: true,
      team: false,
      users: [],
      users_count: 0,
    };

    it('navigates back to account show page when back button clicked', async () => {
      mockPage.props = {
        account,
        can_be_personal: false,
      };

      const { getByRole } = render(EditAccount);

      const backButton = getByRole('button', { name: /back to account/i });
      await fireEvent.click(backButton);

      expect(mockRouter.visit).toHaveBeenCalledWith('/accounts/1');
    });
  });

  describe('Loading States', () => {
    const personalAccount = {
      id: 1,
      name: 'Test Account',
      personal: true,
      team: false,
      users: [],
      users_count: 0,
    };

    it('shows loading spinner during team conversion', async () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      // Mock router.put to not resolve immediately
      let resolvePromise;
      const promise = new Promise((resolve) => {
        resolvePromise = resolve;
      });
      mockRouter.put.mockReturnValue(promise);

      const { getByRole, getByLabelText } = render(EditAccount);

      // Open conversion dialog
      const convertButton = getByRole('button', { name: /convert to team account/i });
      await fireEvent.click(convertButton);

      // Fill in team name
      const teamNameInput = getByLabelText(/team name/i);
      await fireEvent.input(teamNameInput, { target: { value: 'Loading Team' } });

      // Submit conversion
      const submitButton = getByRole('button', { name: /^convert$/i });
      await fireEvent.click(submitButton);

      // Should show loading state
      expect(submitButton).toBeDisabled();
      const spinner = submitButton.querySelector('.animate-spin');
      expect(spinner).toBeInTheDocument();

      // Resolve the promise
      resolvePromise();
      await promise;
    });

    it('shows loading spinner during personal conversion', async () => {
      const singleUserTeam = {
        id: 1,
        name: 'Solo Team',
        personal: false,
        team: true,
        users: [{ id: 1, name: 'John Doe' }],
        users_count: 1,
      };

      mockPage.props = {
        account: singleUserTeam,
        can_be_personal: true,
      };

      // Mock router.put to not resolve immediately
      let resolvePromise;
      const promise = new Promise((resolve) => {
        resolvePromise = resolve;
      });
      mockRouter.put.mockReturnValue(promise);

      const { getByRole } = render(EditAccount);

      // Open conversion dialog
      const convertButton = getByRole('button', { name: /convert to personal account/i });
      await fireEvent.click(convertButton);

      // Submit conversion
      const submitButton = getByRole('button', { name: /^convert$/i });
      await fireEvent.click(submitButton);

      // Should show loading state
      expect(submitButton).toBeDisabled();
      const spinner = submitButton.querySelector('.animate-spin');
      expect(spinner).toBeInTheDocument();

      // Resolve the promise
      resolvePromise();
      await promise;
    });
  });

  describe('User Count Display', () => {
    it('shows singular "user" for one user', () => {
      const singleUserAccount = {
        id: 1,
        name: 'Single User Account',
        personal: true,
        team: false,
        users: [{ id: 1, name: 'John Doe' }],
        users_count: 1,
      };

      mockPage.props = {
        account: singleUserAccount,
        can_be_personal: false,
      };

      const { getByText } = render(EditAccount);

      expect(getByText('1 user')).toBeInTheDocument();
    });

    it('shows plural "users" for multiple users', () => {
      const multiUserAccount = {
        id: 1,
        name: 'Multi User Account',
        personal: false,
        team: true,
        users: [
          { id: 1, name: 'John Doe' },
          { id: 2, name: 'Jane Smith' },
        ],
        users_count: 2,
      };

      mockPage.props = {
        account: multiUserAccount,
        can_be_personal: false,
      };

      const { getByText } = render(EditAccount);

      expect(getByText('2 users')).toBeInTheDocument();
    });

    it('handles users_count fallback when users array missing', () => {
      const accountWithoutUsersArray = {
        id: 1,
        name: 'Test Account',
        personal: true,
        team: false,
        users_count: 3,
      };

      mockPage.props = {
        account: accountWithoutUsersArray,
        can_be_personal: false,
      };

      const { getByText } = render(EditAccount);

      expect(getByText('3 users')).toBeInTheDocument();
    });
  });
});
