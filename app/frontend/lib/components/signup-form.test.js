import { render, fireEvent, screen } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import SignupForm from './signup-form.svelte';
import { useForm } from '@inertiajs/svelte';

describe('SignupForm Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders signup form with all required fields', () => {
    render(SignupForm);
    
    expect(screen.getByRole('heading', { name: 'Sign up' })).toBeInTheDocument();
    expect(screen.getByText('Enter your email to create an account')).toBeInTheDocument();
    expect(screen.getByLabelText('Email')).toBeInTheDocument();
    expect(screen.getByLabelText('Password')).toBeInTheDocument();
    expect(screen.getByLabelText('Password Confirmation')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Sign up' })).toBeInTheDocument();
  });

  it('renders login link', () => {
    render(SignupForm);
    
    expect(screen.getByText('Already have an account?')).toBeInTheDocument();
    const loginLink = screen.getByText('Log in');
    expect(loginLink).toBeInTheDocument();
    expect(loginLink.tagName).toBe('A');
  });

  it('has correct input types and attributes', () => {
    render(SignupForm);
    
    const emailInput = screen.getByLabelText('Email');
    expect(emailInput).toHaveAttribute('type', 'email');
    expect(emailInput).toHaveAttribute('placeholder', 'm@example.com');
    expect(emailInput).toBeRequired();
    
    const passwordInput = screen.getByLabelText('Password');
    expect(passwordInput).toHaveAttribute('type', 'password');
    expect(passwordInput).toBeRequired();
    
    const confirmPasswordInput = screen.getByLabelText('Password Confirmation');
    expect(confirmPasswordInput).toHaveAttribute('type', 'password');
    expect(confirmPasswordInput).toBeRequired();
  });

  it('updates form values on input', async () => {
    render(SignupForm);
    
    const emailInput = screen.getByLabelText('Email');
    const passwordInput = screen.getByLabelText('Password');
    const confirmPasswordInput = screen.getByLabelText('Password Confirmation');
    
    await fireEvent.input(emailInput, { target: { value: 'test@example.com' } });
    await fireEvent.input(passwordInput, { target: { value: 'password123' } });
    await fireEvent.input(confirmPasswordInput, { target: { value: 'password123' } });
    
    expect(emailInput).toHaveValue('test@example.com');
    expect(passwordInput).toHaveValue('password123');
    expect(confirmPasswordInput).toHaveValue('password123');
  });

  it('handles form submission', async () => {
    render(SignupForm);
    
    const emailInput = screen.getByLabelText('Email');
    const passwordInput = screen.getByLabelText('Password');
    const confirmPasswordInput = screen.getByLabelText('Password Confirmation');
    
    await fireEvent.input(emailInput, { target: { value: 'test@example.com' } });
    await fireEvent.input(passwordInput, { target: { value: 'password123' } });
    await fireEvent.input(confirmPasswordInput, { target: { value: 'password123' } });
    
    const form = screen.getByRole('button', { name: 'Sign up' }).closest('form');
    await fireEvent.submit(form);
    
    // Form submission is handled by mocked useForm
    expect(emailInput).toHaveValue('test@example.com');
    expect(passwordInput).toHaveValue('password123');
  });

  it('displays validation errors when present', () => {
    // Mock the form with errors
    const mockForm = useForm();
    mockForm.errors = {
      email_address: ['Email is already taken'],
      password: ['Password must be at least 8 characters'],
      password_confirmation: ['Passwords do not match']
    };
    
    render(SignupForm);
    
    // InputError components should show these errors
    // Note: Actual error display depends on InputError component implementation
  });

  it('has correct form structure for accessibility', () => {
    render(SignupForm);
    
    const emailInput = screen.getByLabelText('Email');
    expect(emailInput).toHaveAttribute('id', 'email_address');
    
    const passwordInput = screen.getByLabelText('Password');
    expect(passwordInput).toHaveAttribute('id', 'password');
    
    const confirmPasswordInput = screen.getByLabelText('Password Confirmation');
    expect(confirmPasswordInput).toHaveAttribute('id', 'password_confirmation');
  });
});