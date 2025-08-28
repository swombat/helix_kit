import { defineConfig, devices } from '@playwright/experimental-ct-svelte';

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
          '$lib': 'app/frontend/lib',
          '@': 'app/frontend',
          '@/routes': 'playwright/mock-routes.js',
          '@inertiajs/svelte': 'playwright/mock-inertia.js',
        },
      },
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