<script>
  import { Input } from '$lib/components/shadcn/input';
  import { BookOpen, Brain, MagnifyingGlass, ShieldCheck, Trash } from 'phosphor-svelte';

  let {
    memorySearch = $bindable(''),
    showCore = $bindable(true),
    showJournal = $bindable(true),
    showProtected = $bindable(true),
    showDiscarded = $bindable(false),
  } = $props();
</script>

<div class="flex flex-col sm:flex-row gap-3 items-start sm:items-center">
  <div class="relative flex-1 w-full sm:w-auto">
    <MagnifyingGlass size={16} class="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
    <Input type="text" placeholder="Search memories..." bind:value={memorySearch} class="pl-8" />
  </div>
  <div class="flex gap-3">
    <label class="flex items-center gap-1.5 cursor-pointer text-sm" title="Core">
      <input type="checkbox" bind:checked={showCore} class="w-3.5 h-3.5 rounded" />
      <Brain size={14} weight="duotone" class="lg:hidden text-primary" />
      <span class="hidden lg:inline">Core</span>
    </label>
    <label class="flex items-center gap-1.5 cursor-pointer text-sm" title="Journal">
      <input type="checkbox" bind:checked={showJournal} class="w-3.5 h-3.5 rounded" />
      <BookOpen size={14} weight="duotone" class="lg:hidden text-muted-foreground" />
      <span class="hidden lg:inline">Journal</span>
    </label>
    <label class="flex items-center gap-1.5 cursor-pointer text-sm" title="Protected">
      <input type="checkbox" bind:checked={showProtected} class="w-3.5 h-3.5 rounded" />
      <ShieldCheck size={14} weight="duotone" class="lg:hidden text-primary" />
      <span class="hidden lg:inline">Protected</span>
    </label>
    <label class="flex items-center gap-1.5 cursor-pointer text-sm" title="Discarded">
      <input type="checkbox" bind:checked={showDiscarded} class="w-3.5 h-3.5 rounded" />
      <Trash size={14} weight="duotone" class="lg:hidden text-destructive" />
      <span class="hidden lg:inline">Discarded</span>
    </label>
  </div>
</div>
