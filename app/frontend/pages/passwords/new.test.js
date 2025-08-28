import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import NewPassword from './new.svelte';

describe('NewPassword Page Component', () => {
  it('renders password reset page', () => {
    render(NewPassword);
    
    expect(screen.getByText('Forgot password?')).toBeInTheDocument();
  });

  it('includes new password form component', () => {
    render(NewPassword);
    
    // Check for form elements
    expect(screen.getByLabelText('Email')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Send password reset link' })).toBeInTheDocument();
  });

  it('displays reset instructions', () => {
    render(NewPassword);
    
    expect(screen.getByText('Enter your email below to receive a password reset link')).toBeInTheDocument();
  });

  it('has back to login link', () => {
    render(NewPassword);
    
    const backLink = screen.getByRole('link', { name: /log in/i });
    expect(backLink).toBeInTheDocument();
  });

  it('uses auth layout structure', () => {
    const { container } = render(NewPassword);
    
    // Should have centered layout typical of auth pages
    const authWrapper = container.querySelector('.max-w-sm');
    expect(authWrapper).toBeInTheDocument();
  });
});