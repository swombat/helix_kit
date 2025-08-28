import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Label from './label.svelte';

describe('Label Component', () => {
  it('renders label with content', () => {
    const { container } = render(Label, { 
      props: { 
        children: () => 'Email Address'
      } 
    });
    
    const label = container.querySelector('label');
    expect(label).toBeInTheDocument();
    expect(label).toHaveTextContent('Email Address');
  });

  it('applies default styling classes', () => {
    const { container } = render(Label, { 
      props: { 
        children: () => 'Test Label'
      } 
    });
    
    const label = container.querySelector('label');
    expect(label?.className).toContain('text-sm');
    expect(label?.className).toContain('font-medium');
    expect(label?.className).toContain('leading-none');
  });

  it('applies custom className', () => {
    const { container } = render(Label, { 
      props: { 
        class: 'custom-label-class',
        children: () => 'Custom Label'
      } 
    });
    
    const label = container.querySelector('label');
    expect(label?.className).toContain('custom-label-class');
  });

  it('passes through additional props', () => {
    const { container } = render(Label, { 
      props: { 
        for: 'email-input',
        'data-testid': 'email-label',
        children: () => 'Email'
      } 
    });
    
    const label = container.querySelector('label');
    expect(label).toHaveAttribute('for', 'email-input');
    expect(label).toHaveAttribute('data-testid', 'email-label');
  });

  it('applies peer disabled styles', () => {
    const { container } = render(Label, { 
      props: { 
        children: () => 'Disabled Label'
      } 
    });
    
    const label = container.querySelector('label');
    expect(label?.className).toContain('peer-disabled:cursor-not-allowed');
    expect(label?.className).toContain('peer-disabled:opacity-70');
  });
});