import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Login from './login.svelte';

describe('Login Page Component', () => {
  it('renders login page', () => {
    render(Login);
    
    // The login page should contain the login form heading
    expect(screen.getByRole('heading', { name: 'Log in' })).toBeInTheDocument();
  });

  it('includes login form component', () => {
    render(Login);
    
    // Check for form elements
    expect(screen.getByLabelText('Email')).toBeInTheDocument();
    expect(screen.getByLabelText('Password')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /log in/i })).toBeInTheDocument();
  });

  it('has forgot password link', () => {
    render(Login);
    
    const forgotLink = screen.getByText('Forgot your password?');
    expect(forgotLink).toBeInTheDocument();
  });

  it('has sign up link', () => {
    render(Login);
    
    expect(screen.getByText("Don't have an account?")).toBeInTheDocument();
    const signUpLink = screen.getByRole('link', { name: /sign up/i });
    expect(signUpLink).toBeInTheDocument();
  });

  it('uses auth layout structure', () => {
    const { container } = render(Login);
    
    // Should have centered layout typical of auth pages
    const authWrapper = container.querySelector('.max-w-sm');
    expect(authWrapper).toBeInTheDocument();
  });
});