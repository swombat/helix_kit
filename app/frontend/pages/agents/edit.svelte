<script>
  import { useForm } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '$lib/components/shadcn/card';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import { ArrowLeft } from 'phosphor-svelte';
  import { accountAgentsPath, accountAgentPath } from '@/routes';
  import ColourPicker from '$lib/components/ColourPicker.svelte';
  import IconPicker from '$lib/components/IconPicker.svelte';

  let { agent, grouped_models = {}, available_tools = [], colour_options = [], icon_options = [], account } = $props();

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
