import { render, fireEvent, screen } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import Navbar from './Navbar.svelte';
import { page, router } from '@inertiajs/svelte';

describe('Navbar Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders navbar with logo', () => {
    render(Navbar);

    const navbar = screen.getByRole('navigation');
    expect(navbar).toBeInTheDocument();

    // Logo should be present
    const logo = navbar.querySelector('svg');
    expect(logo).toBeInTheDocument();
  });

  it('renders HelixKit brand link', () => {
    render(Navbar);

    const brandLink = screen.getByText('HelixKit');
    expect(brandLink).toBeInTheDocument();
    expect(brandLink.closest('a')).toHaveAttribute('href', '/');
  });

  it('renders brand name', () => {
    render(Navbar);

    const brandName = screen.getByText('HelixKit');
    expect(brandName).toBeInTheDocument();
  });

  it('has proper navigation structure', () => {
    render(Navbar);

    const navbar = screen.getByRole('navigation');
    expect(navbar).toBeInTheDocument();

    // Should have the main flex container
    const container = navbar.querySelector('.flex.items-center.justify-between');
    expect(container).toBeInTheDocument();
  });

  it('renders theme toggle button', () => {
    render(Navbar);

    // Should have theme toggle functionality
    const themeButton = screen.getByRole('button', { name: /toggle theme/i });
    expect(themeButton).toBeInTheDocument();
  });

  it('renders dropdown trigger buttons', () => {
    render(Navbar);

    // Should have dropdown buttons (theme and user/auth menu)
    const buttons = screen.getAllByRole('button');
    expect(buttons.length).toBeGreaterThan(0);
  });

  it('renders About navigation link', () => {
    render(Navbar);

    const aboutLink = screen.getByText('About');
    expect(aboutLink).toBeInTheDocument();
  });

  it('has responsive navigation classes', () => {
    render(Navbar);

    const navbar = screen.getByRole('navigation');
    expect(navbar).toBeInTheDocument();

    // Check for responsive layout elements
    const hiddenMdFlex = navbar.querySelector('.hidden.md\\:flex');
    expect(hiddenMdFlex).toBeInTheDocument();
  });
});
