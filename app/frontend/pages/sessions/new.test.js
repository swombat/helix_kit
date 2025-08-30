import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Login from './new.svelte';

describe('Login Page Component', () => {
  it('renders login page with heading', () => {
    render(Login);

    // The login page should contain a heading
    expect(screen.getByRole('heading')).toBeInTheDocument();
  });

  it('includes login form component', () => {
    render(Login);

    // Check for form elements
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /log in|sign in|submit/i })).toBeInTheDocument();
  });

  it('has forgot password link', () => {
    render(Login);

    // Should have a link for password reset
    const forgotLink = screen.getByRole('link', { name: /forgot|reset/i });
    expect(forgotLink).toBeInTheDocument();
  });

  it('has sign up link', () => {
    render(Login);

    // Should have a link to sign up page
    const signUpLink = screen.getByRole('link', { name: /sign up/i });
    expect(signUpLink).toBeInTheDocument();
  });

  it('uses auth layout structure', () => {
    const { container } = render(Login);

    // Should have centered layout typical of auth pages
    // Form framework now handles layout with container
    const authWrapper = container.querySelector('.container');
    expect(authWrapper).toBeInTheDocument();
  });
});
