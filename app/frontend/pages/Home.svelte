<script>
  import { buttonVariants } from '$lib/components/shadcn/button/button.svelte';
  import {
    GithubLogo,
    ArrowUpRight,
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
  import * as Card from '$lib/components/shadcn/card/index.js';

  const githubUrl = 'https://github.com/swombat/helix_kit';

  const completedFeatures = [
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

  const todoFeatures = [
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
</script>

<svelte:head>
  <title>Home</title>
</svelte:head>

<div class="bg-muted border-b">
  <div class="mx-auto max-w-2xl px-6 lg:max-w-7xl lg:px-8 border-l border-r border-dashed pt-40 pb-50">
    <h1 class="text-4xl tracking-tighter text-balance max-lg:font-medium max-sm:px-4 sm:text-5xl lg:text-6xl">
      HelixKit: Svelte App Kit for Ruby on Rails
    </h1>
    <p class="opacity-80 mt-4">
      A start app kit template analogous to Jumpstart Pro or BulletTrain, but using Svelte and Inertia.js for the
      frontend, with Ruby on Rails as the backend, and including a number of other useful libraries and tools.
    </p>
    <p class="opacity-80 mt-4">
      Unlike typical app-kits, this one begins with the assumption that all apps worth building at this point will have
      heavy AI integration, including at the very least chat/conversation features, agentic set ups, tools, and group
      chat features.
    </p>
    <div class="mt-8">
      <a href={githubUrl} class={buttonVariants({ variant: 'default' })} target="_blank" rel="noopener noreferrer">
        <GithubLogo class="text-white dark:text-black" />
        <span>Github repo</span>
      </a>
    </div>
  </div>
</div>

<div class="-mt-15">
  <div class="mx-auto max-w-2xl px-6 lg:max-w-7xl lg:px-8 pb-24 border-l border-r border-dashed">
    <div class="space-y-8">
      <div>
        <h2 class="text-2xl font-semibold mb-4">Features (Done)</h2>
        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {#each completedFeatures as feature}
            <Card.Root class="flex flex-col justify-between">
              <Card.Header>
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0">
                    <svelte:component this={feature.icon} size={48} weight="duotone" class="text-primary" />
                  </div>
                  <div class="flex-1">
                    <Card.Title class="mb-2">{feature.title}</Card.Title>
                    <Card.Description>{feature.description}</Card.Description>
                  </div>
                </div>
              </Card.Header>
              {#if feature.link}
                <Card.Content class="flex justify-end">
                  <a
                    href={feature.link}
                    class={buttonVariants({ variant: 'ghost' })}
                    target="_blank"
                    rel="noopener noreferrer">
                    <span>See more </span>
                    <ArrowUpRight weight="bold" />
                  </a>
                </Card.Content>
              {/if}
            </Card.Root>
          {/each}
        </div>
      </div>

      <div>
        <h2 class="text-2xl font-semibold mb-4">Target Features (Todo)</h2>
        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {#each todoFeatures as feature}
            <Card.Root class="flex flex-col justify-between opacity-75 h-full">
              <Card.Header class="flex-1">
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0">
                    <svelte:component this={feature.icon} size={48} weight="duotone" class="text-muted-foreground" />
                  </div>
                  <div class="flex-1">
                    <Card.Title class="mb-2">{feature.title}</Card.Title>
                    <Card.Description>{feature.description}</Card.Description>
                  </div>
                </div>
              </Card.Header>
              <Card.Content class="flex justify-end">
                {#if feature.link}
                  <a
                    href={feature.link}
                    class={buttonVariants({ variant: 'ghost' })}
                    target="_blank"
                    rel="noopener noreferrer">
                    <span>See more </span>
                    <ArrowUpRight weight="bold" />
                  </a>
                {:else}
                  <div class="h-10"></div>
                {/if}
              </Card.Content>
            </Card.Root>
          {/each}
        </div>
      </div>
    </div>
  </div>
</div>
