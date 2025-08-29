import { render, fireEvent, screen } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import EditPasswordForm from './edit-password-form.svelte';
import { useForm, page } from '@inertiajs/svelte';

describe('EditPasswordForm Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders edit password form with required fields', () => {
    render(EditPasswordForm);
    
    // Should have two password fields
    expect(screen.getByLabelText(/new password$/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/confirmation/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /save|submit|update/i })).toBeInTheDocument();
  });

  it('has correct input types and attributes', () => {
    render(EditPasswordForm);
    
    const passwordInput = screen.getByLabelText(/new password$/i);
    expect(passwordInput).toHaveAttribute('type', 'password');
    expect(passwordInput).toBeRequired();
    
    const confirmPasswordInput = screen.getByLabelText(/confirmation/i);
    expect(confirmPasswordInput).toHaveAttribute('type', 'password');
    expect(confirmPasswordInput).toBeRequired();
  });

  it('updates form values on input', async () => {
    render(EditPasswordForm);
    
    const passwordInput = screen.getByLabelText(/new password$/i);
    const confirmPasswordInput = screen.getByLabelText(/confirmation/i);
    
    await fireEvent.input(passwordInput, { target: { value: 'newpassword123' } });
    await fireEvent.input(confirmPasswordInput, { target: { value: 'newpassword123' } });
    
    expect(passwordInput).toHaveValue('newpassword123');
    expect(confirmPasswordInput).toHaveValue('newpassword123');
  });

  it('renders as a card component', () => {
    const { container } = render(EditPasswordForm);
    
    // Should be wrapped in a card
    const card = container.querySelector('.rounded-xl.border.shadow');
    expect(card).toBeInTheDocument();
    
    // Should have max-width constraint
    expect(card).toHaveClass('max-w-sm');
  });

  it('has proper form structure', async () => {
    render(EditPasswordForm);
    
    const form = screen.getByRole('button', { name: 'Save' }).closest('form');
    expect(form).toBeInTheDocument();
    
    // Should have submit button
    const submitButton = screen.getByRole('button', { name: 'Save' });
    expect(submitButton).toHaveAttribute('type', 'submit');
  });

  it('uses proper grid layout', () => {
    const { container } = render(EditPasswordForm);
    
    // Should use grid layout for form fields
    const gridContainer = container.querySelector('.grid.gap-4');
    expect(gridContainer).toBeInTheDocument();
    
    const fieldGroups = container.querySelectorAll('.grid.gap-2');
    expect(fieldGroups.length).toBeGreaterThanOrEqual(2);
  });

  it('has correct form structure for accessibility', () => {
    render(EditPasswordForm);
    
    const passwordInput = screen.getByLabelText('New Password');
    expect(passwordInput).toHaveAttribute('id', 'password');
    
    const confirmPasswordInput = screen.getByLabelText('New Password Confirmation');
    expect(confirmPasswordInput).toHaveAttribute('id', 'password_confirmation');
  });
});