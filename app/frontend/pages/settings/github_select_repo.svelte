<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { GithubLogo, Lock, MagnifyingGlass } from 'phosphor-svelte';

  let { repos, current_repo } = $props();

  let search = $state('');
  let selectedRepo = $state(current_repo || '');

  const filteredRepos = $derived(repos.filter((r) => r.full_name.toLowerCase().includes(search.toLowerCase())));

  function saveRepo() {
    router.post('/github_integration/save_repo', { repository_full_name: selectedRepo });
  }
</script>

<svelte:head>
  <title>Select Repository</title>
</svelte:head>

<div class="container mx-auto p-8 max-w-2xl">
  <div class="mb-8">
    <h1 class="text-3xl font-bold mb-2">Select Repository</h1>
    <p class="text-muted-foreground">Choose which repository to track for commit activity.</p>
  </div>

  <div class="border rounded-lg p-6">
    <div class="relative mb-4">
      <MagnifyingGlass size={16} class="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
      <input
        type="text"
        placeholder="Search repositories..."
        bind:value={search}
        class="w-full pl-9 pr-4 py-2 border rounded-md bg-background text-sm" />
    </div>

    <div class="max-h-96 overflow-y-auto space-y-1">
      {#each filteredRepos as repo}
        <button
          type="button"
          class="w-full flex items-center gap-3 px-3 py-2 rounded-md text-left text-sm hover:bg-accent transition-colors {selectedRepo ===
          repo.full_name
            ? 'bg-accent ring-1 ring-primary'
            : ''}"
          onclick={() => (selectedRepo = repo.full_name)}>
          <GithubLogo size={16} class="shrink-0" />
          <span class="truncate">{repo.full_name}</span>
          {#if repo.private}
            <Lock size={14} class="shrink-0 text-muted-foreground" />
          {/if}
        </button>
      {:else}
        <p class="text-sm text-muted-foreground text-center py-4">No repositories found.</p>
      {/each}
    </div>

    <div class="flex justify-end gap-2 mt-6 pt-4 border-t">
      <Button variant="outline" onclick={() => router.visit('/github_integration')}>Cancel</Button>
      <Button onclick={saveRepo} disabled={!selectedRepo}>Link Repository</Button>
    </div>
  </div>
</div>
