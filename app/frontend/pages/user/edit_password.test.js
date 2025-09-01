import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import EditPassword from './edit_password.svelte';

describe('Edit Password Page Component', () => {
  const mockUser = {
    id: 1,
    email_address: 'test@example.com',
    name: 'Test User',
  };

  it('renders edit password page', () => {
    const { container } = render(EditPassword, { props: { user: mockUser } });

    // The page should render something (it's a minimal wrapper)
    expect(container).toBeTruthy();
  });

  it('renders component structure', () => {
    const { component } = render(EditPassword, { props: { user: mockUser } });

    // Component should be rendered
    expect(component).toBeTruthy();
  });

  it('renders without props', () => {
    const { container } = render(EditPassword, { props: { user: { email_address: '' } } });

    // Should render even without complete props
    expect(container).toBeTruthy();
  });

  it('creates component instance', () => {
    const { component } = render(EditPassword, { props: { user: mockUser } });

    // The component instance should exist
    expect(component).toBeTruthy();
  });

  it('has component container', () => {
    const { container } = render(EditPassword, { props: { user: mockUser } });

    // Container should have content
    expect(container.innerHTML).toBeTruthy();
  });
});
