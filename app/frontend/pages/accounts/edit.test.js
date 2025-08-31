import { render, fireEvent } from '@testing-library/svelte';
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

// We don't need to mock Form component, just verify it renders properly

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

      const { container } = render(EditAccount);

      // Should render a form for personal accounts
      expect(container.querySelector('form')).toBeInTheDocument();
      // Should not have account name input for personal accounts
      expect(container.querySelector('input#name')).not.toBeInTheDocument();
    });

    it('shows informational message for personal accounts', () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      const { container } = render(EditAccount);

      // Should have an informational message area
      const messageArea = container.querySelector('.bg-muted');
      expect(messageArea).toBeInTheDocument();
    });

    it('has Cancel and Save Changes buttons', () => {
      mockPage.props = {
        account: personalAccount,
        can_be_personal: false,
      };

      const { getByRole } = render(EditAccount);

      expect(getByRole('button', { name: /cancel/i })).toBeInTheDocument();
      expect(getByRole('button', { name: /save changes/i })).toBeInTheDocument();
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

      const { container, getByDisplayValue } = render(EditAccount);

      // Should have account name input for team accounts
      const nameInput = container.querySelector('input#name');
      expect(nameInput).toBeInTheDocument();
      expect(getByDisplayValue('Development Team')).toBeInTheDocument();
    });

    it('allows editing team account name', async () => {
      mockPage.props = {
        account: teamAccount,
        can_be_personal: false,
      };

      const { container } = render(EditAccount);

      const nameInput = container.querySelector('input#name');
      expect(nameInput).toBeInTheDocument();
      await fireEvent.input(nameInput, { target: { value: 'New Team Name' } });
      expect(nameInput.value).toBe('New Team Name');
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

    it('shows account name input for single-user teams', () => {
      mockPage.props = {
        account: singleUserTeam,
        can_be_personal: true,
      };

      const { container, getByDisplayValue } = render(EditAccount);

      const nameInput = container.querySelector('input#name');
      expect(nameInput).toBeInTheDocument();
      expect(getByDisplayValue('Solo Team')).toBeInTheDocument();
    });

    it('allows editing account name', async () => {
      mockPage.props = {
        account: singleUserTeam,
        can_be_personal: true,
      };

      const { container } = render(EditAccount);

      const nameInput = container.querySelector('input#name');
      await fireEvent.input(nameInput, { target: { value: 'New Team Name' } });

      expect(nameInput.value).toBe('New Team Name');
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

    it('has cancel button', () => {
      mockPage.props = {
        account,
        can_be_personal: false,
      };

      const { getByRole } = render(EditAccount);

      const cancelButton = getByRole('button', { name: /cancel/i });
      expect(cancelButton).toBeInTheDocument();
    });
  });

  describe('Form Behavior', () => {
    const teamAccount = {
      id: 1,
      name: 'Test Team',
      personal: false,
      team: true,
      users: [],
      users_count: 0,
    };

    it('shows required attribute on account name input for teams', () => {
      mockPage.props = {
        account: teamAccount,
        can_be_personal: false,
      };

      const { container } = render(EditAccount);

      const nameInput = container.querySelector('input#name');
      expect(nameInput).toHaveAttribute('required');
    });

    it('has placeholder on account name input', () => {
      mockPage.props = {
        account: teamAccount,
        can_be_personal: false,
      };

      const { container } = render(EditAccount);

      const nameInput = container.querySelector('input#name');
      expect(nameInput).toHaveAttribute('placeholder');
    });
  });
});
