import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import InputError from './input-error.svelte';

describe('InputError Component', () => {
  it('does not render when no errors provided', () => {
    const { container } = render(InputError, {
      props: { errors: [] }
    });
    
    const errorElement = container.querySelector('.text-destructive');
    expect(errorElement).not.toBeInTheDocument();
  });

  it('renders single error message', () => {
    const { container } = render(InputError, {
      props: { errors: ['this field is required'] }
    });
    
    const errorElement = container.querySelector('.text-destructive');
    expect(errorElement).toBeInTheDocument();
    expect(errorElement).toHaveTextContent('This field is required');
  });

  it('renders all errors when multiple errors provided', () => {
    const { container } = render(InputError, {
      props: { 
        errors: ['error 1', 'error 2', 'error 3'] 
      }
    });
    
    const errorElements = container.querySelectorAll('.text-destructive');
    expect(errorElements).toHaveLength(3);
    expect(errorElements[0]).toHaveTextContent('Error 1');
    expect(errorElements[1]).toHaveTextContent('Error 2');
    expect(errorElements[2]).toHaveTextContent('Error 3');
  });

  it('applies error styling classes', () => {
    const { container } = render(InputError, {
      props: { errors: ['error message'] }
    });
    
    const errorElement = container.querySelector('.text-destructive');
    expect(errorElement?.className).toContain('text-xs');
    expect(errorElement?.className).toContain('text-destructive');
  });

  it('capitalizes first letter of errors', () => {
    const { container } = render(InputError, {
      props: { 
        errors: ['validation failed', 'must be unique']
      }
    });
    
    const errorElements = container.querySelectorAll('.text-destructive');
    expect(errorElements[0]).toHaveTextContent('Validation failed');
    expect(errorElements[1]).toHaveTextContent('Must be unique');
  });

  it('handles undefined errors gracefully', () => {
    const { container } = render(InputError, {
      props: { errors: undefined }
    });
    
    const errorElement = container.querySelector('.text-destructive');
    expect(errorElement).not.toBeInTheDocument();
  });

  it('handles null errors gracefully', () => {
    const { container } = render(InputError, {
      props: { errors: null }
    });
    
    const errorElement = container.querySelector('.text-destructive');
    expect(errorElement).not.toBeInTheDocument();
  });

  it('updates when errors change', () => {
    const { container, rerender } = render(InputError, {
      props: { errors: ['initial error'] }
    });
    
    let errorElement = container.querySelector('.text-destructive');
    expect(errorElement).toHaveTextContent('Initial error');
    
    rerender({ errors: ['updated error'] });
    errorElement = container.querySelector('.text-destructive');
    expect(errorElement).toHaveTextContent('Updated error');
    
    rerender({ errors: [] });
    errorElement = container.querySelector('.text-destructive');
    expect(errorElement).not.toBeInTheDocument();
  });
});