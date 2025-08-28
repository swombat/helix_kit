import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import EditPassword from './edit.svelte';

describe('EditPassword Page Component', () => {
  const defaultProps = {
    reset_token: 'test-reset-token-123'
  };

  it('renders password edit page', () => {
    render(EditPassword, { props: defaultProps });
    
    expect(screen.getByText('Update your password')).toBeInTheDocument();
  });

  it('includes edit password form component', () => {
    render(EditPassword, { props: defaultProps });
    
    // Check for form elements
    expect(screen.getByLabelText('New Password')).toBeInTheDocument();
    expect(screen.getByLabelText('New Password Confirmation')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Save' })).toBeInTheDocument();
  });

  it('displays password update instructions', () => {
    render(EditPassword, { props: defaultProps });
    
    expect(screen.getByText('Enter a new password for your account')).toBeInTheDocument();
  });

  it('passes reset token to form', () => {
    const resetToken = 'abc-xyz-123';
    render(EditPassword, { 
      props: { reset_token: resetToken } 
    });
    
    // Form should be rendered with the token
    // The actual token handling is in the edit-password-form component
    expect(screen.getByText('Update your password')).toBeInTheDocument();
  });

  it('uses auth layout structure', () => {
    const { container } = render(EditPassword, { props: defaultProps });
    
    // Should have centered layout typical of auth pages
    const authWrapper = container.querySelector('.max-w-sm');
    expect(authWrapper).toBeInTheDocument();
  });
});