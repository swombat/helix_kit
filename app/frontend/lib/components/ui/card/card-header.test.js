import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import CardHeader from './card-header.svelte';

describe('CardHeader Component', () => {
  it('renders card header', () => {
    const { container } = render(CardHeader, {
      props: { children: () => 'Header content' }
    });
    
    const header = container.querySelector('div');
    expect(header).toBeInTheDocument();
    expect(header).toHaveTextContent('Header content');
  });

  it('applies default header styling', () => {
    const { container } = render(CardHeader);
    
    const header = container.querySelector('div');
    expect(header?.className).toContain('flex');
    expect(header?.className).toContain('flex-col');
    expect(header?.className).toContain('space-y-1.5');
    expect(header?.className).toContain('p-6');
  });

  it('applies custom className', () => {
    const { container } = render(CardHeader, {
      props: { class: 'custom-header-class' }
    });
    
    const header = container.querySelector('div');
    expect(header?.className).toContain('custom-header-class');
  });

  it('passes through additional props', () => {
    const { container } = render(CardHeader, {
      props: {
        'data-testid': 'test-header',
        'id': 'card-header-1'
      }
    });
    
    const header = container.querySelector('div');
    expect(header).toHaveAttribute('data-testid', 'test-header');
    expect(header).toHaveAttribute('id', 'card-header-1');
  });
});