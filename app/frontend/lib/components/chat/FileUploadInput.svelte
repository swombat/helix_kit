<script>
  import { Paperclip, X } from 'phosphor-svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { acceptAttributeFor, addUploadFiles, formatFileSize, removeUploadFile } from '$lib/file-upload-rules';

  let {
    files = $bindable([]),
    disabled = false,
    maxFiles = 5,
    maxSize = 50 * 1024 * 1024,
    allowedTypes = [],
    allowedExtensions = [],
  } = $props();

  let fileInput;
  let error = $state(null);
  let dragActive = $state(false);

  const acceptAttribute = $derived(acceptAttributeFor({ allowedTypes, allowedExtensions }));

  function handleFileSelect(event) {
    const selectedFiles = Array.from(event.target.files || []);
    processFiles(selectedFiles);
  }

  function processFiles(selectedFiles) {
    const result = addUploadFiles(files, selectedFiles, { maxFiles, maxSize, allowedTypes, allowedExtensions });
    files = result.files;
    error = result.error;
  }

  function removeFile(index) {
    files = removeUploadFile(files, index);
    error = null;
  }

  function handleDragOver(event) {
    event.preventDefault();
    dragActive = true;
  }

  function handleDragLeave() {
    dragActive = false;
  }

  function handleDrop(event) {
    event.preventDefault();
    dragActive = false;

    const droppedFiles = Array.from(event.dataTransfer.files || []);
    processFiles(droppedFiles);
  }
</script>

<div class="space-y-2">
  <input
    bind:this={fileInput}
    type="file"
    multiple
    accept={acceptAttribute}
    onchange={handleFileSelect}
    {disabled}
    class="hidden" />

  <Button
    type="button"
    variant="ghost"
    size="sm"
    onclick={() => fileInput?.click()}
    {disabled}
    class="h-10 w-10 p-0"
    title="Attach files">
    <Paperclip size={18} />
  </Button>

  {#if files.length > 0}
    <div class="space-y-2">
      {#each files as file, index}
        <div class="flex items-center gap-2 p-2 rounded-md border border-border bg-muted/50">
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium truncate">{file.name}</div>
            <div class="text-xs text-muted-foreground">{formatFileSize(file.size)}</div>
          </div>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onclick={() => removeFile(index)}
            {disabled}
            class="h-8 w-8 p-0">
            <X size={16} />
          </Button>
        </div>
      {/each}
    </div>
  {/if}

  {#if error}
    <div class="text-sm text-destructive">{error}</div>
  {/if}
</div>
