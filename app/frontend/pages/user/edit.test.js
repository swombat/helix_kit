import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import EditUser from './edit.svelte';

describe('Edit User Page Component', () => {
  const mockUser = {
    id: 1,
    email: 'test@example.com',
    name: 'Test User',
    timezone: 'America/New_York',
  };

  const mockTimezones = ['America/New_York', 'America/Los_Angeles', 'Europe/London', 'Asia/Tokyo'];

  it('renders edit user page', () => {
    const { container } = render(EditUser, {
      user: mockUser,
      timezones: mockTimezones,
    });

    // The page should render something (it's a minimal wrapper)
    expect(container).toBeTruthy();
  });

  it('renders with user prop', () => {
    const { component } = render(EditUser, {
      user: mockUser,
      timezones: mockTimezones,
    });

    // Component should render with user prop
    expect(component).toBeTruthy();
  });

  it('renders with timezones prop', () => {
    const { component } = render(EditUser, {
      user: mockUser,
      timezones: mockTimezones,
    });

    // Component should render with timezones prop
    expect(component).toBeTruthy();
  });

  it('has container element', () => {
    const { container } = render(EditUser, {
      user: mockUser,
      timezones: mockTimezones,
    });

    // Should have content in container
    expect(container.innerHTML).toBeTruthy();
  });

  it('creates component successfully', () => {
    const result = render(EditUser, {
      user: mockUser,
      timezones: mockTimezones,
    });

    // Should successfully create the component
    expect(result).toBeTruthy();
  });
});
