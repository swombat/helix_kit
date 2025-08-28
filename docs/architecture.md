# Architecture Documentation

## Technology Stack

### Backend
- **Ruby on Rails 8.0.2** - Web application framework
- **PostgreSQL** - Primary database
- **Solid Adapters** - Rails 8's new approach for cache, queue, and cable
  - `solid_cache` - Database-backed caching
  - `solid_queue` - Database-backed job queue
  - `solid_cable` - Database-backed ActionCable

### Frontend
- **Svelte 5** - Reactive UI framework with runes
- **Inertia.js** - Connects Rails backend with Svelte frontend
- **Vite** - Fast build tool and dev server
- **Tailwind CSS 4** - Utility-first CSS framework
- **DaisyUI** - Component library for Tailwind
- **ShadcnUI** - Customizable component library

## Application Architecture

### Request Flow
1. Browser makes request to Rails server
2. Rails controller processes request
3. Controller renders Inertia response with Svelte component name and props
4. Inertia client-side router loads the Svelte component
5. Svelte component renders with provided props

### Directory Structure

```
helix_kit/
├── app/
│   ├── frontend/           # All frontend code
│   │   ├── entrypoints/   # Vite entry points
│   │   │   ├── application.js    # Main JS entry
│   │   │   ├── inertia.js        # Inertia setup
│   │   │   └── application.css   # Tailwind CSS
│   │   ├── pages/         # Page components (mapped to routes)
│   │   ├── layouts/       # Layout components
│   │   ├── lib/          
│   │   │   ├── components/       # Reusable UI components
│   │   │   │   └── ui/          # ShadcnUI components
│   │   │   ├── stores/          # Svelte stores
│   │   │   └── utils.js        # Utility functions
│   │   └── routes/        # JS Routes integration
│   ├── controllers/       # Rails controllers
│   │   └── concerns/      # Controller mixins
│   ├── models/           # ActiveRecord models
│   ├── mailers/          # Email functionality
│   └── views/            # Minimal ERB views (mostly for emails)
├── config/               # Rails configuration
├── db/                   # Database migrations and schema
├── public/               # Static files
└── test/                 # Test files
```

## Key Design Patterns

### Inertia.js Integration

Controllers use Inertia to render Svelte components:

```ruby
class PagesController < ApplicationController
  def home
    render inertia: 'Home', props: {
      user: current_user&.slice(:id, :email, :name)
    }
  end
end
```

Redirects use `inertia_location`:
```ruby
inertia_location(root_path)
```

### Component Organization

1. **Page Components** (`app/frontend/pages/`)
   - One component per controller action
   - Named to match the controller/action pattern
   - Receive props from Rails controller

2. **Layout Components** (`app/frontend/layouts/`)
   - `layout.svelte` - Main application layout
   - `auth-layout.svelte` - Authentication pages layout

3. **Reusable Components** (`app/frontend/lib/components/`)
   - Shared UI components used across pages
   - ShadcnUI components in `ui/` subdirectory
   - Custom business components at root level

### State Management

1. **Component State** - Use Svelte 5 runes (`$state`, `$derived`)
2. **Shared State** - Svelte stores in `app/frontend/lib/stores/`
3. **Server State** - Props passed from Rails controllers
4. **Persistent State** - localStorage (see theme store example)

### Authentication Architecture

- Session-based authentication using Rails 8 built-in auth
- `Authentication` concern included in `ApplicationController`
- Session cookies for maintaining logged-in state
- BCrypt for password hashing
- Password reset via email tokens

### Database Architecture

- PostgreSQL as primary database
- Solid adapters use separate schemas for isolation:
  - `cable_schema.rb` - ActionCable connections
  - `cache_schema.rb` - Cache entries
  - `queue_schema.rb` - Background jobs
  - `schema.rb` - Main application schema

### Frontend Build Pipeline

1. **Development**
   - Vite dev server provides HMR (Hot Module Replacement)
   - Rails serves on port 3000, Vite on configured port
   - `bin/dev` starts both servers via Procfile.dev

2. **Production**
   - Vite builds optimized bundles
   - Assets served by Rails with fingerprinting
   - Configured in `vite.json` and `vite.config.ts`

## Security Considerations

### Built-in Protections
- CSRF protection enabled by default
- Secure session cookies
- Parameter filtering for sensitive data
- Content Security Policy configured
- SQL injection protection via ActiveRecord

### Authentication Security
- BCrypt password hashing
- Session tokens with expiration
- Password reset tokens expire
- Secure cookie flags in production

## Performance Optimizations

### Frontend
- Vite code splitting for optimal bundle sizes
- Svelte's compiled output is highly optimized
- Tailwind CSS purging unused styles
- Lazy loading of page components via Inertia

### Backend
- Database-backed caching with solid_cache
- Background job processing with solid_queue
- Efficient database queries with includes/joins
- PostgreSQL query optimization

## Extension Points

### Adding New Features
1. Create route in `config/routes.rb`
2. Add controller action with Inertia render
3. Create Svelte page component
4. Add any shared components to lib/components
5. Update navigation if needed

### Adding New UI Components
1. Check if ShadcnUI has the component
2. If not, create in `app/frontend/lib/components/`
3. Use Tailwind classes for styling
4. Consider DaisyUI for rapid prototyping

### Adding Background Jobs
1. Create job class in `app/jobs/`
2. Solid Queue will handle execution
3. Monitor via Rails console or future admin UI

### Adding Real-time Features
1. Create ActionCable channel
2. Solid Cable handles connections
3. Update Svelte components to subscribe
4. Consider using stores for real-time state