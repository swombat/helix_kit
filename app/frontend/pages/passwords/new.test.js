import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import NewPassword from './new.svelte';

describe('NewPassword Page Component', () => {
  it('renders password reset page with email field', () => {
    render(NewPassword);

    // Check for email input field
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
  });

  it('includes new password form component', () => {
    render(NewPassword);

    // Check for form elements
    expect(screen.getByLabelText('Email')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Send password reset link' })).toBeInTheDocument();
  });

  it('has submit button for sending reset link', () => {
    render(NewPassword);

    // Check for submit button
    expect(screen.getByRole('button', { name: /send|reset|submit/i })).toBeInTheDocument();
  });

  it('has back to login link', () => {
    render(NewPassword);

    const backLink = screen.getByRole('link', { name: /log in/i });
    expect(backLink).toBeInTheDocument();
  });

  it('uses auth layout structure', () => {
    const { container } = render(NewPassword);

    // Should have centered layout typical of auth pages
    // Form framework now handles layout with container
    const authWrapper = container.querySelector('.container');
    expect(authWrapper).toBeInTheDocument();
  });
});
