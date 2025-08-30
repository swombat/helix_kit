import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import SetPassword from './set_password.svelte';

describe('Set Password Page Component', () => {
  it('renders set password page with success message', () => {
    render(SetPassword, {
      user: { id: 1, email: 'test@example.com' },
      email: 'test@example.com',
    });

    // The page should contain confirmation message
    expect(screen.getByText('Email Confirmed!')).toBeInTheDocument();
    expect(screen.getByText(/secure your account with a password/i)).toBeInTheDocument();
  });

  it('displays confirmation card structure', () => {
    const { container } = render(SetPassword, {
      user: { id: 1, email: 'test@example.com' },
      email: 'test@example.com',
    });

    // Should have card with success indicator
    const card = container.querySelector('.max-w-sm');
    expect(card).toBeInTheDocument();
  });

  it('has page structure elements', () => {
    const { container } = render(SetPassword, {
      user: { id: 1, email: 'test@example.com' },
      email: 'test@example.com',
    });

    // Should have proper layout structure
    const flexContainer = container.querySelector('.flex.flex-col.h-screen');
    expect(flexContainer).toBeInTheDocument();
  });

  it('renders without user prop', () => {
    render(SetPassword, { email: 'test@example.com' });

    // Should still render the page
    expect(screen.getByText('Email Confirmed!')).toBeInTheDocument();
  });

  it('has centered content layout', () => {
    const { container } = render(SetPassword, {
      user: { id: 1, email: 'test@example.com' },
      email: 'test@example.com',
    });

    // Should have centered layout
    const centeredContent = container.querySelector('.items-center.justify-center');
    expect(centeredContent).toBeInTheDocument();
  });
});
