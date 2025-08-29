import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import EditPassword from './edit.svelte';

describe('EditPassword Page Component', () => {
  const defaultProps = {
    reset_token: 'test-reset-token-123'
  };

  it('renders password edit page with form', () => {
    render(EditPassword, { props: defaultProps });
    
    // Check that password form fields are present (should have multiple)
    const passwordFields = screen.getAllByLabelText(/password/i);
    expect(passwordFields.length).toBeGreaterThan(0);
  });

  it('includes edit password form component', () => {
    render(EditPassword, { props: defaultProps });
    
    // Check for form elements
    expect(screen.getByLabelText('New Password')).toBeInTheDocument();
    expect(screen.getByLabelText('New Password Confirmation')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Save' })).toBeInTheDocument();
  });

  it('includes both password fields for confirmation', () => {
    render(EditPassword, { props: defaultProps });
    
    // Should have two password fields for password and confirmation
    const passwordFields = screen.getAllByLabelText(/password/i);
    expect(passwordFields).toHaveLength(2);
  });

  it('renders form with save button', () => {
    const resetToken = 'abc-xyz-123';
    render(EditPassword, { 
      props: { reset_token: resetToken } 
    });
    
    // Form should have a save/submit button
    expect(screen.getByRole('button', { name: /save|submit|update/i })).toBeInTheDocument();
  });

  it('uses auth layout structure', () => {
    const { container } = render(EditPassword, { props: defaultProps });
    
    // Should have centered layout typical of auth pages
    const authWrapper = container.querySelector('.max-w-sm');
    expect(authWrapper).toBeInTheDocument();
  });
});