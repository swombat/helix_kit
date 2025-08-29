import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Signup from './signup.svelte';

describe('Signup Page Component', () => {
  it('renders signup page with heading', () => {
    render(Signup);
    
    // The signup page should contain a heading
    expect(screen.getByRole('heading')).toBeInTheDocument();
  });

  it('includes signup form component', () => {
    render(Signup);
    
    // Check for form elements - new flow only asks for email
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /send|sign|submit/i })).toBeInTheDocument();
  });

  it('has login link for existing users', () => {
    render(Signup);
    
    // Should have a link to login page
    const loginLink = screen.getByRole('link', { name: /log in/i });
    expect(loginLink).toBeInTheDocument();
  });

  it('has email input field and submit button', () => {
    render(Signup);
    
    // Check for functional form elements
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByRole('button')).toBeInTheDocument();
  });

  it('uses auth layout structure', () => {
    const { container } = render(Signup);
    
    // Should have centered layout typical of auth pages
    const authWrapper = container.querySelector('.max-w-sm');
    expect(authWrapper).toBeInTheDocument();
  });
});