import { createInertiaApp } from '@inertiajs/svelte';
import { router } from '@inertiajs/core';
import { mount } from 'svelte';
import Layout from '../layouts/Layout.svelte';
import * as logging from '$lib/logging';

// Configure CSRF token for all Inertia requests
// This is the correct way to handle CSRF tokens with Inertia.js and Rails
router.defaults = {
  headers: {
    'X-CSRF-Token': () => {
      const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
      return token || '';
    },
  },
};

createInertiaApp({
  // Set default page title
  // see https://inertia-rails.dev/guide/title-and-meta
  //
  // title: title => title ? `${title} - App` : 'App',

  // Disable progress bar
  //
  // see https://inertia-rails.dev/guide/progress-indicators
  // progress: false,

  resolve: (name) => {
    const pages = import.meta.glob('../pages/**/*.svelte', {
      eager: true,
    });
    const page = pages[`../pages/${name}.svelte`];
    if (!page) {
      logging.error(`Missing Inertia page component: '${name}.svelte'`);
    }

    // To use a default layout, import the Layout component
    // and use the following line.
    // see https://inertia-rails.dev/guide/pages#default-layouts
    //
    return { default: page.default, layout: page.layout || Layout };
  },

  setup({ el, App, props }) {
    if (el) {
      mount(App, { target: el, props });
    } else {
      logging.error(
        'Missing root element.\n\n' +
          'If you see this error, it probably means you load Inertia.js on non-Inertia pages.\n' +
          'Consider moving <%= vite_javascript_tag "inertia" %> to the Inertia-specific layout instead.'
      );
    }
  },
});
