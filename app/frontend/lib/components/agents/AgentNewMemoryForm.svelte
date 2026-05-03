<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Label } from '$lib/components/shadcn/label';
  import { BookOpen, Brain } from 'phosphor-svelte';

  let { oncancel, oncreate } = $props();

  let content = $state('');
  let memoryType = $state('core');

  function reset() {
    content = '';
    memoryType = 'core';
  }

  function cancel() {
    reset();
    oncancel?.();
  }

  function createMemory() {
    if (!content.trim()) return;

    oncreate?.({
      content,
      memoryType,
    });
    reset();
  }
</script>

<div class="p-4 border rounded-lg bg-muted/30 space-y-4">
  <div class="space-y-2">
    <Label for="new_memory_content">Memory Content</Label>
    <textarea
      id="new_memory_content"
      bind:value={content}
      placeholder="Enter the memory content..."
      rows="3"
      class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
             focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
  </div>

  <fieldset class="space-y-2">
    <legend class="text-sm font-medium leading-none">Memory Type</legend>
    <div class="flex gap-4">
      <label class="flex items-center gap-2 cursor-pointer">
        <input type="radio" name="memory_type" value="core" bind:group={memoryType} class="w-4 h-4" />
        <Brain size={16} class="text-primary" weight="duotone" />
        <span class="text-sm">Core (permanent)</span>
      </label>
      <label class="flex items-center gap-2 cursor-pointer">
        <input type="radio" name="memory_type" value="journal" bind:group={memoryType} class="w-4 h-4" />
        <BookOpen size={16} class="text-muted-foreground" weight="duotone" />
        <span class="text-sm">Journal (expires in 1 week)</span>
      </label>
    </div>
  </fieldset>

  <div class="flex gap-2 justify-end">
    <Button type="button" variant="outline" size="sm" onclick={cancel}>Cancel</Button>
    <Button type="button" size="sm" onclick={createMemory} disabled={!content.trim()}>Save Memory</Button>
  </div>
</div>
