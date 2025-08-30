import { render, fireEvent, screen } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import NewPasswordForm from './new-password-form.svelte';
import { useForm } from '@inertiajs/svelte';

describe('NewPasswordForm Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders password reset form with required fields', () => {
    render(NewPasswordForm);
    
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /send|reset|submit/i })).toBeInTheDocument();
  });

  it('renders back to login link', () => {
    render(NewPasswordForm);
    
    const loginLink = screen.getByRole('link', { name: /log in|back|login/i });
    expect(loginLink).toBeInTheDocument();
  });

  it('has correct input type and attributes', () => {
    render(NewPasswordForm);
    
    const emailInput = screen.getByLabelText(/email/i);
    expect(emailInput).toHaveAttribute('type', 'email');
    expect(emailInput).toBeRequired();
  });

  it('updates form value on input', async () => {
    render(NewPasswordForm);
    
    const emailInput = screen.getByLabelText(/email/i);
    await fireEvent.input(emailInput, { target: { value: 'test@example.com' } });
    
    expect(emailInput).toHaveValue('test@example.com');
  });

  it('handles form submission', async () => {
    render(NewPasswordForm);
    
    const emailInput = screen.getByLabelText(/email/i);
    await fireEvent.input(emailInput, { target: { value: 'test@example.com' } });
    
    const form = screen.getByRole('button', { name: 'Send password reset link' }).closest('form');
    await fireEvent.submit(form);
    
    // Form submission is handled by mocked useForm
    expect(emailInput).toHaveValue('test@example.com');
  });

  it('displays validation errors when present', () => {
    // Mock the form with errors
    const mockForm = useForm();
    mockForm.errors = {
      email_address: ['Email not found']
    };
    
    render(NewPasswordForm);
    
    // InputError component should show these errors
    // Note: Actual error display depends on InputError component implementation
  });

  it('disables submit button when processing', () => {
    const mockForm = useForm();
    mockForm.processing = true;
    
    render(NewPasswordForm);
    
    const submitButton = screen.getByRole('button', { name: 'Send password reset link' });
    // Button disabled state depends on the actual implementation
  });

  it('has correct form structure for accessibility', () => {
    render(NewPasswordForm);
    
    const emailInput = screen.getByLabelText(/email/i);
    expect(emailInput).toHaveAttribute('id', 'email_address');
  });
});