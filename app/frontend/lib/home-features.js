import {
  Atom,
  Train,
  Lightning,
  Palette,
  Wind,
  Sparkle,
  Path,
  ShieldCheck,
  Rocket,
  Database,
  PaintBrush,
  Robot,
  Stack,
  LockKey,
  TestTube,
  Users,
  ArrowsClockwise,
  FileText,
  Paperclip,
  Brain,
  Buildings,
  CreditCard,
  Plugs,
  Trash,
  Chats,
  CloudArrowUp,
} from 'phosphor-svelte';

export const completedFeatures = [
  {
    title: 'Svelte 5',
    description: 'A modern JavaScript framework for building user interfaces.',
    link: 'https://svelte.dev/',
    icon: Atom,
  },
  {
    title: 'Ruby on Rails',
    description: 'A powerful web application framework for building server-side applications.',
    link: 'https://rubyonrails.org/',
    icon: Train,
  },
  {
    title: 'Inertia.js Rails',
    description: 'Enables single-page applications using classic Rails routing and controllers.',
    link: 'https://inertia-rails.dev/',
    icon: Lightning,
  },
  {
    title: 'ShadcnUI',
    description: 'A collection of UI components for Svelte.',
    link: 'https://ui.shadcn.com/',
    icon: Palette,
  },
  {
    title: 'Tailwind CSS',
    description: 'A utility-first CSS framework for building custom designs.',
    link: 'https://tailwindcss.com/',
    icon: Wind,
  },
  {
    title: 'Phosphor Icons',
    description: 'A versatile icon library for user interfaces.',
    link: 'https://phosphoricons.com/',
    icon: Sparkle,
  },
  {
    title: 'JS Routes',
    description: 'A library for generating JavaScript routes in Rails applications.',
    link: 'https://github.com/railsware/js-routes',
    icon: Path,
  },
  {
    title: 'Rails Authentication',
    description: 'Built-in authentication using the default Rails 8 authentication system.',
    link: 'https://www.bigbinary.com/blog/rails-8-introduces-a-basic-authentication-generator',
    icon: ShieldCheck,
  },
  {
    title: 'Vite',
    description: 'A fast and modern frontend bundler.',
    link: 'https://vitejs.dev/',
    icon: Rocket,
  },
  {
    title: 'PostgreSQL',
    description: 'A powerful, open-source relational database system.',
    link: 'https://www.postgresql.org/',
    icon: Database,
  },
  {
    title: 'DaisyUI',
    description:
      'A plugin for Tailwind CSS that provides a set of pre-designed components, for rapid prototyping of components not covered by ShadcnUI.',
    link: 'https://daisyui.com/',
    icon: PaintBrush,
  },
  {
    title: 'Claude Code Ready',
    description: 'Clear documentation in /docs/ to enable Claude Code to perform at its best.',
    link: 'https://www.anthropic.com/news/claude-code',
    icon: Robot,
  },
  {
    title: 'SolidQueue/Cable/Cache',
    description: 'Set up in development environment, for background jobs, real-time features, and caching.',
    link: 'https://medium.com/@reinteractivehq/rails-8-solid-trifecta-comparison-44a76cb92ac3',
    icon: Stack,
  },
  {
    title: 'Obfuscated IDs',
    description: 'For better security and aesthetics in URLs. Copy implementation from BulletTrain.',
    link: 'https://github.com/bullet-train-co/bullet_train-core/blob/3c12343eba5745dbe0f02db4cb8fb588e4a091e7/bullet_train-obfuscates_id/app/models/concerns/obfuscates_id.rb',
    icon: LockKey,
  },
  {
    title: 'Testing',
    description:
      'Full test suite setup with Playwright Component Testing for page testing, Vitest for Svelte component unit testing, Minitest for Rails model and controller testing.',
    icon: TestTube,
  },
  {
    title: 'Full-featured user system',
    description:
      'Necessary for most commercial applications: Site Admin, User Profiles, Personal/Organization Accounts, Invitations, Roles.',
    link: 'https://jumpstartrails.com/docs/accounts',
    icon: Users,
  },
  {
    title: 'Svelte Object Synchronization',
    description:
      "Using ActionCable and Inertia's partial reload and a custom Registry to keep Svelte $props up to date in real-time.",
    icon: ArrowsClockwise,
  },
  {
    title: 'Audit Logging',
    description: 'Audit logging with audit log viewer (required in many business applications).',
    icon: FileText,
  },
  {
    title: 'AI Integration',
    description:
      'OpenRouter integration, Prompt system, Basic Conversation System, Agentic Conversation System with Tools, and Extended Thinking Mode.',
    icon: Brain,
    link: 'https://openrouter.ai/',
  },
  {
    title: 'Group Chat System',
    description:
      'Multiple agents in single chat with memory management (Journal/Core), conversation consolidation, and shared whiteboard.',
    icon: Chats,
  },
  {
    title: 'Automated Database Backups',
    description: 'Daily PostgreSQL backups to S3 via scheduled job with compression and easy restore process.',
    icon: CloudArrowUp,
  },
  {
    title: 'AI-Friendly JSON API',
    description:
      'RESTful API with OAuth-style CLI authentication for AI assistants. Includes conversations and whiteboards access.',
    icon: Plugs,
    link: '/ai/api.md',
  },
];

export const todoFeatures = [
  {
    title: 'Discard Gem',
    description:
      'Never delete anything important (e.g. accounts, users, etc), only soft-delete it for data integrity and recovery.',
    link: 'https://github.com/jhawthorn/discard',
    icon: Trash,
  },
  {
    title: 'MultiAttachment System',
    description: 'Supporting direct uploads to S3, PDF/Document parsing, URL fetch, and free text.',
    icon: Paperclip,
  },
  {
    title: 'Organisation Account Settings',
    description: 'Logo and Company Name settings for organisation accounts.',
    icon: Buildings,
  },
  {
    title: 'Billing',
    description: 'Billing integration for all account types.',
    icon: CreditCard,
  },
];
