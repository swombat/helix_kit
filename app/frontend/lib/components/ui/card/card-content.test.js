import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import CardContent from './card-content.svelte';

describe('CardContent Component', () => {
  it('renders card content', () => {
    const { container } = render(CardContent, {
      props: { children: () => 'Content text' }
    });
    
    const content = container.querySelector('div');
    expect(content).toBeInTheDocument();
    expect(content).toHaveTextContent('Content text');
  });

  it('applies default content styling', () => {
    const { container } = render(CardContent);
    
    const content = container.querySelector('div');
    expect(content?.className).toContain('p-6');
    expect(content?.className).toContain('pt-0');
  });

  it('applies custom className', () => {
    const { container } = render(CardContent, {
      props: { class: 'custom-content-class' }
    });
    
    const content = container.querySelector('div');
    expect(content?.className).toContain('custom-content-class');
  });

  it('passes through additional props', () => {
    const { container } = render(CardContent, {
      props: {
        'data-testid': 'test-content',
        'role': 'region'
      }
    });
    
    const content = container.querySelector('div');
    expect(content).toHaveAttribute('data-testid', 'test-content');
    expect(content).toHaveAttribute('role', 'region');
  });
});