import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import ConfirmEmail from './confirm_email.svelte';

describe('Confirm Email Page Component', () => {
  it('renders confirm email page structure', () => {
    const { container } = render(ConfirmEmail, { token: 'test-token' });

    // Should have card structure
    const card = container.querySelector('.max-w-sm');
    expect(card).toBeInTheDocument();
  });

  it('has centered layout', () => {
    const { container } = render(ConfirmEmail, { token: 'test-token' });

    // Should have centered flex layout
    const flexContainer = container.querySelector('.flex.flex-col.h-screen');
    expect(flexContainer).toBeInTheDocument();

    const centeredContent = container.querySelector('.items-center.justify-center');
    expect(centeredContent).toBeInTheDocument();
  });

  it('renders with proper card header', () => {
    const { container } = render(ConfirmEmail, { token: 'test-token' });

    // Should have card header with centered content
    const cardHeader = container.querySelector('.text-center');
    expect(cardHeader).toBeInTheDocument();
  });

  it('has icon container', () => {
    const { container } = render(ConfirmEmail, { token: 'test-token' });

    // Should have icon container with rounded style
    const iconContainer = container.querySelector('.rounded-full');
    expect(iconContainer).toBeInTheDocument();
  });

  it('renders page structure elements', () => {
    const { container } = render(ConfirmEmail, { token: 'test-token' });

    // Should have proper page structure
    const pageWrapper = container.querySelector('.w-full');
    expect(pageWrapper).toBeInTheDocument();

    const maxWidth = container.querySelector('.mx-auto');
    expect(maxWidth).toBeInTheDocument();
  });
});
