<script>
  import { useForm, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Badge } from '$lib/components/shadcn/badge';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import * as Dialog from '$lib/components/shadcn/dialog/index.js';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import {
    Plus,
    Robot,
    PencilSimple,
    Trash,
    Brain,
    Sparkle,
    Lightning,
    Star,
    Heart,
    Sun,
    Moon,
    Eye,
    Globe,
    Compass,
    Rocket,
    Atom,
    Lightbulb,
    Crown,
    Shield,
    Fire,
    Target,
    Trophy,
    Flask,
    Code,
    Cube,
    PuzzlePiece,
    Cat,
    Dog,
    Bird,
    Alien,
    Ghost,
    Detective,
    Butterfly,
    Flower,
    Tree,
    Leaf,
  } from 'phosphor-svelte';
  import { useSync } from '$lib/use-sync';
  import {
    accountAgentsPath,
    editAccountAgentPath,
    accountAgentPath,
    triggerInitiationAccountAgentsPath,
  } from '@/routes';
  import ColourPicker from '$lib/components/ColourPicker.svelte';
  import IconPicker from '$lib/components/IconPicker.svelte';

  let {
    agents = [],
    grouped_models = {},
    available_tools = [],
    colour_options = [],
    icon_options = [],
    account,
  } = $props();

  // Map icon names to components for dynamic rendering
  const iconComponents = {
    Robot,
    Brain,
    Sparkle,
    Lightning,
    Star,
    Heart,
    Sun,
    Moon,
    Eye,
    Globe,
    Compass,
    Rocket,
    Atom,
    Lightbulb,
    Crown,
    Shield,
    Fire,
    Target,
    Trophy,
    Flask,
    Code,
    Cube,
    PuzzlePiece,
    Cat,
    Dog,
    Bird,
    Alien,
    Ghost,
    Detective,
    Butterfly,
    Flower,
    Tree,
    Leaf,
  };

  // Subscribe to both:
  // - Account:${id}:agents - individual agent updates (via collection subscription)
  // - Account:${id} - new agent creation (via broadcasts_to :account)
  useSync({
    [`Account:${account.id}:agents`]: 'agents',
    [`Account:${account.id}`]: 'agents',
  });

  let showCreateModal = $state(false);
  let selectedModel = $state(Object.values(grouped_models).flat()[0]?.model_id ?? 'openrouter/auto');

  // Build lookup map for tool display names
  const toolNameLookup = $derived(Object.fromEntries(available_tools.map((t) => [t.class_name, t.name])));

  let form = useForm({
    agent: {
      name: '',
      system_prompt: '',
      model_id: selectedModel,
      active: true,
      enabled_tools: [],
      colour: null,
      icon: null,
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

  function createAgent() {
    $form.agent.model_id = selectedModel;
    $form.post(accountAgentsPath(account.id), {
      onSuccess: () => {
        showCreateModal = false;
        resetForm();
      },
    });
  }

  function resetForm() {
    $form.agent.name = '';
    $form.agent.system_prompt = '';
    $form.agent.model_id = Object.values(grouped_models).flat()[0]?.model_id ?? 'openrouter/auto';
    $form.agent.active = true;
    $form.agent.enabled_tools = [];
    $form.agent.colour = null;
    $form.agent.icon = null;
    selectedModel = $form.agent.model_id;
  }

  function deleteAgent(agent) {
    if (!confirm(`Delete agent "${agent.name}"? This cannot be undone.`)) return;
    router.delete(accountAgentPath(account.id, agent.id));
  }
</script>

<svelte:head>
  <title>Agents</title>
</svelte:head>

<div class="p-8 max-w-6xl mx-auto">
  <div class="flex items-center justify-between mb-8">
    <div>
      <h1 class="text-3xl font-bold">Agents</h1>
      <p class="text-muted-foreground mt-1">Create and manage AI agents with custom personalities</p>
    </div>
    <div class="flex gap-2">
      <Button variant="outline" onclick={() => router.post(triggerInitiationAccountAgentsPath(account.id))}>
        <Lightning class="mr-2 size-4" />
        Trigger Initiation
      </Button>
      <Button onclick={() => (showCreateModal = true)}>
        <Plus class="mr-2 size-4" />
        New Agent
      </Button>
    </div>
  </div>

  {#if agents.length === 0}
    <Card>
      <CardContent class="py-16 text-center">
        <Robot class="mx-auto size-16 text-muted-foreground mb-4" weight="duotone" />
        <h2 class="text-xl font-semibold mb-2">No agents yet</h2>
        <p class="text-muted-foreground mb-6">
          Create your first agent to define a custom AI personality with specific tools and capabilities.
        </p>
        <Button onclick={() => (showCreateModal = true)}>
          <Plus class="mr-2 size-4" />
          Create Your First Agent
        </Button>
      </CardContent>
    </Card>
  {:else}
    <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {#each agents as agent (agent.id)}
        {@const IconComponent = iconComponents[agent.icon] || Robot}
        <Card class="hover:border-primary/50 transition-colors">
          <CardHeader class="pb-3">
            <div class="flex items-start justify-between">
              <div class="flex items-center gap-3">
                <div
                  class="p-2 rounded-lg {agent.colour
                    ? `bg-${agent.colour}-100 dark:bg-${agent.colour}-900`
                    : 'bg-primary/10'}">
                  <IconComponent
                    class="size-5 {agent.colour
                      ? `text-${agent.colour}-700 dark:text-${agent.colour}-300`
                      : 'text-primary'}"
                    weight="duotone" />
                </div>
                <div>
                  <CardTitle class="text-lg">{agent.name}</CardTitle>
                  {#if !agent.active}
                    <Badge variant="secondary" class="mt-1">Inactive</Badge>
                  {/if}
                </div>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <p class="text-sm text-muted-foreground line-clamp-2 mb-4 min-h-[2.5rem]">
              {agent.system_prompt || 'No system prompt defined'}
            </p>

            <div class="text-xs text-muted-foreground mb-2">
              <span class="font-medium">Model:</span>
              {agent.model_label || agent.model_id}
            </div>

            {#if agent.memory_token_summary}
              {@const mts = agent.memory_token_summary}
              <div class="text-xs text-muted-foreground mb-4 flex flex-wrap gap-x-3 gap-y-0.5">
                <span><span class="font-medium">Core:</span> {mts.core.toLocaleString()}t</span>
                <span><span class="font-medium">Journal:</span> {mts.active_journal.toLocaleString()}t</span>
                {#if mts.inactive_journal > 0}
                  <span class="opacity-50"
                    ><span class="font-medium">Inactive:</span> {mts.inactive_journal.toLocaleString()}t</span>
                {/if}
              </div>
            {/if}

            {#if agent.enabled_tools?.length > 0}
              <div class="flex flex-wrap gap-1 mb-4">
                {#each agent.enabled_tools.slice(0, 3) as tool}
                  <Badge variant="outline" class="text-xs">{toolNameLookup[tool] || tool}</Badge>
                {/each}
                {#if agent.enabled_tools.length > 3}
                  <Badge variant="outline" class="text-xs">+{agent.enabled_tools.length - 3} more</Badge>
                {/if}
              </div>
            {/if}

            <div class="flex gap-2 pt-2 border-t">
              <a href={editAccountAgentPath(account.id, agent.id)} class="flex-1">
                <Button variant="outline" size="sm" class="w-full">
                  <PencilSimple class="mr-1 size-4" />
                  Edit
                </Button>
              </a>
              <Button
                variant="outline"
                size="sm"
                onclick={() => deleteAgent(agent)}
                class="text-destructive hover:text-destructive">
                <Trash class="size-4" />
              </Button>
            </div>
          </CardContent>
        </Card>
      {/each}
    </div>
  {/if}
</div>

<!-- Create Agent Modal -->
<Dialog.Root bind:open={showCreateModal}>
  <Dialog.Content class="max-w-2xl max-h-[90vh] overflow-y-auto">
    <Dialog.Header>
      <Dialog.Title>Create New Agent</Dialog.Title>
      <Dialog.Description>Define a custom AI personality with specific tools and capabilities.</Dialog.Description>
    </Dialog.Header>

    <form
      onsubmit={(e) => {
        e.preventDefault();
        createAgent();
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
        <Select.Root
          type="single"
          value={selectedModel}
          onValueChange={(value) => {
            selectedModel = value;
          }}>
          <Select.Trigger class="w-full">
            {findModelLabel(selectedModel)}
          </Select.Trigger>
          <Select.Content sideOffset={4} class="max-h-60">
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

      <ColourPicker bind:value={$form.agent.colour} options={colour_options} label="Chat Bubble Colour" />

      <IconPicker bind:value={$form.agent.icon} options={icon_options} colour={$form.agent.colour} label="Agent Icon" />

      {#if available_tools.length > 0}
        <div class="space-y-3">
          <Label>Tools & Capabilities</Label>
          <div class="space-y-3 max-h-48 overflow-y-auto border rounded-md p-3">
            {#each available_tools as tool (tool.class_name)}
              <label class="flex items-start gap-3 cursor-pointer group">
                <input
                  type="checkbox"
                  checked={$form.agent.enabled_tools.includes(tool.class_name)}
                  onchange={() => toggleTool(tool.class_name)}
                  class="mt-1 w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
                <div class="space-y-0.5">
                  <div class="font-medium text-sm group-hover:text-primary transition-colors">{tool.name}</div>
                  {#if tool.description}
                    <p class="text-xs text-muted-foreground">{tool.description}</p>
                  {/if}
                </div>
              </label>
            {/each}
          </div>
        </div>
      {/if}

      <Dialog.Footer>
        <Button type="button" variant="outline" onclick={() => (showCreateModal = false)}>Cancel</Button>
        <Button type="submit" disabled={$form.processing}>
          {$form.processing ? 'Creating...' : 'Create Agent'}
        </Button>
      </Dialog.Footer>
    </form>
  </Dialog.Content>
</Dialog.Root>
