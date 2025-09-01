# Svelte App Kit for Ruby on Rails

<div align="center">
  <img src="app/assets/images/helix-kit-logo.svg" alt="Helix Kit Logo" width="100" height="100">
</div>

This is a start app kit template analogous to Jumpstart Pro or BulletTrain, but using Svelte and Inertia.js for the frontend, with Ruby on Rails as the backend, and including a number of other useful libraries and tools.

## Features

- **[Svelte 5](https://svelte.dev/)** - A modern JavaScript framework for building user interfaces.
- **[Ruby on Rails](https://rubyonrails.org/)** - A powerful web application framework for building server-side applications.
- **[Inertia.js Rails](https://inertia-rails.dev/)** - Enables single-page applications using classic Rails routing and controllers.
- **[ShadcnUI](https://ui.shadcn.com/)** - A collection of UI components for Svelte.
- **[Tailwind CSS](https://tailwindcss.com/)** - A utility-first CSS framework for building custom designs.
- **[Phosphor Icons](https://phosphoricons.com/)** - A versatile icon library for user interfaces.
- **[JS Routes](https://github.com/railsware/js-routes)** - A library for generating JavaScript routes in Rails applications.
- **Rails Authentication** - Built-in authentication using the default Rails 8 authentication system.
- **[Vite](https://vitejs.dev/)** - A fast and modern frontend bundler.
- **[PostgreSQL](https://www.postgresql.org/)** - A powerful, open-source relational database system.
- **[DaisyUI](https://daisyui.com/)** - A plugin for Tailwind CSS that provides a set of pre-designed components, for rapid prototyping of components not covered by ShadcnUI.
- **[Claude Code Ready](https://www.anthropic.com/news/claude-code)** - Clear documentation in `/docs/` to enable Claude Code to perform at its best.
- **[SolidQueue/Cable/Cache](https://medium.com/@reinteractivehq/rails-8-solid-trifecta-comparison-44a76cb92ac3)** - Set up in development environment, for background jobs, real-time features, and caching.
- **[Obfuscated IDs](https://github.com/bullet-train-co/bullet_train-core/blob/3c12343eba5745dbe0f02db4cb8fb588e4a091e7/bullet_train-obfuscates_id/app/models/concerns/obfuscates_id.rb)** - For better security and aesthetics in URLs. Copy implementation from BulletTrain.
- **Testing** - Full test suite setup with [Playwright Component Testing](https://testomat.io/blog/playwright-component-testing-as-modern-alternative-to-traditional-tools/) for page testing, [Vitest](https://vitest.dev/) for Svelte component unit testing, [Minitest](https://guides.rubyonrails.org/testing.html) for Rails model and controller testing.
- **[Full-featured user system](https://jumpstartrails.com/docs/accounts)** - Necessary for most commercial applications, but not included in the default user setup.
    - [x] User signup and confirmation
    - [x] Personal/Organization Accounts
    - [x] Site Admin
    - [x] User Profiles
    - [x] Invitations
    - [x] Roles
- **Svelte Object Synchronization** - Using ActionCable and Inertia's partial reload and a custom Regitry to keep Svelte $props up to date in real-time.

## Target features (TODO)

- Audit Logging with audit log viewer (required in many business applications).
- MultiAttachment system supporting:
    - Direct uploads to S3
    - PDF/Document parsing
    - URL fetch
    - Free text
- AI Integration features:
    - OpenRouter integration
    - Prompt system
    - Basic Conversation System
    - Agentic Conversation System
- Organisation account settings:
    - Logo
    - Company Name
- All account settings:
    - Billing
- API capability:
    - API key management
    - API key usage tracking
    - API key rate limiting
    - API key billing
    - API key audit logging
    - API documentation

## Explicitly out of scope

- Internationalization (i18n)

## Installation

1. Click "Use this template" to create a new repository from this template.
2. Clone your new repository:
   ```sh
   git clone https://github.com/<youruser>/<your_repo>
   cd <your-repo>
   ```
3. Install dependencies:
   ```sh
   bundle install
   npm install
   ```
4. Setup the database:
   ```sh
   rails db:create:all
   rails db:setup db:prepare
   rails db:migrate:cache db:migrate:queue db:migrate:cable
   rails db:schema:dump:cable db:schema:dump:cache db:schema:dump:queue
   ```
   Check that the solid* databases have been created by checking `db/cable_schema.rb`, `db/cache_schema.rb`, and `db/queue_schema.rb` and seeing that they contain a comment at the top about auto-generation.
5. Start the development server:
   ```sh
   bin/dev
   ```
6. Open in browser at localhost:3100

### Optional: Claude setup

Necessary for Claude Code to be full featured.

```sh
claude mcp add --scope=local playwright npx @executeautomation/playwright-mcp-server
claude mcp add --scope=local snap-happy npx @mariozechner/snap-happy
```

## Usage

This template integrates Svelte with Rails using Inertia.js to manage front-end routing while keeping Rails' backend structure. It uses Vite for asset bundling, and all frontend code is located in the `app/frontend` directory. Place assets such as images and fonts inside the `app/frontend/assets` folder.

## Contributing

Feel free to fork this repository and submit pull requests with improvements, fixes, or additional features.

## Documentation

### Real-time Synchronization System

This application includes a powerful real-time synchronization system that automatically updates Svelte components when Rails models change, using ActionCable and Inertia.js partial reloads.

#### How It Works

1. Rails models broadcast minimal "marker" messages when they change
2. Svelte components subscribe to these broadcasts via ActionCable
3. When a broadcast is received, Inertia performs a partial reload of just the affected props
4. Updates are debounced (300ms) to handle multiple rapid changes efficiently

#### Key Files

**Rails Side:**
- [`app/channels/sync_channel.rb`](https://github.com/danieltenner/helix_kit/blob/master/app/channels/sync_channel.rb) - ActionCable channel with authorization
- [`app/models/concerns/broadcastable.rb`](https://github.com/danieltenner/helix_kit/blob/master/app/models/concerns/broadcastable.rb) - Model concern for automatic broadcasting
- [`app/models/concerns/sync_authorizable.rb`](https://github.com/danieltenner/helix_kit/blob/master/app/models/concerns/sync_authorizable.rb) - Authorization logic for sync access
- [`app/channels/application_cable/connection.rb`](https://github.com/danieltenner/helix_kit/blob/master/app/channels/application_cable/connection.rb) - WebSocket authentication

**JavaScript/Svelte Side:**
- [`app/frontend/lib/cable.js`](https://github.com/danieltenner/helix_kit/blob/master/app/frontend/lib/cable.js) - Core ActionCable subscription management
- [`app/frontend/lib/use-sync.js`](https://github.com/danieltenner/helix_kit/blob/master/app/frontend/lib/use-sync.js) - Svelte hook for easy integration

#### Usage Example

**1. Add to your Rails model:**
```ruby
class Account < ApplicationRecord
  include SyncAuthorizable
  include Broadcastable
  
  # Configure what to broadcast
  broadcasts_to :all # Broadcast to admin collection
  
  # IMPORTANT: broadcasts_refresh_prop tells the system which Inertia prop name to reload
  # These should match the prop names used in your controller's render inertia call
  
  # When this specific account changes, reload the 'account' prop
  broadcasts_refresh_prop :account
  
  # When any account changes (for :all broadcasts), reload the 'accounts' prop
  broadcasts_refresh_prop :accounts, collection: true
end
```

**Understanding `broadcasts_refresh_prop`:**
- This configures which Inertia.js prop should be reloaded when a model changes
- The prop name must match exactly what your Rails controller uses in `render inertia:`
- Use `collection: true` for props that represent arrays/collections
- Without this, the system defaults to the model's underscored name (e.g., 'account' for Account model)

**2. Use in your Svelte component:**

For static subscriptions:
```svelte
<script>
  import { useSync } from '$lib/use-sync';
  
  let { accounts = [] } = $props();
  
  // Simple static subscriptions
  useSync({
    'Account:all': 'accounts',  // Updates when any account changes
  });
</script>
```

For dynamic subscriptions (when the subscribed objects can change):
```svelte
<script>
  import { createDynamicSync } from '$lib/use-sync';
  
  let { accounts = [], selected_account = null } = $props();
  
  // Create dynamic sync handler
  const updateSync = createDynamicSync();
  
  // Update subscriptions when selected_account changes
  $effect(() => {
    const subs = { 'Account:all': 'accounts' };
    if (selected_account) {
      subs[`Account:${selected_account.id}`] = 'selected_account';
    }
    updateSync(subs);
  });
</script>
```

That's it! Your component will now automatically update when the data changes on the server.

#### Complete Example: Controller + Model + Component

Here's how all the pieces work together:

**Rails Controller:**
```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    render inertia: "Dashboard", props: {
      current_user: current_user.as_json,     # Creates 'current_user' prop
      notifications: current_user.notifications, # Creates 'notifications' prop
      stats: calculate_stats                  # Creates 'stats' prop
    }
  end
end
```

**Rails Model:**
```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  include Broadcastable
  belongs_to :user
  
  # Tell the system which props to reload when notifications change
  broadcasts_refresh_prop :notifications  # Matches controller's 'notifications' prop
  broadcasts_to parent: :user  # Also broadcast to parent user
end
```

**Svelte Component:**
```svelte
<script>
  import { useSync } from '$lib/use-sync';
  
  // These prop names match what the controller sends
  let { current_user, notifications, stats } = $props();
  
  // Subscribe to updates - the second value is the prop name to reload
  useSync({
    [`User:${current_user.id}`]: 'current_user',
    [`Notification:all`]: 'notifications'  // Will reload when any notification changes
  });
</script>
```

The key insight: `broadcasts_refresh_prop :notifications` tells the system to reload the 'notifications' prop (from your controller) whenever a Notification model changes.

#### Authorization Model

- Objects with an `account` property: Accessible by all users in that account
- Objects without an `account` property: Admin-only access
- Site admins can subscribe to `:all` collections for any model

#### Testing

Run the synchronization tests:
```sh
rails test test/channels/sync_channel_test.rb
rails test test/models/concerns/broadcastable_test.rb
```

See the [in-app documentation](/documentation) for more detailed information and advanced usage.

## License

This project is open-source and available under the [MIT License](LICENSE).

