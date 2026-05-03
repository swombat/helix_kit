<script>
  import FileUploadInput from '$lib/components/chat/FileUploadInput.svelte';
  import { ArrowUp } from 'phosphor-svelte';

  let {
    selectedFiles = $bindable([]),
    message = $bindable(''),
    textareaRef = $bindable(null),
    fileUploadConfig = {},
    processing = false,
    isGroupChat = false,
    selectedAgentIds = [],
    placeholder = 'Type your message to start the chat...',
    onSubmit,
    onKeydown,
    onInput,
  } = $props();
</script>

<div class="border-t border-border bg-muted/30 p-3 md:p-4">
  <div class="flex gap-2 md:gap-3 items-start">
    <FileUploadInput
      bind:files={selectedFiles}
      disabled={processing}
      allowedTypes={fileUploadConfig?.acceptable_types || []}
      allowedExtensions={fileUploadConfig?.acceptable_extensions || []}
      maxSize={fileUploadConfig?.max_size || 52428800} />

    <div class="flex-1">
      <textarea
        bind:this={textareaRef}
        bind:value={message}
        onkeydown={onKeydown}
        oninput={onInput}
        {placeholder}
        disabled={processing}
        class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
               focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent
               min-h-[40px] max-h-[240px] overflow-y-auto"
        rows="1"></textarea>
    </div>
    <button
      onclick={onSubmit}
      disabled={(!message.trim() && selectedFiles.length === 0) ||
        processing ||
        (isGroupChat && selectedAgentIds.length === 0)}
      class="h-10 w-10 p-0 inline-flex items-center justify-center rounded-md bg-primary text-primary-foreground hover:bg-primary/90 disabled:pointer-events-none disabled:opacity-50">
      <ArrowUp size={16} />
    </button>
  </div>
</div>
