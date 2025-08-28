import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import CardDescription from './card-description.svelte';

describe('CardDescription Component', () => {
  it('renders card description', () => {
    const { container } = render(CardDescription, {
      props: { children: () => 'Card description text' }
    });
    
    const description = container.querySelector('p');
    expect(description).toBeInTheDocument();
    expect(description).toHaveTextContent('Card description text');
  });

  it('applies default description styling', () => {
    const { container } = render(CardDescription);
    
    const description = container.querySelector('p');
    expect(description?.className).toContain('text-sm');
    expect(description?.className).toContain('text-muted-foreground');
  });

  it('applies custom className', () => {
    const { container } = render(CardDescription, {
      props: { class: 'custom-description-class' }
    });
    
    const description = container.querySelector('p');
    expect(description?.className).toContain('custom-description-class');
  });

  it('passes through additional props', () => {
    const { container } = render(CardDescription, {
      props: {
        'data-testid': 'test-description',
        'id': 'card-desc-1'
      }
    });
    
    const description = container.querySelector('p');
    expect(description).toHaveAttribute('data-testid', 'test-description');
    expect(description).toHaveAttribute('id', 'card-desc-1');
  });
});