import { render, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import TestButton from '../../../test/TestButton.svelte';

describe('Button Component', () => {
  it('renders as button by default', () => {
    const { container } = render(TestButton, { 
      props: { text: 'Click me' } 
    });
    
    const button = container.querySelector('button');
    expect(button).toBeInTheDocument();
    expect(button).toHaveTextContent('Click me');
  });

  it('renders as link when href is provided', () => {
    const { container } = render(TestButton, { 
      props: { 
        href: '/test-link',
        text: 'Link text'
      } 
    });
    
    const link = container.querySelector('a');
    expect(link).toBeInTheDocument();
    expect(link).toHaveAttribute('href', '/test-link');
    expect(link).toHaveTextContent('Link text');
  });

  it('applies correct variant classes', () => {
    const { container, rerender } = render(TestButton, { 
      props: { 
        variant: 'destructive',
        text: 'Delete' 
      } 
    });
    
    const button = container.querySelector('button');
    expect(button?.className).toContain('bg-destructive');
    
    rerender({ variant: 'outline', text: 'Cancel' });
    expect(button?.className).toContain('border');
  });

  it('applies correct size classes', () => {
    const { container, rerender } = render(TestButton, { 
      props: { 
        size: 'sm',
        text: 'Small' 
      } 
    });
    
    const button = container.querySelector('button');
    expect(button?.className).toContain('h-8');
    
    rerender({ size: 'lg', text: 'Large' });
    expect(button?.className).toContain('h-10');
  });

  it('handles click events', async () => {
    const handleClick = vi.fn();
    const { container } = render(TestButton, { 
      props: { 
        onclick: handleClick,
        text: 'Click me' 
      } 
    });
    
    const button = container.querySelector('button');
    await fireEvent.click(button);
    expect(handleClick).toHaveBeenCalledOnce();
  });

  it('can be disabled', () => {
    const { container } = render(TestButton, { 
      props: { 
        disabled: true,
        text: 'Disabled' 
      } 
    });
    
    const button = container.querySelector('button');
    expect(button).toBeDisabled();
  });

  it('supports custom className', () => {
    const { container } = render(TestButton, { 
      props: { 
        class: 'custom-class',
        text: 'Custom' 
      } 
    });
    
    const button = container.querySelector('button');
    expect(button?.className).toContain('custom-class');
  });

  it('passes through additional props', () => {
    const { container } = render(TestButton, { 
      props: { 
        'data-testid': 'test-button',
        'aria-label': 'Test button',
        text: 'Test' 
      } 
    });
    
    const button = container.querySelector('button');
    expect(button).toHaveAttribute('data-testid', 'test-button');
    expect(button).toHaveAttribute('aria-label', 'Test button');
  });

  it('sets type attribute correctly', () => {
    const { container } = render(TestButton, { 
      props: { 
        type: 'submit',
        text: 'Submit' 
      } 
    });
    
    const button = container.querySelector('button');
    expect(button).toHaveAttribute('type', 'submit');
  });
});