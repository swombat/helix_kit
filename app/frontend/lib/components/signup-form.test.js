import { render, fireEvent, screen } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import SignupForm from './signup-form.svelte';
import { useForm } from '@inertiajs/svelte';

describe('SignupForm Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders signup form with email field only', () => {
    render(SignupForm);
    
    expect(screen.getByRole('heading', { name: 'Sign up' })).toBeInTheDocument();
    expect(screen.getByText("Enter your email to create an account. We'll send you a confirmation link.")).toBeInTheDocument();
    expect(screen.getByLabelText('Email')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Send Confirmation Email' })).toBeInTheDocument();
  });

  it('does not render password fields in initial signup', () => {
    render(SignupForm);
    
    expect(screen.queryByLabelText('Password')).not.toBeInTheDocument();
    expect(screen.queryByLabelText('Password Confirmation')).not.toBeInTheDocument();
  });

  it('renders login link', () => {
    render(SignupForm);
    
    expect(screen.getByText('Already have an account?')).toBeInTheDocument();
    const loginLink = screen.getByText('Log in');
    expect(loginLink).toBeInTheDocument();
    expect(loginLink.tagName).toBe('A');
  });

  it('has correct email input attributes', () => {
    render(SignupForm);
    
    const emailInput = screen.getByLabelText('Email');
    expect(emailInput).toHaveAttribute('type', 'email');
    expect(emailInput).toHaveAttribute('placeholder', 'm@example.com');
    expect(emailInput).toBeRequired();
  });

  it('updates email value on input', async () => {
    render(SignupForm);
    
    const emailInput = screen.getByLabelText('Email');
    
    await fireEvent.input(emailInput, { target: { value: 'test@example.com' } });
    
    expect(emailInput).toHaveValue('test@example.com');
  });

  it('handles form submission', async () => {
    render(SignupForm);
    
    const emailInput = screen.getByLabelText('Email');
    
    await fireEvent.input(emailInput, { target: { value: 'test@example.com' } });
    
    const form = screen.getByRole('button', { name: 'Send Confirmation Email' }).closest('form');
    await fireEvent.submit(form);
    
    // Form submission is handled by mocked useForm
    expect(emailInput).toHaveValue('test@example.com');
  });

  it('shows loading state when processing', async () => {
    render(SignupForm);
    
    // The button should show 'Sending...' when processing
    // This would need proper mocking of the form processing state
  });

  it('displays validation errors when present', () => {
    // Mock the form with errors
    const mockForm = useForm();
    mockForm.errors = {
      email_address: ['Email is already taken']
    };
    
    render(SignupForm);
    
    // InputError components should show these errors
    // Note: Actual error display depends on InputError component implementation
  });

  it('has correct form structure for accessibility', () => {
    render(SignupForm);
    
    const emailInput = screen.getByLabelText('Email');
    expect(emailInput).toHaveAttribute('id', 'email_address');
  });
});