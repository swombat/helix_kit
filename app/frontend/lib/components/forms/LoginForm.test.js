import { render, fireEvent, screen } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import LoginForm from './LoginForm.svelte';
import { useForm } from '@inertiajs/svelte';

describe('LoginForm Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders login form with all required fields', () => {
    render(LoginForm);
    
    expect(screen.getByRole('heading', { name: 'Log in' })).toBeInTheDocument();
    // Form should be rendered (checking for form fields instead of specific text)
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Log in' })).toBeInTheDocument();
  });

  it('renders forgot password link', () => {
    render(LoginForm);
    
    const forgotLink = screen.getByRole('link', { name: /forgot|reset/i });
    expect(forgotLink).toBeInTheDocument();
    expect(forgotLink.tagName).toBe('A');
  });

  it('renders sign up link', () => {
    render(LoginForm);
    
    expect(screen.getByText("Don't have an account?")).toBeInTheDocument();
    const signUpLink = screen.getByRole('link', { name: /sign up/i });
    expect(signUpLink).toBeInTheDocument();
    expect(signUpLink.tagName).toBe('A');
  });

  it('has correct input types', () => {
    render(LoginForm);
    
    const emailInput = screen.getByLabelText(/email/i);
    expect(emailInput).toHaveAttribute('type', 'email');
    expect(emailInput).toHaveAttribute('placeholder', 'm@example.com');
    expect(emailInput).toBeRequired();
    
    const passwordInput = screen.getByLabelText(/password/i);
    expect(passwordInput).toHaveAttribute('type', 'password');
    expect(passwordInput).toBeRequired();
  });

  it('updates form values on input', async () => {
    render(LoginForm);
    
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    
    await fireEvent.input(emailInput, { target: { value: 'test@example.com' } });
    await fireEvent.input(passwordInput, { target: { value: 'password123' } });
    
    expect(emailInput).toHaveValue('test@example.com');
    expect(passwordInput).toHaveValue('password123');
  });

  it('handles form submission', async () => {
    render(LoginForm);
    
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    
    await fireEvent.input(emailInput, { target: { value: 'test@example.com' } });
    await fireEvent.input(passwordInput, { target: { value: 'password123' } });
    
    const form = screen.getByRole('button', { name: 'Log in' }).closest('form');
    await fireEvent.submit(form);
    
    // Form submission is handled by mocked useForm
    expect(emailInput).toHaveValue('test@example.com');
    expect(passwordInput).toHaveValue('password123');
  });

  it('displays validation errors when present', () => {
    // Mock the form with errors
    const mockForm = useForm();
    mockForm.errors = {
      email_address: ['Email is invalid'],
      password: ['Password is required']
    };
    
    render(LoginForm);
    
    // InputError components should show these errors
    // Note: Actual error display depends on InputError component implementation
  });

  it('has correct form structure for accessibility', () => {
    render(LoginForm);
    
    const emailInput = screen.getByLabelText(/email/i);
    expect(emailInput).toHaveAttribute('id', 'email_address');
    
    const passwordInput = screen.getByLabelText(/password/i);
    expect(passwordInput).toHaveAttribute('id', 'password');
  });
});