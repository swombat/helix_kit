<script>
  import { router } from '@inertiajs/svelte';
  import { Key, Trash, Plus } from 'phosphor-svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input/index.js';

  let { api_keys = [] } = $props();
  let newKeyName = $state('');
  let showForm = $state(false);

  function createKey() {
    if (newKeyName.trim()) {
      router.post('/api_keys', { name: newKeyName });
    }
  }

  function deleteKey(id) {
    if (confirm('Revoke this API key? Applications using it will stop working.')) {
      router.delete(`/api_keys/${id}`);
    }
  }
</script>

<div class="container mx-auto p-8 max-w-4xl">
  <div class="flex items-center justify-between mb-6">
    <div>
      <h1 class="text-2xl font-bold">API Keys</h1>
      <p class="text-muted-foreground">Manage API keys for CLI tools</p>
    </div>
    <Button onclick={() => (showForm = !showForm)}>
      <Plus class="mr-2" size={16} />
      Create Key
    </Button>
  </div>

  {#if showForm}
    <div class="mb-6 p-4 border rounded-lg">
      <form
        onsubmit={(e) => {
          e.preventDefault();
          createKey();
        }}
        class="flex gap-2">
        <Input bind:value={newKeyName} placeholder="Key name (e.g., Claude Code)" class="flex-1" />
        <Button type="submit">Create</Button>
      </form>
    </div>
  {/if}

  <div class="border rounded-lg">
    {#if api_keys.length === 0}
      <div class="p-8 text-center text-muted-foreground">
        <Key size={48} class="mx-auto mb-4 opacity-50" />
        <p>No API keys yet. Create one to use with CLI tools.</p>
      </div>
    {:else}
      <div class="divide-y">
        {#each api_keys as key (key.id)}
          <div class="flex items-center justify-between p-4">
            <div>
              <div class="font-medium">{key.name}</div>
              <div class="text-sm text-muted-foreground">
                <code class="bg-muted px-1 rounded">{key.prefix}</code>
                <span class="mx-2">-</span>
                Created {key.created_at}
              </div>
              {#if key.last_used_at}
                <div class="text-xs text-muted-foreground mt-1">
                  Last used {key.last_used_at}
                </div>
              {/if}
            </div>
            <Button variant="ghost" size="icon" onclick={() => deleteKey(key.id)}>
              <Trash size={16} class="text-destructive" />
            </Button>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>
