# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 8 application using Svelte 5 and Inertia.js for the frontend, with PostgreSQL as the database. It serves as a starter template for building modern web applications with authentication built-in.

## Development Commands

### Starting the Development Server
```bash
bin/dev
```
This runs both the Rails server (port 3000) and Vite dev server concurrently.

### Database Management
```bash
rails db:create    # Create development and test databases
rails db:migrate   # Run pending migrations
rails db:seed      # Load seed data
rails db:setup     # Create, migrate, and seed databases
rails db:prepare   # Setup database (creates if necessary, migrates, and seeds)
```

### Testing
```bash
rails test              # Run all tests except system tests
rails test:db           # Reset database and run tests
rails test test/models  # Run specific test directory
```

### Code Quality
```bash
bin/rubocop            # Run Ruby linting
bin/rubocop -A         # Auto-fix linting issues where possible
bin/brakeman           # Security vulnerability scanning
```

### Dependency Management
```bash
bundle install         # Install Ruby gems
npm install           # Install JavaScript packages
```

## Architecture

### Frontend Structure
- **app/frontend/**: All frontend code using Svelte 5
  - **entrypoints/**: Entry points for Vite (application.js, inertia.js, application.css)
  - **pages/**: Svelte page components corresponding to Rails routes
  - **layouts/**: Shared layout components (auth-layout, main layout)
  - **lib/components/**: Reusable UI components including ShadcnUI components
  - **lib/stores/**: Svelte stores for state management
  - **routes/**: JS Routes generated from Rails routes

### Backend Structure
- **Controllers**: Using Inertia.js pattern - controllers render Svelte components instead of ERB views
  - Authentication controllers: sessions, registrations, passwords
  - All controllers inherit from ApplicationController with Authentication concern
- **Models**: 
  - User model with has_secure_password
  - Session model for authentication tracking
- **Database**: PostgreSQL with Solid adapters for cache, queue, and cable

### Key Technologies Integration
- **Inertia.js**: Bridges Rails backend with Svelte frontend, handling routing and data passing
- **Vite**: Fast build tool for frontend assets
- **Tailwind CSS + DaisyUI**: Utility-first CSS with pre-built components
- **ShadcnUI**: Component library integrated with Tailwind
- **JS Routes**: Generates JavaScript route helpers from Rails routes

### Authentication System
Built-in Rails 8 authentication using bcrypt:
- User registration at `/signup`
- Login/logout at `/login` and `/logout`
- Password reset functionality
- Session-based authentication with secure cookies

## Important Patterns

### Creating New Pages
1. Add route in `config/routes.rb`
2. Create controller action that renders Inertia component
3. Create Svelte component in `app/frontend/pages/`
4. Use `inertia_location` instead of `redirect_to` for redirects

### Using Inertia Props
Controllers pass data to Svelte components via props:
```ruby
render inertia: 'PageName', props: { data: @data }
```

### Component Organization
- Place reusable UI components in `app/frontend/lib/components/`
- Use ShadcnUI components from `app/frontend/lib/components/ui/`
- Keep page-specific components within page files or nearby

### State Management
- Use Svelte stores in `app/frontend/lib/stores/` for shared state
- Theme persistence is already implemented as an example

## Security Considerations
- CSRF protection enabled by default
- Authentication required via `authenticate` before_action
- Parameter filtering configured for passwords and tokens
- Brakeman available for security scanning