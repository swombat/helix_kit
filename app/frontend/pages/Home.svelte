<script>
  import { buttonVariants } from '$lib/components/shadcn/button/button.svelte';
  import FeatureGrid from '$lib/components/home/FeatureGrid.svelte';
  import { completedFeatures, todoFeatures } from '$lib/home-features.js';
  import { GithubLogo } from 'phosphor-svelte';

  const githubUrl = 'https://github.com/swombat/helix_kit';
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
      <FeatureGrid title="Features (Done)" features={completedFeatures} />
      <FeatureGrid title="Target Features (Todo)" features={todoFeatures} muted />
    </div>
  </div>
</div>
