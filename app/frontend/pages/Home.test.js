import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Home from './Home.svelte';

describe('Home Page Component', () => {
  it('renders main heading', () => {
    render(Home);
    
    const heading = screen.getByRole('heading', { level: 1 });
    expect(heading).toBeInTheDocument();
    expect(heading).toHaveTextContent('HelixKit: Svelte App Kit for Ruby on Rails');
  });

  it('renders description text', () => {
    render(Home);
    
    expect(screen.getByText(/A start app kit template analogous to/)).toBeInTheDocument();
  });

  it('renders features done section', () => {
    render(Home);
    
    // Check for completed features section
    expect(screen.getByText('Features (Done)')).toBeInTheDocument();
    expect(screen.getByText('Svelte 5')).toBeInTheDocument();
    expect(screen.getByText('Ruby on Rails')).toBeInTheDocument();
    expect(screen.getByText('Inertia.js')).toBeInTheDocument();
    expect(screen.getByText('Tailwind CSS')).toBeInTheDocument();
  });

  it('renders todo features section', () => {
    render(Home);
    
    // Check for todo features section
    expect(screen.getByText('Target Features (Todo)')).toBeInTheDocument();
    expect(screen.getByText('Testing')).toBeInTheDocument();
    expect(screen.getByText('Full-featured user system')).toBeInTheDocument();
  });

  it('renders github link', () => {
    render(Home);
    
    const githubLink = screen.getByRole('link', { name: /github repo/i });
    expect(githubLink).toBeInTheDocument();
    expect(githubLink).toHaveAttribute('href', 'https://github.com/swombat/helix_kit');
  });

  it('has proper page structure', () => {
    const { container } = render(Home);
    
    // Check for main layout structure
    const backgroundSection = container.querySelector('.bg-muted');
    expect(backgroundSection).toBeInTheDocument();
  });

  it('renders feature cards with proper links', () => {
    render(Home);
    
    // Check for external links
    const links = screen.getAllByRole('link');
    expect(links.length).toBeGreaterThan(0);
    
    // Check for multiple "See more" links
    const seeMoreLinks = screen.getAllByRole('link', { name: /see more/i });
    expect(seeMoreLinks.length).toBeGreaterThan(0);
  });

  it('includes proper page title', () => {
    render(Home);
    
    // Check that svelte:head title is set
    expect(document.title).toBe('Home');
  });
});