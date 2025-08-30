import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import CheckEmail from './check_email.svelte';

describe('Check Email Page Component', () => {
  it('renders check email page with heading', () => {
    render(CheckEmail, { email: 'test@example.com' });

    // The page should contain check email message
    expect(screen.getByText('Check Your Email')).toBeInTheDocument();
  });

  it('displays email address when provided', () => {
    render(CheckEmail, { email: 'test@example.com' });

    // Should show the email address
    expect(screen.getByText('test@example.com')).toBeInTheDocument();
  });

  it('shows helpful instructions', () => {
    render(CheckEmail, { email: 'test@example.com' });

    // Should show instructions for users
    expect(screen.getByText(/Didn't receive the email/i)).toBeInTheDocument();
    expect(screen.getByText(/Check your spam or junk folder/i)).toBeInTheDocument();
    expect(screen.getByText(/Make sure you entered the correct email/i)).toBeInTheDocument();
    expect(screen.getByText(/Wait a few minutes and check again/i)).toBeInTheDocument();
  });

  it('has button to try different email', () => {
    render(CheckEmail, { email: 'test@example.com' });

    // Should have a button to go back to signup
    const differentEmailButton = screen.getByRole('button', { name: /Try with a different email/i });
    expect(differentEmailButton).toBeInTheDocument();
  });

  it('renders without email prop', () => {
    render(CheckEmail, {});

    // Should still render the page
    expect(screen.getByText('Check Your Email')).toBeInTheDocument();
    // But shouldn't show specific email
    expect(screen.queryByText('test@example.com')).not.toBeInTheDocument();
  });

  it('has proper page structure', () => {
    const { container } = render(CheckEmail, { email: 'test@example.com' });

    // Should have centered layout
    const authWrapper = container.querySelector('.max-w-sm');
    expect(authWrapper).toBeInTheDocument();

    const flexContainer = container.querySelector('.flex.flex-col.h-screen');
    expect(flexContainer).toBeInTheDocument();
  });

  it('has instruction card with proper styling', () => {
    const { container } = render(CheckEmail, { email: 'test@example.com' });

    // Should have muted background section for instructions
    const mutedSection = container.querySelector('.bg-muted');
    expect(mutedSection).toBeInTheDocument();
  });

  it('displays icon container', () => {
    const { container } = render(CheckEmail, { email: 'test@example.com' });

    // Should have icon container
    const iconContainer = container.querySelector('.rounded-full');
    expect(iconContainer).toBeInTheDocument();
  });
});
