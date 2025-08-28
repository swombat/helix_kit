import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Signup from './signup.svelte';

describe('Signup Page Component', () => {
  it('renders signup page', () => {
    render(Signup);
    
    // The signup page should contain the signup form heading
    expect(screen.getByRole('heading', { name: 'Sign up' })).toBeInTheDocument();
  });

  it('includes signup form component', () => {
    render(Signup);
    
    // Check for form elements
    expect(screen.getByLabelText('Email')).toBeInTheDocument();
    expect(screen.getByLabelText('Password')).toBeInTheDocument();
    expect(screen.getByLabelText('Password Confirmation')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Sign up' })).toBeInTheDocument();
  });

  it('has login link for existing users', () => {
    render(Signup);
    
    expect(screen.getByText('Already have an account?')).toBeInTheDocument();
    const loginLink = screen.getByRole('link', { name: /log in/i });
    expect(loginLink).toBeInTheDocument();
  });

  it('displays signup description', () => {
    render(Signup);
    
    expect(screen.getByText('Enter your email to create an account')).toBeInTheDocument();
  });

  it('uses auth layout structure', () => {
    const { container } = render(Signup);
    
    // Should have centered layout typical of auth pages
    const authWrapper = container.querySelector('.max-w-sm');
    expect(authWrapper).toBeInTheDocument();
  });
});