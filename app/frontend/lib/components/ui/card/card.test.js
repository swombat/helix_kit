import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Card from './card.svelte';

describe('Card Component', () => {
  it('renders card container', () => {
    const { container } = render(Card, {
      props: { children: () => 'Card content' }
    });
    
    const card = container.querySelector('div');
    expect(card).toBeInTheDocument();
    expect(card).toHaveTextContent('Card content');
  });

  it('applies default card styling', () => {
    const { container } = render(Card);
    
    const card = container.querySelector('div');
    expect(card?.className).toContain('rounded-xl');
    expect(card?.className).toContain('border');
    expect(card?.className).toContain('bg-card');
    expect(card?.className).toContain('text-card-foreground');
    expect(card?.className).toContain('shadow');
  });

  it('applies custom className', () => {
    const { container } = render(Card, {
      props: { class: 'custom-card-class' }
    });
    
    const card = container.querySelector('div');
    expect(card?.className).toContain('custom-card-class');
  });

  it('passes through additional props', () => {
    const { container } = render(Card, {
      props: {
        'data-testid': 'test-card',
        'role': 'article'
      }
    });
    
    const card = container.querySelector('div');
    expect(card).toHaveAttribute('data-testid', 'test-card');
    expect(card).toHaveAttribute('role', 'article');
  });
});