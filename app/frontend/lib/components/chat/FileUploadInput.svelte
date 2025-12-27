<script>
  import { Paperclip, X } from 'phosphor-svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';

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

  const mimeToExtension = {
    'image/png': '.png',
    'image/jpeg': '.jpg,.jpeg',
    'image/jpg': '.jpg',
    'image/gif': '.gif',
    'image/webp': '.webp',
    'image/bmp': '.bmp',
    'audio/mpeg': '.mp3',
    'audio/wav': '.wav',
    'audio/m4a': '.m4a',
    'audio/ogg': '.ogg',
    'audio/flac': '.flac',
    'video/mp4': '.mp4',
    'video/quicktime': '.mov',
    'video/x-msvideo': '.avi',
    'video/webm': '.webm',
    'application/pdf': '.pdf',
    'application/msword': '.doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
    'text/plain': '.txt',
    'text/markdown': '.md',
    'text/csv': '.csv',
  };

  const acceptAttribute = $derived(() => {
    const fromMimeTypes = allowedTypes.map((type) => mimeToExtension[type] || '').filter(Boolean);
    const allExtensions = [...new Set([...fromMimeTypes, ...allowedExtensions])];
    return allExtensions.join(',');
  });

  function getFileExtension(filename) {
    const lastDot = filename.lastIndexOf('.');
    return lastDot !== -1 ? filename.slice(lastDot).toLowerCase() : '';
  }

  function validateFile(file) {
    const extension = getFileExtension(file.name);
    const typeAllowed = allowedTypes.includes(file.type);
    const extensionAllowed = allowedExtensions.includes(extension);

    // Accept if either MIME type or extension matches
    if (!typeAllowed && !extensionAllowed) {
      return 'File type not supported. Please upload images, audio, video, or documents.';
    }

    if (file.size > maxSize) {
      return `File too large. Maximum size is ${maxSize / (1024 * 1024)}MB.`;
    }

    return null;
  }

  function handleFileSelect(event) {
    const selectedFiles = Array.from(event.target.files || []);
    processFiles(selectedFiles);
  }

  function processFiles(selectedFiles) {
    error = null;

    if (files.length + selectedFiles.length > maxFiles) {
      error = `Maximum ${maxFiles} files allowed.`;
      return;
    }

    for (const file of selectedFiles) {
      const validationError = validateFile(file);
      if (validationError) {
        error = validationError;
        return;
      }
    }

    files = [...files, ...selectedFiles];
  }

  function removeFile(index) {
    files = files.filter((_, i) => i !== index);
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

  function formatFileSize(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
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
