import { render, screen } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import Layout from './Layout.svelte';
import { page } from '@inertiajs/svelte';

describe('Layout Component', () => {
  it('renders main layout structure', () => {
    const { container } = render(Layout);

    // Should have main wrapper
    const main = container.querySelector('main');
    expect(main).toBeInTheDocument();

    // Should have wrapper div
    const wrapper = container.querySelector('.bg-bg');
    expect(wrapper).toBeInTheDocument();
  });

  it('includes navbar component', () => {
    const { container } = render(Layout);

    // Navbar should be present (navbar renders navigation role)
    const navbar = container.querySelector('nav');
    expect(navbar).toBeInTheDocument();
  });

  it('has proper DOM structure', () => {
    const { container } = render(Layout);

    // Should have wrapper div
    const wrapper = container.querySelector('.bg-bg');
    expect(wrapper).toBeInTheDocument();

    // Should have navbar inside wrapper
    const navbar = wrapper.querySelector('nav');
    expect(navbar).toBeInTheDocument();

    // Should have main inside wrapper
    const main = wrapper.querySelector('main');
    expect(main).toBeInTheDocument();
  });

  it('applies correct layout classes', () => {
    const { container } = render(Layout);

    const layoutDiv = container.querySelector('.bg-bg');
    expect(layoutDiv).toBeInTheDocument();
  });

  it('has proper content wrapper structure', () => {
    const { container } = render(Layout);

    const main = container.querySelector('main');
    expect(main).toBeInTheDocument();
  });

  it('renders without errors', () => {
    const { container } = render(Layout);

    // Navbar should be present
    const navbar = container.querySelector('nav');
    expect(navbar).toBeInTheDocument();

    // Main should be present
    const main = container.querySelector('main');
    expect(main).toBeInTheDocument();
  });

  it('includes required layout components', () => {
    const { container } = render(Layout);

    // Should have the main structure without errors
    const wrapper = container.querySelector('.bg-bg');
    expect(wrapper).toBeInTheDocument();
  });
});
