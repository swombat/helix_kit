<script>
  import { Spinner } from 'phosphor-svelte';

  let { chat, titleIsLoading = false, onSaveTitle = () => {} } = $props();

  let titleEditing = $state(false);
  let titleEditValue = $state('');
  let titleInputRef = $state(null);

  $effect(() => {
    if (titleEditing && titleInputRef) {
      titleInputRef.focus();
      titleInputRef.select();
    }
  });

  function startEditingTitle() {
    if (!chat) return;
    titleEditValue = chat.title || 'New Chat';
    titleEditing = true;
  }

  function cancelEditingTitle() {
    titleEditing = false;
    titleEditValue = '';
  }

  function saveTitle() {
    if (!chat || !titleEditValue.trim()) {
      cancelEditingTitle();
      return;
    }

    const previousTitle = chat.title;
    titleEditing = false;
    onSaveTitle(titleEditValue.trim(), previousTitle);
  }

  function handleTitleKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      saveTitle();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      cancelEditingTitle();
    }
  }
</script>

{#if titleEditing}
  <input
    bind:this={titleInputRef}
    bind:value={titleEditValue}
    onkeydown={handleTitleKeydown}
    onblur={saveTitle}
    type="text"
    class="text-lg font-semibold bg-background border border-primary rounded px-2 py-1 w-full focus:outline-none focus:ring-2 focus:ring-ring" />
{:else}
  <h1 class="min-w-0">
    <button
      type="button"
      class="text-lg font-semibold cursor-pointer hover:opacity-70 transition-opacity flex items-center gap-2 min-w-0 text-left"
      onclick={startEditingTitle}
      title="Edit chat title">
      <span class="truncate">{chat?.title || 'New Chat'}</span>
      {#if titleIsLoading}
        <Spinner size={14} class="animate-spin text-muted-foreground flex-shrink-0" />
      {/if}
    </button>
  </h1>
{/if}
