<script>
  import * as Drawer from '$lib/components/shadcn/drawer';
  import { X, DownloadSimple, ArrowSquareOut } from 'phosphor-svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';

  let { open = $bindable(false), file = null } = $props();

  // Use preview URL if available, otherwise fall back to original
  const imageUrl = $derived(file?.preview_url || file?.url);
</script>

<Drawer.Root bind:open direction="bottom">
  <Drawer.Content class="max-h-[85vh]">
    <div class="flex flex-col h-full">
      <Drawer.Header class="flex items-center justify-between px-4 py-3 border-b">
        <div class="flex-1 min-w-0">
          <Drawer.Title class="text-sm font-medium truncate">
            {file?.filename ?? 'Image'}
          </Drawer.Title>
        </div>
        <div class="flex items-center gap-2 ml-4">
          <a
            href={file?.url}
            download={file?.filename}
            class="p-2 rounded-md hover:bg-muted transition-colors"
            title="Download original">
            <DownloadSimple size={20} />
          </a>
          <Drawer.Close class="p-2 rounded-md hover:bg-muted transition-colors">
            <X size={20} />
          </Drawer.Close>
        </div>
      </Drawer.Header>
      <div class="flex-1 overflow-auto p-4 flex flex-col items-center justify-center bg-muted/30 gap-4">
        {#if imageUrl}
          <img
            src={imageUrl}
            alt={file?.filename}
            class="max-w-full max-h-[60vh] object-contain rounded-lg shadow-lg" />
        {/if}
        {#if file?.url && file?.preview_url}
          <a
            href={file.url}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors">
            <ArrowSquareOut size={16} />
            View full size original
          </a>
        {/if}
      </div>
    </div>
  </Drawer.Content>
</Drawer.Root>
