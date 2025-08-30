import { render } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import Logo from './helix-kit-logo.svelte';

// Mock the SVG import
vi.mock('../../../../assets/images/helix-kit-logo.svg?raw', () => ({
  default: '<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40"/></svg>',
}));

describe('Logo Component', () => {
  it('renders SVG logo', () => {
    const { container } = render(Logo);

    const svg = container.querySelector('svg');
    expect(svg).toBeInTheDocument();
  });

  it('applies default width and height', () => {
    const { container } = render(Logo);

    const svg = container.querySelector('svg');
    expect(svg).toHaveAttribute('width', '84');
    expect(svg).toHaveAttribute('height', '84');
  });

  it('applies custom width and height', () => {
    const { container } = render(Logo, {
      props: { width: 100, height: 100 },
    });

    const svg = container.querySelector('svg');
    expect(svg).toHaveAttribute('width', '100');
    expect(svg).toHaveAttribute('height', '100');
  });

  it('applies custom className', () => {
    const { container } = render(Logo, {
      props: { class: 'custom-logo-class' },
    });

    const svg = container.querySelector('svg');
    expect(svg).toHaveAttribute('class', 'custom-logo-class');
  });

  it('passes through additional props as attributes', () => {
    const { container } = render(Logo, {
      props: {
        'data-testid': 'app-logo',
        'aria-label': 'Application logo',
        role: 'img',
      },
    });

    const svg = container.querySelector('svg');
    expect(svg).toHaveAttribute('data-testid', 'app-logo');
    expect(svg).toHaveAttribute('aria-label', 'Application logo');
    expect(svg).toHaveAttribute('role', 'img');
  });

  it('maintains SVG structure', () => {
    const { container } = render(Logo);

    const svg = container.querySelector('svg');
    const circle = svg?.querySelector('circle');
    expect(circle).toBeInTheDocument();
  });
});
