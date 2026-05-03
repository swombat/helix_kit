<script>
  import { page, router } from '@inertiajs/svelte';
  import { createDynamicSync } from '$lib/use-sync';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import WhiteboardEmptyState from '$lib/components/whiteboards/WhiteboardEmptyState.svelte';
  import WhiteboardList from '$lib/components/whiteboards/WhiteboardList.svelte';
  import WhiteboardPlaceholder from '$lib/components/whiteboards/WhiteboardPlaceholder.svelte';
  import { PencilSimple, FloppyDisk, X, Spinner } from 'phosphor-svelte';
  import { Streamdown } from 'svelte-streamdown';
  import { mode } from 'mode-watcher';

  const shikiTheme = $derived(mode.current === 'dark' ? 'catppuccin-mocha' : 'catppuccin-latte');

  let { whiteboards = [], account } = $props();

  // Parse URL to get selected ID (Inertia's $page.url is a string, not a URL object)
  const selectedId = $derived(() => {
    try {
      const url = new URL($page.url, window.location.origin);
      return url.searchParams.get('id');
    } catch {
      return null;
    }
  });
  const selected = $derived(whiteboards.find((w) => String(w.id) === selectedId()));

  let editing = $state(false);
  let editContent = $state('');
  let conflict = $state(null);
  let saving = $state(false);

  const updateSync = createDynamicSync();

  $effect(() => {
    const subs = {
      [`Account:${account.id}:whiteboards`]: 'whiteboards',
    };
    if (selected) {
      subs[`Whiteboard:${selected.id}`] = 'whiteboards';
    }
    updateSync(subs);
  });

  function selectWhiteboard(id) {
    editing = false;
    conflict = null;
    router.get(`/accounts/${account.id}/whiteboards`, { id }, { preserveState: true, preserveScroll: true });
  }

  function startEditing() {
    editContent = selected?.content || '';
    editing = true;
  }

  function cancelEditing() {
    editing = false;
    editContent = '';
    conflict = null;
  }

  async function saveWhiteboard() {
    saving = true;
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

    try {
      const response = await fetch(`/accounts/${account.id}/whiteboards/${selected.id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken || '',
        },
        body: JSON.stringify({
          whiteboard: { content: editContent },
          expected_revision: selected.revision,
        }),
      });

      if (response.ok) {
        editing = false;
        conflict = null;
        saving = false;
        // Reload page data to get updated whiteboard
        router.reload({ only: ['whiteboards'], preserveScroll: true });
      } else {
        const data = await response.json();
        saving = false;
        if (data.error === 'conflict') {
          conflict = {
            serverContent: data.current_content,
            serverRevision: data.current_revision,
            myContent: editContent,
          };
        } else {
          alert('Failed to save. Please try again.');
        }
      }
    } catch (error) {
      saving = false;
      alert('Failed to save. Please try again.');
    }
  }

  function useServerVersion() {
    if (!conflict) return;
    editContent = conflict.serverContent;
    conflict = null;
  }

  function keepMyVersion() {
    conflict = null;
    saveWhiteboard();
  }
</script>

<svelte:head>
  <title>Whiteboards</title>
</svelte:head>

<div class="p-8 max-w-7xl mx-auto">
  <div class="mb-8">
    <h1 class="text-3xl font-bold">Whiteboards</h1>
    <p class="text-muted-foreground mt-1">Shared workspaces for agents and humans</p>
  </div>

  {#if whiteboards.length === 0}
    <WhiteboardEmptyState />
  {:else}
    <div class="grid gap-6 lg:grid-cols-3">
      <WhiteboardList {whiteboards} {selected} onSelect={selectWhiteboard} />

      <!-- Selected whiteboard viewer -->
      <div class="lg:col-span-2">
        {#if selected}
          <Card.Root class="h-[calc(100vh-16rem)]">
            <div class="flex flex-col h-full">
              <div class="flex items-center justify-between px-4 py-3 border-b border-border">
                <div>
                  <h3 class="font-semibold text-lg">{selected.name}</h3>
                  {#if selected.last_edited_at}
                    <p class="text-xs text-muted-foreground">
                      Last edited {selected.last_edited_at}
                      {#if selected.editor_name}
                        by {selected.editor_name}
                      {/if}
                    </p>
                  {/if}
                </div>

                <div class="flex items-center gap-2">
                  {#if editing}
                    <Button variant="outline" size="sm" onclick={cancelEditing} disabled={saving}>
                      <X class="mr-1 size-4" />
                      Cancel
                    </Button>
                    <Button size="sm" onclick={saveWhiteboard} disabled={saving}>
                      {#if saving}
                        <Spinner class="mr-1 size-4 animate-spin" />
                      {:else}
                        <FloppyDisk class="mr-1 size-4" />
                      {/if}
                      Save
                    </Button>
                  {:else}
                    <Button variant="outline" size="sm" onclick={startEditing}>
                      <PencilSimple class="mr-1 size-4" />
                      Edit
                    </Button>
                  {/if}
                </div>
              </div>

              {#if conflict}
                <div class="px-4 py-3 bg-amber-50 dark:bg-amber-950/30 border-b border-amber-200 dark:border-amber-800">
                  <p class="font-semibold text-amber-800 dark:text-amber-200 mb-1">
                    Someone else edited this whiteboard
                  </p>
                  <p class="text-sm text-amber-700 dark:text-amber-300 mb-3">
                    Your changes have been preserved. Choose which version to keep:
                  </p>
                  <div class="flex gap-2">
                    <Button variant="outline" size="sm" onclick={useServerVersion}>Use their version</Button>
                    <Button size="sm" onclick={keepMyVersion}>Keep mine and save</Button>
                  </div>
                </div>
              {/if}

              <div class="flex-1 overflow-y-auto p-4">
                {#if editing}
                  <textarea
                    bind:value={editContent}
                    class="w-full h-full min-h-[300px] resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
                           focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"
                    placeholder="Write your whiteboard content here..."></textarea>
                {:else if selected.content?.trim()}
                  <div class="prose dark:prose-invert max-w-none">
                    <Streamdown
                      content={selected.content}
                      parseIncompleteMarkdown={false}
                      baseTheme="shadcn"
                      {shikiTheme}
                      shikiPreloadThemes={['catppuccin-latte', 'catppuccin-mocha']} />
                  </div>
                {:else}
                  <p class="text-muted-foreground text-center py-8">No content yet. Click Edit to add content.</p>
                {/if}
              </div>
            </div>
          </Card.Root>
        {:else}
          <WhiteboardPlaceholder />
        {/if}
      </div>
    </div>
  {/if}
</div>
