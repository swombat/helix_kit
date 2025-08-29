import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import Home from './Home.svelte';

describe('Home Page Component', () => {
  it('renders main heading', () => {
    render(Home);
    
    const heading = screen.getByRole('heading', { level: 1 });
    expect(heading).toBeInTheDocument();
  });

  it('has multiple headings for sections', () => {
    render(Home);
    
    // Should have multiple section headings
    const headings = screen.getAllByRole('heading');
    expect(headings.length).toBeGreaterThan(1);
  });

  it('renders feature sections with links', () => {
    render(Home);
    
    // Should have multiple links to documentation/features
    const links = screen.getAllByRole('link');
    expect(links.length).toBeGreaterThan(0);
  });

  it('renders multiple sections with content', () => {
    const { container } = render(Home);
    
    // Should have multiple sections with cards or content areas
    const sections = container.querySelectorAll('section, [class*="card"], [class*="grid"]');
    expect(sections.length).toBeGreaterThan(0);
  });

  it('includes external links', () => {
    render(Home);
    
    // Should have at least one external link
    const externalLinks = screen.getAllByRole('link').filter(link => 
      link.getAttribute('href')?.startsWith('http')
    );
    expect(externalLinks.length).toBeGreaterThan(0);
  });

  it('has proper page structure', () => {
    const { container } = render(Home);
    
    // Check for main layout structure
    const backgroundSection = container.querySelector('.bg-muted');
    expect(backgroundSection).toBeInTheDocument();
  });

  it('renders multiple clickable links', () => {
    render(Home);
    
    // Check that there are multiple links
    const links = screen.getAllByRole('link');
    expect(links.length).toBeGreaterThan(3);
  });

  it('includes proper page title', () => {
    render(Home);
    
    // Check that svelte:head title is set
    expect(document.title).toBe('Home');
  });
});