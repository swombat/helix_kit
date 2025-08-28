import { defineConfig, devices } from '@playwright/experimental-ct-svelte';
import { resolve } from 'path';
import { fileURLToPath } from 'url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

export default defineConfig({
  testDir: './playwright/tests',
  testMatch: '**/*.pw.{js,jsx,ts,tsx}',

  // Shared settings for all projects
  use: {
    // Base URL for your Rails app
    baseURL: 'http://localhost:3200',

    // Capture traces for failed tests
    trace: 'on-first-retry',

    // Screenshots on failure
    screenshot: 'only-on-failure',

    // Video on failure  
    video: 'retain-on-failure',

    // Component testing specific options
    ctPort: 3101,  // Changed from 3100 to avoid conflict with Rails test server
    ctViteConfig: {
      resolve: {
        alias: {
          '$lib': resolve(__dirname, 'app/frontend/lib'),
          '@': resolve(__dirname, 'app/frontend'),
          '@/routes': resolve(__dirname, 'playwright/mock-routes.js'),
          '@inertiajs/svelte': resolve(__dirname, 'playwright/mock-inertia.js'),
        },
      },
      server: {
        proxy: {
          '/login': 'http://localhost:3200',
          '/signup': 'http://localhost:3200', 
          '/logout': 'http://localhost:3200',
          '/passwords': 'http://localhost:3200',
          '/password': 'http://localhost:3200',
          '/session': 'http://localhost:3200',
        }
      }
    },
  },

  // Configure projects for cross-browser testing
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // Folder for test artifacts
  outputDir: 'test-results/',

  // Reporter configuration
  reporter: [
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['list'],
  ],

  // Run tests in parallel
  fullyParallel: true,

  // Retry failed tests
  retries: process.env.CI ? 2 : 0,

  // Limit workers on CI
  workers: process.env.CI ? 1 : undefined,
});