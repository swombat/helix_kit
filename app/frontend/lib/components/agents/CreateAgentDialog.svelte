<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import * as Dialog from '$lib/components/shadcn/dialog/index.js';
  import AgentAppearanceFields from '$lib/components/agents/AgentAppearanceFields.svelte';
  import AgentModelSelect from '$lib/components/agents/AgentModelSelect.svelte';
  import AgentToolChecklist from '$lib/components/agents/AgentToolChecklist.svelte';

  let {
    open = $bindable(false),
    form,
    selectedModel = $bindable(),
    groupedModels = {},
    availableTools = [],
    colourOptions = [],
    iconOptions = [],
    onsubmit,
  } = $props();
</script>

<Dialog.Root bind:open>
  <Dialog.Content class="max-w-2xl max-h-[90vh] overflow-y-auto">
    <Dialog.Header>
      <Dialog.Title>Create New Agent</Dialog.Title>
      <Dialog.Description>Define a custom AI personality with specific tools and capabilities.</Dialog.Description>
    </Dialog.Header>

    <form
      onsubmit={(event) => {
        event.preventDefault();
        onsubmit?.();
      }}
      class="space-y-6 mt-4">
      <div class="space-y-2">
        <Label for="name">Name</Label>
        <Input
          id="name"
          type="text"
          bind:value={$form.agent.name}
          placeholder="e.g., Research Assistant"
          required
          maxlength={100} />
        {#if $form.errors.name}
          <p class="text-sm text-destructive">{$form.errors.name}</p>
        {/if}
      </div>

      <div class="space-y-2">
        <Label for="system_prompt">System Prompt</Label>
        <textarea
          id="system_prompt"
          bind:value={$form.agent.system_prompt}
          placeholder="You are a helpful research assistant that..."
          rows="4"
          class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
                 focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
      </div>

      <div class="space-y-2">
        <Label>AI Model</Label>
        <AgentModelSelect {groupedModels} bind:value={selectedModel} triggerClass="w-full" contentClass="max-h-60" />
      </div>

      <div class="flex items-center justify-between">
        <div class="space-y-1">
          <Label for="active">Active</Label>
          <p class="text-sm text-muted-foreground">For future filtering in agent selection</p>
        </div>
        <Switch
          id="active"
          checked={$form.agent.active}
          onCheckedChange={(checked) => ($form.agent.active = checked)} />
      </div>

      <AgentAppearanceFields
        bind:colour={$form.agent.colour}
        bind:icon={$form.agent.icon}
        {colourOptions}
        {iconOptions} />

      {#if availableTools.length > 0}
        <div class="space-y-3">
          <Label>Tools & Capabilities</Label>
          <AgentToolChecklist tools={availableTools} bind:enabledTools={$form.agent.enabled_tools} compact />
        </div>
      {/if}

      <Dialog.Footer>
        <Button type="button" variant="outline" onclick={() => (open = false)}>Cancel</Button>
        <Button type="submit" disabled={$form.processing}>
          {$form.processing ? 'Creating...' : 'Create Agent'}
        </Button>
      </Dialog.Footer>
    </form>
  </Dialog.Content>
</Dialog.Root>
