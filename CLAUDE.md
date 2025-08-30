# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Information

This is a Rails 8 + Svelte 5 application using Inertia.js. **Always check the `/docs/` folder for detailed documentation before making changes.**

## Quick Start

```bash
bin/dev          # Start development server (Rails + Vite)
rails db:setup   # Setup database
rails test       # Run tests
```

## Documentation Structure

📁 **`/docs/` - All detailed documentation lives here**

Start with **[/docs/overview.md](/docs/overview.md)** which indexes all documentation:

- **[Architecture](/docs/architecture.md)** - Application structure, patterns, and technology stack
- **[Testing](/docs/testing.md)** - Testing strategy and how to write/run tests  
- **[Commands](/docs/commands.md)** - Complete development command reference

## Critical Information

### When Creating New Features
1. Check `/docs/architecture.md` for patterns and structure
2. Follow existing code conventions in similar files
3. Run tests after changes: `rails test`
4. Check linting: `bin/rubocop`
5. Test features using the Playwright MCP

### Technology Stack
- **Backend**: Rails 8 with PostgreSQL
- **Frontend**: Svelte 5 with Inertia.js
- **Styling**: Tailwind CSS + DaisyUI + ShadcnUI
- **Build**: Vite

### Key Directories
- `/app/frontend/` - Svelte components and frontend code
- `/app/controllers/` - Rails controllers (render Inertia components)
- `/config/routes.rb` - Application routes
- `/docs/` - Detailed documentation

## Always Remember

1. **Read the docs first** - Check `/docs/` before implementing
2. **Follow patterns** - Look at existing code for conventions
3. **Test your changes** - Run `rails test` after modifications
4. **Security matters** - Never commit secrets, use credentials