# Documentation Overview

This directory contains detailed documentation for the Helix Kit Rails application. Start here to understand the project structure and find the information you need.

## Quick Start

1. **Development Setup**: Run `bin/dev` to start the development server (Rails on port 3000, Vite for frontend assets)
2. **Database Setup**: Run `rails db:setup` to create and seed the database
3. **Run Tests**: Use `rails test`, `npm test`, and `npm run test:unit` to run the test suite before declaring changes complete.

## Documentation Index

### Core Documentation

- **[Architecture](./architecture.md)** - Application architecture, technology stack, and design patterns
- **[File System Structure](./file_system_structure.md)** - Complete directory structure and file organization for Rails and Svelte
- **[Testing](./testing.md)** - Testing strategy, frameworks, and best practices
- **[Commands](./commands.md)** - Complete list of development, testing, and deployment commands

### Feature Documentation

- **[Authentication](./authentication.md)** - User authentication system details
- **[Frontend](./frontend.md)** - Svelte, Inertia.js, and component organization
- **[Database](./database.md)** - PostgreSQL setup and Solid adapters configuration
- **[Icons](./icons.md)** - Comprehensive Phosphor Icons reference with 1500+ searchable icons

### Tech Stack Documentation

Important: those are summarise of the documentation with reference to a URL. When details of a specific feature are needed, use the fetcher sub-agent to fetch the entire documentation, 

- **[Inertia Rails](./stack/inertia-rails.md)** - Summary of Inertia.js Rails adapter capabilities and features
- **[Svelte 5](./stack/svelte-5.md)** - Summary of Svelte 5 capabilities and features

## Project Overview

Helix Kit is a Rails 8 starter template that combines:
- **Backend**: Ruby on Rails 8 with PostgreSQL
- **Frontend**: Svelte 5 with Inertia.js for SPA-like experience
- **Styling**: Tailwind CSS with DaisyUI and ShadcnUI components
- **Authentication**: Built-in Rails 8 authentication system
- **Build Tools**: Vite for fast frontend builds

## Key Directories

See **[File System Structure](./file_system_structure.md)** for complete directory layout and organization.

## Getting Help

- Check the specific documentation files for detailed information
- Review the README.md for installation instructions
- Look at existing code patterns in the codebase for examples

## Playwright Testing

Separate from the Playwright Component Testing described in `docs/testing.md`, there is also a Playwright MCP server installed that should be used to test changes in a real browser before telling the user the change is complete.

See `docs/playwright-testing.md` for more information.