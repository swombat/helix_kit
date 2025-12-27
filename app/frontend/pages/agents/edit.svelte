<script>
  import { useForm, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '$lib/components/shadcn/card';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import { ArrowLeft, Brain, BookOpen, Warning, Trash, Plus } from 'phosphor-svelte';
  import { accountAgentsPath, accountAgentPath } from '@/routes';
  import ColourPicker from '$lib/components/ColourPicker.svelte';
  import IconPicker from '$lib/components/IconPicker.svelte';

  let {
    agent,
    memories = [],
    grouped_models = {},
    available_tools = [],
    colour_options = [],
    icon_options = [],
    account,
  } = $props();

  let selectedModel = $state(agent.model_id);

  let form = useForm({
    agent: {
      name: agent.name,
      system_prompt: agent.system_prompt || '',
      model_id: agent.model_id,
      active: agent.active,
      enabled_tools: agent.enabled_tools || [],
      colour: agent.colour || null,
      icon: agent.icon || null,
    },
  });

  function findModelLabel(modelId) {
    for (const models of Object.values(grouped_models)) {
      const found = models.find((m) => m.model_id === modelId);
      if (found) return found.label;
    }
    return modelId;
  }

  function toggleTool(toolClassName) {
    const tools = [...$form.agent.enabled_tools];
    const index = tools.indexOf(toolClassName);
    if (index === -1) {
      tools.push(toolClassName);
    } else {
      tools.splice(index, 1);
    }
    $form.agent.enabled_tools = tools;
  }

  function updateAgent() {
    $form.agent.model_id = selectedModel;
    $form.patch(accountAgentPath(account.id, agent.id));
  }

  function deleteMemory(memoryId) {
    if (confirm('Delete this memory permanently?')) {
      router.delete(`/accounts/${account.id}/agents/${agent.id}/memories/${memoryId}`);
    }
  }

  let showNewMemoryForm = $state(false);
  let newMemoryContent = $state('');
  let newMemoryType = $state('core');

  function createMemory() {
    if (!newMemoryContent.trim()) return;

    router.post(`/accounts/${account.id}/agents/${agent.id}/memories`, {
      memory: {
        content: newMemoryContent,
        memory_type: newMemoryType,
      },
    });

    // Reset form
    newMemoryContent = '';
    newMemoryType = 'core';
    showNewMemoryForm = false;
  }
</script>

<svelte:head>
  <title>Edit {agent.name}</title>
</svelte:head>

<div class="p-8 max-w-3xl mx-auto">
  <div class="mb-8">
    <a
      href={accountAgentsPath(account.id)}
      class="inline-flex items-center text-sm text-muted-foreground hover:text-foreground mb-4">
      <ArrowLeft class="mr-1 size-4" />
      Back to Agents
    </a>
    <h1 class="text-3xl font-bold">Edit Agent</h1>
    <p class="text-muted-foreground mt-1">Update {agent.name}'s configuration</p>
  </div>

  <form
    onsubmit={(e) => {
      e.preventDefault();
      updateAgent();
    }}>
    <div class="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Agent Identity</CardTitle>
          <CardDescription>Define the agent's name and personality</CardDescription>
        </CardHeader>
        <CardContent class="space-y-4">
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
              rows="6"
              class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
                     focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
            <p class="text-xs text-muted-foreground">
              Define the agent's personality, expertise, and behavior guidelines.
            </p>
          </div>

          <div class="flex items-center justify-between pt-4">
            <div class="space-y-1">
              <Label for="active">Active</Label>
              <p class="text-sm text-muted-foreground">For future filtering in agent selection</p>
            </div>
            <Switch
              id="active"
              checked={$form.agent.active}
              onCheckedChange={(checked) => ($form.agent.active = checked)} />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Chat Appearance</CardTitle>
          <CardDescription>Customise how this agent appears in group chats</CardDescription>
        </CardHeader>
        <CardContent class="space-y-6">
          <ColourPicker bind:value={$form.agent.colour} options={colour_options} label="Chat Bubble Colour" />
          <IconPicker
            bind:value={$form.agent.icon}
            options={icon_options}
            colour={$form.agent.colour}
            label="Agent Icon" />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>AI Model</CardTitle>
          <CardDescription>Choose which AI model powers this agent</CardDescription>
        </CardHeader>
        <CardContent>
          <Select.Root
            type="single"
            value={selectedModel}
            onValueChange={(value) => {
              selectedModel = value;
            }}>
            <Select.Trigger class="w-full max-w-md">
              {findModelLabel(selectedModel)}
            </Select.Trigger>
            <Select.Content sideOffset={4} class="max-h-80">
              {#each Object.entries(grouped_models) as [groupName, models]}
                <Select.Group>
                  <Select.GroupHeading class="px-2 py-1.5 text-xs font-semibold text-muted-foreground">
                    {groupName}
                  </Select.GroupHeading>
                  {#each models as model (model.model_id)}
                    <Select.Item value={model.model_id} label={model.label}>{model.label}</Select.Item>
                  {/each}
                </Select.Group>
              {/each}
            </Select.Content>
          </Select.Root>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Tools & Capabilities</CardTitle>
          <CardDescription
            >Select which tools this agent can use. New tools will be disabled by default.</CardDescription>
        </CardHeader>
        <CardContent>
          {#if available_tools.length === 0}
            <p class="text-sm text-muted-foreground py-4">
              No tools are currently available. Tools will appear here as they are added to the system.
            </p>
          {:else}
            <div class="space-y-4">
              {#each available_tools as tool (tool.class_name)}
                <label class="flex items-start gap-3 cursor-pointer group">
                  <input
                    type="checkbox"
                    checked={$form.agent.enabled_tools.includes(tool.class_name)}
                    onchange={() => toggleTool(tool.class_name)}
                    class="mt-1 w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
                  <div class="space-y-1">
                    <div class="font-medium group-hover:text-primary transition-colors">{tool.name}</div>
                    {#if tool.description}
                      <p class="text-sm text-muted-foreground">{tool.description}</p>
                    {/if}
                  </div>
                </label>
              {/each}
            </div>
          {/if}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <div class="flex items-start justify-between">
            <div>
              <CardTitle>Agent Memory</CardTitle>
              <CardDescription>
                Review and manage this agent's memories. Core memories are permanent; journal entries fade after a week.
              </CardDescription>
            </div>
            {#if !showNewMemoryForm}
              <Button type="button" variant="outline" size="sm" onclick={() => (showNewMemoryForm = true)}>
                <Plus class="size-4 mr-1" />
                Add Memory
              </Button>
            {/if}
          </div>
        </CardHeader>
        <CardContent>
          {#if showNewMemoryForm}
            <div class="mb-4 p-4 border rounded-lg bg-muted/30 space-y-4">
              <div class="space-y-2">
                <Label for="new_memory_content">Memory Content</Label>
                <textarea
                  id="new_memory_content"
                  bind:value={newMemoryContent}
                  placeholder="Enter the memory content..."
                  rows="3"
                  class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                         focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
              </div>
              <div class="space-y-2">
                <Label>Memory Type</Label>
                <div class="flex gap-4">
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input type="radio" name="memory_type" value="core" bind:group={newMemoryType} class="w-4 h-4" />
                    <Brain size={16} class="text-primary" weight="duotone" />
                    <span class="text-sm">Core (permanent)</span>
                  </label>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input type="radio" name="memory_type" value="journal" bind:group={newMemoryType} class="w-4 h-4" />
                    <BookOpen size={16} class="text-muted-foreground" weight="duotone" />
                    <span class="text-sm">Journal (expires in 1 week)</span>
                  </label>
                </div>
              </div>
              <div class="flex gap-2 justify-end">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onclick={() => {
                    showNewMemoryForm = false;
                    newMemoryContent = '';
                    newMemoryType = 'core';
                  }}>
                  Cancel
                </Button>
                <Button type="button" size="sm" onclick={createMemory} disabled={!newMemoryContent.trim()}>
                  Save Memory
                </Button>
              </div>
            </div>
          {/if}

          {#if memories.length === 0 && !showNewMemoryForm}
            <p class="text-sm text-muted-foreground py-4">
              This agent has no memories yet. Click "Add Memory" to create one manually, or memories will appear here as
              the agent creates them using the save_memory tool.
            </p>
          {:else if memories.length > 0}
            <div class="space-y-3 max-h-96 overflow-y-auto">
              {#each memories as memory (memory.id)}
                <div
                  class="flex items-start gap-3 p-3 rounded-lg border {memory.expired
                    ? 'opacity-50 border-dashed'
                    : 'border-border'}">
                  <div class="flex-shrink-0 mt-0.5">
                    {#if memory.memory_type === 'core'}
                      <Brain size={18} class="text-primary" weight="duotone" />
                    {:else}
                      <BookOpen size={18} class="text-muted-foreground" weight="duotone" />
                    {/if}
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 mb-1">
                      <span
                        class="text-xs font-medium uppercase {memory.memory_type === 'core'
                          ? 'text-primary'
                          : 'text-muted-foreground'}">
                        {memory.memory_type}
                      </span>
                      <span class="text-xs text-muted-foreground">{memory.created_at}</span>
                      {#if memory.expired}
                        <span class="text-xs text-warning flex items-center gap-1">
                          <Warning size={12} /> expired
                        </span>
                      {/if}
                    </div>
                    <p class="text-sm whitespace-pre-wrap break-words">{memory.content}</p>
                  </div>
                  <button
                    type="button"
                    onclick={() => deleteMemory(memory.id)}
                    class="flex-shrink-0 p-1 text-muted-foreground hover:text-destructive transition-colors">
                    <Trash size={16} />
                  </button>
                </div>
              {/each}
            </div>
          {/if}
        </CardContent>
      </Card>

      <div class="flex justify-end gap-3">
        <a href={accountAgentsPath(account.id)}>
          <Button type="button" variant="outline">Cancel</Button>
        </a>
        <Button type="submit" disabled={$form.processing}>
          {$form.processing ? 'Saving...' : 'Update Agent'}
        </Button>
      </div>
    </div>
  </form>
</div>
