import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import CardFooter from './card-footer.svelte';

describe('CardFooter Component', () => {
  it('renders card footer', () => {
    const { container } = render(CardFooter, {
      props: { children: () => 'Footer content' }
    });
    
    const footer = container.querySelector('div');
    expect(footer).toBeInTheDocument();
    expect(footer).toHaveTextContent('Footer content');
  });

  it('applies default footer styling', () => {
    const { container } = render(CardFooter);
    
    const footer = container.querySelector('div');
    expect(footer?.className).toContain('flex');
    expect(footer?.className).toContain('items-center');
    expect(footer?.className).toContain('p-6');
    expect(footer?.className).toContain('pt-0');
  });

  it('applies custom className', () => {
    const { container } = render(CardFooter, {
      props: { class: 'custom-footer-class' }
    });
    
    const footer = container.querySelector('div');
    expect(footer?.className).toContain('custom-footer-class');
  });

  it('passes through additional props', () => {
    const { container } = render(CardFooter, {
      props: {
        'data-testid': 'test-footer',
        'role': 'contentinfo'
      }
    });
    
    const footer = container.querySelector('div');
    expect(footer).toHaveAttribute('data-testid', 'test-footer');
    expect(footer).toHaveAttribute('role', 'contentinfo');
  });
});