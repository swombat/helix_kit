import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import CardTitle from './card-title.svelte';

describe('CardTitle Component', () => {
  it('renders card title', () => {
    const { container } = render(CardTitle, {
      props: { children: () => 'Card Title' }
    });
    
    const title = container.querySelector('h3');
    expect(title).toBeInTheDocument();
    expect(title).toHaveTextContent('Card Title');
  });

  it('applies default title styling', () => {
    const { container } = render(CardTitle);
    
    const title = container.querySelector('h3');
    expect(title?.className).toContain('font-semibold');
    expect(title?.className).toContain('leading-none');
    expect(title?.className).toContain('tracking-tight');
  });

  it('applies custom className', () => {
    const { container } = render(CardTitle, {
      props: { class: 'custom-title-class' }
    });
    
    const title = container.querySelector('h3');
    expect(title?.className).toContain('custom-title-class');
  });

  it('passes through additional props', () => {
    const { container } = render(CardTitle, {
      props: {
        'data-testid': 'test-title',
        'id': 'card-title-1'
      }
    });
    
    const title = container.querySelector('h3');
    expect(title).toHaveAttribute('data-testid', 'test-title');
    expect(title).toHaveAttribute('id', 'card-title-1');
  });
});