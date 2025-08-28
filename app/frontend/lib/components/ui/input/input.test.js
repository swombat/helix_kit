import { render, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import Input from './input.svelte';

describe('Input Component', () => {
  it('renders input element', () => {
    const { container } = render(Input);
    
    const input = container.querySelector('input');
    expect(input).toBeInTheDocument();
  });

  it('applies default styling classes', () => {
    const { container } = render(Input);
    
    const input = container.querySelector('input');
    expect(input?.className).toContain('flex');
    expect(input?.className).toContain('h-9');
    expect(input?.className).toContain('w-full');
    expect(input?.className).toContain('rounded-md');
  });

  it('supports value binding', async () => {
    const { container } = render(Input, { 
      props: { value: 'initial value' } 
    });
    
    const input = container.querySelector('input');
    expect(input).toHaveValue('initial value');
    
    await fireEvent.input(input, { target: { value: 'new value' } });
    expect(input).toHaveValue('new value');
  });

  it('handles input events', async () => {
    const handleInput = vi.fn();
    const { container } = render(Input, { 
      props: { oninput: handleInput } 
    });
    
    const input = container.querySelector('input');
    await fireEvent.input(input, { target: { value: 'test' } });
    expect(handleInput).toHaveBeenCalled();
  });

  it('supports different input types', () => {
    const { container, rerender } = render(Input, { 
      props: { type: 'email' } 
    });
    
    let input = container.querySelector('input');
    expect(input).toHaveAttribute('type', 'email');
    
    rerender({ type: 'password' });
    input = container.querySelector('input');
    expect(input).toHaveAttribute('type', 'password');
  });

  it('can be disabled', () => {
    const { container } = render(Input, { 
      props: { disabled: true } 
    });
    
    const input = container.querySelector('input');
    expect(input).toBeDisabled();
  });

  it('supports placeholder text', () => {
    const { container } = render(Input, { 
      props: { placeholder: 'Enter your email' } 
    });
    
    const input = container.querySelector('input');
    expect(input).toHaveAttribute('placeholder', 'Enter your email');
  });

  it('applies custom className', () => {
    const { container } = render(Input, { 
      props: { class: 'custom-input' } 
    });
    
    const input = container.querySelector('input');
    expect(input?.className).toContain('custom-input');
  });

  it('passes through additional props', () => {
    const { container } = render(Input, { 
      props: { 
        'data-testid': 'test-input',
        'aria-label': 'Test input',
        maxlength: '100'
      } 
    });
    
    const input = container.querySelector('input');
    expect(input).toHaveAttribute('data-testid', 'test-input');
    expect(input).toHaveAttribute('aria-label', 'Test input');
    expect(input).toHaveAttribute('maxlength', '100');
  });

  it('supports required attribute', () => {
    const { container } = render(Input, { 
      props: { required: true } 
    });
    
    const input = container.querySelector('input');
    expect(input).toHaveAttribute('required');
  });

  it('supports autofocus attribute', () => {
    const { container } = render(Input, { 
      props: { autofocus: true } 
    });
    
    const input = container.querySelector('input');
    expect(input).toHaveAttribute('autofocus');
  });

  it('supports readonly attribute', () => {
    const { container } = render(Input, { 
      props: { readonly: true } 
    });
    
    const input = container.querySelector('input');
    expect(input).toHaveAttribute('readonly');
  });
});