# Svelte App Kit for Ruby on Rails

This is a start app kit template analogous to Jumpstart Pro or BulletTrain, but using Svelte and Inertia.js for the frontend, with Ruby on Rails as the backend, and including a number of other useful libraries and tools.

## Features

- **[Svelte](https://svelte.dev/)** - A modern JavaScript framework for building user interfaces.
- **[Ruby on Rails](https://rubyonrails.org/)** - A powerful web application framework for building server-side applications.
- **[Inertia.js](https://inertiajs.com/)** - Enables single-page applications using classic Rails routing and controllers.
- **[ShadcnUI](https://ui.shadcn.com/)** - A collection of UI components for Svelte.
- **[Tailwind CSS](https://tailwindcss.com/)** - A utility-first CSS framework for building custom designs.
- **[Phosphor Icons](https://phosphoricons.com/)** - A versatile icon library for user interfaces.
- **[JS Routes](https://github.com/railsware/js-routes)** - A library for generating JavaScript routes in Rails applications.
- **Rails Authentication** - Built-in authentication using the default Rails 8 authentication system.
- **[Vite](https://vitejs.dev/)** - A fast and modern frontend bundler.
- **[PostgreSQL](https://www.postgresql.org/)** - A powerful, open-source relational database system.
- **[DaisyUI](https://daisyui.com/)** - A plugin for Tailwind CSS that provides a set of pre-designed components, for rapid prototyping of components not covered by ShadcnUI.

## Target features (TODO)

- **[SolidQueue/Cable/Cache](https://medium.com/@reinteractivehq/rails-8-solid-trifecta-comparison-44a76cb92ac3)** - Set up in development environment, for background jobs, real-time features, and caching.
- **[Obfuscated IDs](https://github.com/bullet-train-co/bullet_train-core)** - For better security and aesthetics in URLs. Copy implementation from BulletTrain.
- **[Full-featured user system](https://jumpstartrails.com/docs/accounts)** - Necessary for most commercial applications, but not included in the default user setup.
    - Site Admin
    - User Profiles
    - Personal/Organization Accounts
    - Invitations
    - Roles
- **Svelte Object Synchronization** - Using ActionCable and Inertia's partial reload and a custom Regitry to keep Svelte $props up to date in real-time.
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
   rails db:setup db:prepare
   ```
5. Start the development server:
   ```sh
   bin/dev
   ```
6. Open in browser at localhost:3100

## Usage

This template integrates Svelte with Rails using Inertia.js to manage front-end routing while keeping Rails' backend structure. It uses Vite for asset bundling, and all frontend code is located in the `app/frontend` directory. Place assets such as images and fonts inside the `app/frontend/assets` folder.

## Contributing

Feel free to fork this repository and submit pull requests with improvements, fixes, or additional features.

## License

This project is open-source and available under the [MIT License](LICENSE).

