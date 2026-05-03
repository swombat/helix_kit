<script>
  import { page, router } from '@inertiajs/svelte';
  import { createDynamicSync } from '$lib/use-sync';
  import WhiteboardEmptyState from '$lib/components/whiteboards/WhiteboardEmptyState.svelte';
  import WhiteboardList from '$lib/components/whiteboards/WhiteboardList.svelte';
  import WhiteboardPlaceholder from '$lib/components/whiteboards/WhiteboardPlaceholder.svelte';
  import WhiteboardViewer from '$lib/components/whiteboards/WhiteboardViewer.svelte';

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
          <WhiteboardViewer
            {selected}
            {editing}
            bind:editContent
            {conflict}
            {saving}
            onStartEditing={startEditing}
            onCancelEditing={cancelEditing}
            onSave={saveWhiteboard}
            onUseServerVersion={useServerVersion}
            onKeepMyVersion={keepMyVersion} />
        {:else}
          <WhiteboardPlaceholder />
        {/if}
      </div>
    </div>
  {/if}
</div>
