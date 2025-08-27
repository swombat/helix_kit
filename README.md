# Svelte Starter Template for Ruby on Rails

This is a starter template for Rails developers who want to integrate Svelte into their applications without setting everything up from scratch. It provides a structured foundation with essential tools and libraries for building modern, reactive UIs within a Rails ecosystem.

![localhost_3100_login (1)](https://github.com/user-attachments/assets/e3d98e5c-6e4b-4d64-a5d3-e31209459f07)



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

## Installation

1. Use this repository as a template.
2. Clone your new repository:
   ```sh
   git clone git@github.com:georgekettle/rails_svelte.git <your-repo-name>
   cd <your-repo-name>
   ```
3. Install dependencies:
   ```sh
   bundle install
   npm install
   ```
4. Setup the database:
   ```sh
   rails db:setup
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

