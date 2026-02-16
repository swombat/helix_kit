<script>
  import { useForm, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import {
    ArrowLeft,
    Brain,
    BookOpen,
    Warning,
    Trash,
    Plus,
    Shield,
    ShieldCheck,
    Lightning,
    ArrowCounterClockwise,
    MagnifyingGlass,
    IdentificationCard,
    Palette,
    Cpu,
    Plug,
    Notebook,
    Hourglass,
  } from 'phosphor-svelte';
  import {
    accountAgentsPath,
    accountAgentPath,
    accountAgentTelegramTestPath,
    accountAgentTelegramWebhookPath,
    accountAgentRefinementPath,
    accountAgentMemoriesPath,
    accountAgentMemoryDiscardPath,
    accountAgentMemoryProtectionPath,
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

  useSync({
    [`Agent:${agent.id}`]: ['agent', 'memories'],
  });

  let selectedModel = $state(agent.model_id);
  let sendingTestNotification = $state(false);
  let registeringWebhook = $state(false);
  let triggeringRefinement = $state(false);
  let activeTab = $state('identity');

  const tabs = [
    { id: 'identity', label: 'Identity', icon: IdentificationCard },
    { id: 'appearance', label: 'Appearance', icon: Palette },
    { id: 'model', label: 'Model', icon: Cpu },
    { id: 'integrations', label: 'Integrations', icon: Plug },
    { id: 'memory', label: 'Memory', icon: Notebook },
  ];

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
      summary_prompt: agent.summary_prompt || '',
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
    if (confirm('Discard this memory?')) {
      router.post(
        accountAgentMemoryDiscardPath(account.id, agent.id, memoryId),
        {},
        {
          preserveScroll: true,
        }
      );
    }
  }

  function undiscardMemory(memoryId) {
    router.delete(accountAgentMemoryDiscardPath(account.id, agent.id, memoryId), { preserveScroll: true });
  }

  function triggerRefinement() {
    triggeringRefinement = true;
    router.post(
      accountAgentRefinementPath(account.id, agent.id),
      {},
      {
        preserveScroll: true,
        onFinish() {
          triggeringRefinement = false;
        },
      }
    );
  }

  function toggleConstitutional(memoryId, isCurrentlyProtected) {
    if (isCurrentlyProtected) {
      router.delete(accountAgentMemoryProtectionPath(account.id, agent.id, memoryId), { preserveScroll: true });
    } else {
      router.post(accountAgentMemoryProtectionPath(account.id, agent.id, memoryId), {}, { preserveScroll: true });
    }
  }

  function sendTestNotification() {
    sendingTestNotification = true;
    router.post(
      accountAgentTelegramTestPath(account.id, agent.id),
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
      accountAgentTelegramWebhookPath(account.id, agent.id),
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
  let memorySearch = $state('');
  let showCore = $state(true);
  let showJournal = $state(true);
  let showProtected = $state(true);
  let showDiscarded = $state(false);

  let filteredMemories = $derived.by(() => {
    const search = memorySearch.toLowerCase();
    return memories.filter((m) => {
      if (m.discarded && !showDiscarded) return false;
      if (m.memory_type === 'core' && !m.constitutional && !showCore) return false;
      if (m.memory_type === 'journal' && !showJournal) return false;
      if (m.constitutional && !showProtected) return false;
      if (search && !m.content.toLowerCase().includes(search)) return false;
      return true;
    });
  });

  function getJournalOpacity(memory) {
    if (memory.memory_type !== 'journal') return 1;
    if (memory.expired) return 0.3;
    return Math.max(0.3, 1 - memory.age_in_days * 0.1);
  }

  function createMemory() {
    if (!newMemoryContent.trim()) return;

    router.post(
      accountAgentMemoriesPath(account.id, agent.id),
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

    newMemoryContent = '';
    newMemoryType = 'core';
    showNewMemoryForm = false;
  }
</script>

<svelte:head>
  <title>Edit {agent.name}</title>
</svelte:head>

<div class="p-8 max-w-5xl mx-auto">
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
    <div class="flex flex-col md:flex-row gap-6 md:gap-8">
      <!-- Tabs: dropdown on small, horizontal scroll on medium, vertical sidebar on large -->
      <nav class="md:w-48 md:flex-shrink-0">
        <!-- Small: dropdown selector -->
        <div class="sm:hidden">
          <Select.Root type="single" value={activeTab} onValueChange={(value) => (activeTab = value)}>
            <Select.Trigger class="w-full">
              {tabs.find((t) => t.id === activeTab)?.label}
            </Select.Trigger>
            <Select.Content>
              {#each tabs as tab (tab.id)}
                <Select.Item value={tab.id} label={tab.label}>{tab.label}</Select.Item>
              {/each}
            </Select.Content>
          </Select.Root>
        </div>
        <!-- Medium: horizontal scroll -->
        <div
          class="hidden sm:flex md:flex-col md:sticky md:top-8 gap-1 overflow-x-auto pb-2 md:pb-0 border-b md:border-b-0 border-border">
          {#each tabs as tab (tab.id)}
            <button
              type="button"
              onclick={() => (activeTab = tab.id)}
              class="flex items-center gap-2 px-3 py-2 text-sm rounded-md transition-colors whitespace-nowrap
                {activeTab === tab.id
                ? 'bg-primary text-primary-foreground font-medium'
                : 'text-muted-foreground hover:text-foreground hover:bg-muted'}">
              <tab.icon size={18} weight={activeTab === tab.id ? 'fill' : 'regular'} />
              {tab.label}
            </button>
          {/each}
        </div>
      </nav>

      <!-- Content area -->
      <div class="flex-1 min-w-0 space-y-6">
        {#if activeTab === 'identity'}
          <div class="space-y-6">
            <div>
              <h2 class="text-lg font-semibold">Agent Identity</h2>
              <p class="text-sm text-muted-foreground">Define the agent's name and personality</p>
            </div>

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

            <div class="space-y-2">
              <Label for="summary_prompt">Summary Prompt</Label>
              <textarea
                id="summary_prompt"
                bind:value={$form.agent.summary_prompt}
                placeholder="Leave empty to use default summary prompt (focus on state, 2 lines)"
                rows="6"
                class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
                       focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
              <p class="text-xs text-muted-foreground">
                Customize how this agent summarizes conversations for cross-conversation awareness. Leave empty for the
                default prompt that focuses on current state rather than narrative.
              </p>
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
          </div>
        {:else if activeTab === 'appearance'}
          <div class="space-y-6">
            <div>
              <h2 class="text-lg font-semibold">Chat Appearance</h2>
              <p class="text-sm text-muted-foreground">Customise how this agent appears in group chats</p>
            </div>

            <ColourPicker bind:value={$form.agent.colour} options={colour_options} label="Chat Bubble Colour" />
            <IconPicker
              bind:value={$form.agent.icon}
              options={icon_options}
              colour={$form.agent.colour}
              label="Agent Icon" />
          </div>
        {:else if activeTab === 'model'}
          <div class="space-y-8">
            <div class="space-y-4">
              <div>
                <h2 class="text-lg font-semibold">AI Model</h2>
                <p class="text-sm text-muted-foreground">Choose which AI model powers this agent</p>
              </div>
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
            </div>

            <div class="space-y-4">
              <div>
                <h2 class="text-lg font-semibold">Extended Thinking</h2>
                <p class="text-sm text-muted-foreground">
                  Allow the model to show its reasoning process before responding
                </p>
              </div>
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
                <p class="text-sm text-muted-foreground">
                  The selected model does not support extended thinking. Choose Claude 4+, GPT-5, or Gemini 3 Pro to
                  enable this feature.
                </p>
              {/if}
            </div>

            <div class="space-y-4">
              <div>
                <h2 class="text-lg font-semibold">Tools & Capabilities</h2>
                <p class="text-sm text-muted-foreground">
                  Select which tools this agent can use. New tools will be disabled by default.
                </p>
              </div>
              {#if available_tools.length === 0}
                <p class="text-sm text-muted-foreground">
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
            </div>
          </div>
        {:else if activeTab === 'integrations'}
          <div class="space-y-6">
            <div>
              <h2 class="text-lg font-semibold">Telegram Notifications</h2>
              <p class="text-sm text-muted-foreground">
                Connect a Telegram bot to send notifications when this agent initiates conversations or replies.
              </p>
            </div>

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
          </div>
        {:else if activeTab === 'memory'}
          <div class="space-y-6">
            <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
              <div>
                <h2 class="text-lg font-semibold">Agent Memory</h2>
                <p class="text-sm text-muted-foreground">
                  Review and manage this agent's memories. Core memories are permanent; journal entries fade after a
                  week.
                </p>
              </div>
              <div class="flex flex-col sm:flex-row gap-2">
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

            {#if showNewMemoryForm}
              <div class="p-4 border rounded-lg bg-muted/30 space-y-4">
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
                      <input
                        type="radio"
                        name="memory_type"
                        value="journal"
                        bind:group={newMemoryType}
                        class="w-4 h-4" />
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
              <p class="text-sm text-muted-foreground">
                This agent has no memories yet. Click "Add Memory" to create one manually, or memories will appear here
                as the agent creates them using the save_memory tool.
              </p>
            {:else if memories.length > 0}
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

              {#if filteredMemories.length === 0}
                <p class="text-sm text-muted-foreground py-4">No memories match your filters.</p>
              {:else}
                <div class="text-xs text-muted-foreground flex flex-wrap items-center gap-x-3 gap-y-0.5">
                  <span>Showing {filteredMemories.length} of {memories.length} memories</span>
                  {#if agent.memory_token_summary}
                    {@const mts = agent.memory_token_summary}
                    <span class="flex items-center gap-1">
                      <Brain size={12} weight="duotone" class="lg:hidden text-primary" />
                      <span class="hidden lg:inline font-medium">Core:</span>
                      {mts.core.toLocaleString()}t
                    </span>
                    <span class="flex items-center gap-1">
                      <BookOpen size={12} weight="duotone" class="lg:hidden text-muted-foreground" />
                      <span class="hidden lg:inline font-medium">Journal:</span>
                      {mts.active_journal.toLocaleString()}t
                    </span>
                    {#if mts.inactive_journal > 0}
                      <span class="flex items-center gap-1 opacity-50">
                        <Hourglass size={12} weight="duotone" class="lg:hidden" />
                        <span class="hidden lg:inline font-medium">Inactive:</span>
                        {mts.inactive_journal.toLocaleString()}t
                      </span>
                    {/if}
                  {/if}
                </div>
              {/if}

              <div class="space-y-3 max-h-[32rem] overflow-y-auto">
                {#each filteredMemories as memory (memory.id)}
                  <div
                    class="memory-card flex items-start gap-3 p-3 rounded-lg border
                      {memory.expired ? 'border-dashed' : 'border-border'}
                      {memory.discarded ? 'border-l-4 border-l-destructive opacity-60' : ''}"
                    style="--memory-opacity: {memory.discarded ? 0.6 : getJournalOpacity(memory)}">
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
                        {#if memory.discarded}
                          <span class="text-xs font-medium uppercase text-destructive">discarded</span>
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
                    {#if memory.discarded}
                      <button
                        type="button"
                        onclick={() => undiscardMemory(memory.id)}
                        class="flex-shrink-0 p-1 text-muted-foreground hover:text-primary transition-colors"
                        title="Restore memory">
                        <ArrowCounterClockwise size={16} />
                      </button>
                    {:else}
                      <button
                        type="button"
                        onclick={() => toggleConstitutional(memory.id, memory.constitutional)}
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
                    {/if}
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        {/if}

        <div class="flex justify-end gap-3">
          <a href={accountAgentsPath(account.id)}>
            <Button type="button" variant="outline">Cancel</Button>
          </a>
          <Button type="submit" disabled={$form.processing}>
            {$form.processing ? 'Saving...' : 'Update Agent'}
          </Button>
        </div>
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
