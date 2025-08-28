import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { svelteTesting } from '@testing-library/svelte/vite';
import path from 'path';

export default defineConfig({
  plugins: [
    svelte(),
    svelteTesting()
  ],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./app/frontend/test/setup.js'],
    include: ['app/frontend/**/*.{test,spec}.{js,mjs}'],
    alias: {
      $lib: path.resolve('./app/frontend/lib'),
      '@': path.resolve('./app/frontend'),
      '@inertiajs/svelte': path.resolve('./app/frontend/test/__mocks__/@inertiajs/svelte.js'),
    },
  },
  resolve: {
    conditions: ['browser'],
    alias: {
      $lib: path.resolve('./app/frontend/lib'),
      '@': path.resolve('./app/frontend'),
    },
  },
});