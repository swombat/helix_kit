<script>
  import { useForm, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '$lib/components/shadcn/card';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import { ArrowLeft, Brain, BookOpen, Warning, Trash, Plus, Shield, ShieldCheck, Lightning } from 'phosphor-svelte';
  import {
    accountAgentsPath,
    accountAgentPath,
    sendTestTelegramAccountAgentPath,
    registerTelegramWebhookAccountAgentPath,
  } from '@/routes';
  import ColourPicker from '$lib/components/ColourPicker.svelte';
  import IconPicker from '$lib/components/IconPicker.svelte';
  import { useSync } from '$lib/use-sync';

  let {
    agent,
    telegram_deep_link: telegramDeepLink = null,
    telegram_subscriber_count: telegramSubscriberCount = 0,
    memories = [],
    grouped_models = {},
    available_tools = [],
    colour_options = [],
    icon_options = [],
    account,
  } = $props();

  // Sync agent and memories when AgentMemory changes broadcast to agent
  useSync({
    [`Agent:${agent.id}`]: ['agent', 'memories'],
  });

  let selectedModel = $state(agent.model_id);
  let sendingTestNotification = $state(false);
  let registeringWebhook = $state(false);
  let triggeringRefinement = $state(false);

  // Helper function to check if model supports thinking
  function modelSupportsThinking(modelId) {
    for (const models of Object.values(grouped_models)) {
      const found = models.find((m) => m.model_id === modelId);
      if (found) return found.supports_thinking === true;
    }
    return false;
  }

  let form = useForm({
    agent: {
      name: agent.name,
      system_prompt: agent.system_prompt || '',
      reflection_prompt: agent.reflection_prompt || '',
      memory_reflection_prompt: agent.memory_reflection_prompt || '',
      model_id: agent.model_id,
      active: agent.active,
      enabled_tools: agent.enabled_tools || [],
      colour: agent.colour || null,
      icon: agent.icon || null,
      thinking_enabled: agent.thinking_enabled || false,
      thinking_budget: agent.thinking_budget || 10000,
      telegram_bot_username: agent.telegram_bot_username || '',
      telegram_bot_token: agent.telegram_bot_token || '',
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
      router.delete(`/accounts/${account.id}/agents/${agent.id}/memories/${memoryId}`, {
        preserveScroll: true,
      });
    }
  }

  function triggerRefinement() {
    triggeringRefinement = true;
    router.post(
      `/accounts/${account.id}/agents/${agent.id}/trigger_refinement`,
      {},
      {
        preserveScroll: true,
        onFinish() {
          triggeringRefinement = false;
        },
      }
    );
  }

  function toggleConstitutional(memoryId) {
    router.patch(
      `/accounts/${account.id}/agents/${agent.id}/memories/${memoryId}/toggle_constitutional`,
      {},
      { preserveScroll: true }
    );
  }

  function sendTestNotification() {
    sendingTestNotification = true;
    router.post(
      sendTestTelegramAccountAgentPath(account.id, agent.id),
      {},
      {
        preserveScroll: true,
        onFinish() {
          sendingTestNotification = false;
        },
      }
    );
  }

  function registerWebhook() {
    registeringWebhook = true;
    router.post(
      registerTelegramWebhookAccountAgentPath(account.id, agent.id),
      {},
      {
        preserveScroll: true,
        onFinish() {
          registeringWebhook = false;
        },
      }
    );
  }

  let showNewMemoryForm = $state(false);
  let newMemoryContent = $state('');
  let newMemoryType = $state('core');

  function getJournalOpacity(memory) {
    if (memory.memory_type !== 'journal') return 1;
    if (memory.expired) return 0.3;
    return Math.max(0.3, 1 - memory.age_in_days * 0.1);
  }

  function createMemory() {
    if (!newMemoryContent.trim()) return;

    router.post(
      `/accounts/${account.id}/agents/${agent.id}/memories`,
      {
        memory: {
          content: newMemoryContent,
          memory_type: newMemoryType,
        },
      },
      {
        preserveScroll: true,
      }
    );

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

          <div class="space-y-2">
            <Label for="reflection_prompt">Reflection Prompt</Label>
            <textarea
              id="reflection_prompt"
              bind:value={$form.agent.reflection_prompt}
              placeholder="Leave empty to use default reflection prompt"
              rows="8"
              class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
                     focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
            <p class="text-xs text-muted-foreground">
              Customize how the agent reflects on conversations to extract memories. Leave empty to use the default
              prompt. The prompt can use %{'{'}system_prompt{'}'} and %{'{'}existing_memories{'}'} placeholders.
            </p>
          </div>

          <div class="space-y-2">
            <Label for="memory_reflection_prompt">Memory Reflection Prompt</Label>
            <textarea
              id="memory_reflection_prompt"
              bind:value={$form.agent.memory_reflection_prompt}
              placeholder="Leave empty to use default memory reflection prompt"
              rows="8"
              class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
                     focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
            <p class="text-xs text-muted-foreground">
              Customize how the agent reviews journal entries to promote them to core memories. Leave empty to use the
              default prompt. The prompt can use %{'{'}core_memories{'}'} and %{'{'}journal_entries{'}'} placeholders.
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
          <CardTitle>Extended Thinking</CardTitle>
          <CardDescription>Allow the model to show its reasoning process before responding</CardDescription>
        </CardHeader>
        <CardContent class="space-y-4">
          {#if modelSupportsThinking(selectedModel)}
            <div class="flex items-center justify-between">
              <div class="space-y-1">
                <Label for="thinking_enabled">Enable Thinking</Label>
                <p class="text-sm text-muted-foreground">Show the model's reasoning process in responses</p>
              </div>
              <Switch
                id="thinking_enabled"
                checked={$form.agent.thinking_enabled}
                onCheckedChange={(checked) => ($form.agent.thinking_enabled = checked)} />
            </div>

            {#if $form.agent.thinking_enabled}
              <div class="space-y-2">
                <Label for="thinking_budget">Thinking Budget (tokens)</Label>
                <Input
                  id="thinking_budget"
                  type="number"
                  min={1000}
                  max={50000}
                  step={1000}
                  bind:value={$form.agent.thinking_budget}
                  class="max-w-xs" />
                <p class="text-xs text-muted-foreground">Maximum tokens for reasoning (1,000 - 50,000)</p>
              </div>
            {/if}
          {:else}
            <p class="text-sm text-muted-foreground py-4">
              The selected model does not support extended thinking. Choose Claude 4+, GPT-5, or Gemini 3 Pro to enable
              this feature.
            </p>
          {/if}
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
          <CardTitle>Telegram Notifications</CardTitle>
          <CardDescription>
            Connect a Telegram bot to send notifications when this agent initiates conversations or replies.
          </CardDescription>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="space-y-2">
            <Label for="telegram_bot_username">Bot Username</Label>
            <Input
              id="telegram_bot_username"
              type="text"
              bind:value={$form.agent.telegram_bot_username}
              placeholder="e.g., my_agent_bot" />
            <p class="text-xs text-muted-foreground">
              Create a bot via <a
                href="https://t.me/botfather"
                target="_blank"
                rel="noopener noreferrer"
                class="underline">@BotFather</a> on Telegram, then paste the username here.
            </p>
          </div>

          <div class="space-y-2">
            <Label for="telegram_bot_token">Bot Token</Label>
            <Input
              id="telegram_bot_token"
              type="password"
              bind:value={$form.agent.telegram_bot_token}
              placeholder="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11" />
            <p class="text-xs text-muted-foreground">The API token provided by BotFather. Stored encrypted.</p>
          </div>

          {#if agent.telegram_configured}
            <div class="p-3 rounded-lg bg-muted/50 space-y-2">
              <p class="text-sm font-medium">Your Registration Link</p>
              <p class="text-xs text-muted-foreground">
                Use this to connect your own Telegram account for testing. Other users will see their own link in the
                chat UI.
              </p>
              <code class="text-xs block p-2 bg-background rounded border break-all">
                {telegramDeepLink}
              </code>
            </div>

            <div class="p-3 rounded-lg bg-muted/50 space-y-2">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium">Test Notifications</p>
                  <p class="text-xs text-muted-foreground">
                    {telegramSubscriberCount} subscriber{telegramSubscriberCount === 1 ? '' : 's'} connected
                  </p>
                </div>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  disabled={sendingTestNotification || telegramSubscriberCount === 0}
                  onclick={sendTestNotification}>
                  {sendingTestNotification ? 'Sending...' : 'Send Test Notification'}
                </Button>
              </div>
            </div>

            <div class="p-3 rounded-lg bg-muted/50 space-y-2">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium">Webhook</p>
                  <p class="text-xs text-muted-foreground">
                    Re-register the webhook if Telegram isn't receiving updates.
                  </p>
                </div>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  disabled={registeringWebhook}
                  onclick={registerWebhook}>
                  {registeringWebhook ? 'Registering...' : 'Re-register Webhook'}
                </Button>
              </div>
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
            <div class="flex gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={triggeringRefinement}
                onclick={triggerRefinement}>
                <Lightning class="size-4 mr-1" />
                {triggeringRefinement ? 'Queuing...' : 'Refine Memories'}
              </Button>
              {#if !showNewMemoryForm}
                <Button type="button" variant="outline" size="sm" onclick={() => (showNewMemoryForm = true)}>
                  <Plus class="size-4 mr-1" />
                  Add Memory
                </Button>
              {/if}
            </div>
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
                  class="memory-card flex items-start gap-3 p-3 rounded-lg border
                    {memory.expired ? 'border-dashed' : 'border-border'}"
                  style="--memory-opacity: {getJournalOpacity(memory)}">
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
                      {#if memory.constitutional}
                        <span class="text-xs font-medium uppercase text-primary flex items-center gap-0.5">
                          <ShieldCheck size={10} weight="fill" /> protected
                        </span>
                      {/if}
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
                    onclick={() => toggleConstitutional(memory.id)}
                    class="flex-shrink-0 p-1 transition-colors {memory.constitutional
                      ? 'text-primary'
                      : 'text-muted-foreground hover:text-primary'}"
                    title={memory.constitutional
                      ? 'Constitutional (protected from deletion)'
                      : 'Mark as constitutional'}>
                    {#if memory.constitutional}
                      <ShieldCheck size={16} weight="fill" />
                    {:else}
                      <Shield size={16} />
                    {/if}
                  </button>
                  {#if !memory.constitutional}
                    <button
                      type="button"
                      onclick={() => deleteMemory(memory.id)}
                      class="flex-shrink-0 p-1 text-muted-foreground hover:text-destructive transition-colors">
                      <Trash size={16} />
                    </button>
                  {/if}
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

<style>
  .memory-card {
    opacity: var(--memory-opacity, 1);
    transition: opacity 150ms ease-in-out;
  }

  .memory-card:hover {
    opacity: 1;
  }
</style>
