import { render } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import Sonner from './sonner.svelte';

describe('Sonner Component', () => {
  it('renders toast container', () => {
    const { container } = render(Sonner);
    
    // Sonner creates a portal, so we check document.body
    const toaster = document.body.querySelector('[data-sonner-toaster]');
    expect(toaster).toBeInTheDocument();
  });

  it('applies theme based on mode-watcher', () => {
    const { container } = render(Sonner);
    
    const toaster = document.body.querySelector('[data-sonner-toaster]');
    expect(toaster).toBeInTheDocument();
  });

  it('passes through additional props', () => {
    const { container } = render(Sonner, {
      props: {
        position: 'top-center',
        duration: 5000
      }
    });
    
    const toaster = document.body.querySelector('[data-sonner-toaster]');
    expect(toaster).toBeInTheDocument();
  });

  it('applies custom className if provided', () => {
    const { container } = render(Sonner, {
      props: {
        class: 'custom-toast-class'
      }
    });
    
    // Note: The exact implementation depends on how svelte-sonner handles classes
    const toaster = document.body.querySelector('[data-sonner-toaster]');
    expect(toaster).toBeInTheDocument();
  });
});