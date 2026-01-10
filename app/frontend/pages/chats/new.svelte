<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import {
    ArrowUp,
    Globe,
    Robot,
    UsersThree,
    List,
    Brain,
    Sparkle,
    Lightning,
    Star,
    Heart,
    Sun,
    Moon,
    Eye,
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

  // Map icon names to components
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
  import * as Select from '$lib/components/shadcn/select/index.js';
  import ChatList from './ChatList.svelte';
  import FileUploadInput from '$lib/components/chat/FileUploadInput.svelte';
  import { accountChatsPath } from '@/routes';

  let { chats = [], account, models = [], agents = [], file_upload_config = null } = $props();

  let selectedModel = $state(models?.[0]?.model_id ?? '');
  let selectedAgent = $state(null); // Will hold the agent object if an agent is selected from dropdown
  let isGroupChat = $state(false);
  let selectedAgentIds = $state([]);
  let sidebarOpen = $state(false);
  let textareaRef = $state(null);
  // Random placeholder (10% chance for the tip)
  const placeholder =
    Math.random() < 0.1
      ? 'Did you know? Press shift-enter for a new line...'
      : 'Type your message to start the chat...';

  // Group models by their group property
  const groupedModels = $derived(() => {
    const groups = {};
    const groupOrder = [];
    for (const model of models) {
      const group = model.group || 'Other';
      if (!groups[group]) {
        groups[group] = [];
        groupOrder.push(group);
      }
      groups[group].push(model);
    }
    return { groups, groupOrder };
  });
  let selectedFiles = $state([]);
  let webAccess = $state(false);
  let message = $state('');
  let processing = $state(false);

  function toggleAgent(agentId) {
    if (selectedAgentIds.includes(agentId)) {
      selectedAgentIds = selectedAgentIds.filter((id) => id !== agentId);
    } else {
      selectedAgentIds = [...selectedAgentIds, agentId];
    }
  }

  // Handle selection from the combined dropdown (agents + models)
  function handleSelection(value) {
    if (value.startsWith('agent:')) {
      const agentId = value.replace('agent:', '');
      selectedAgent = agents.find((a) => a.id === agentId) || null;
      // Use the agent's model_id for the chat
      if (selectedAgent) {
        selectedModel = selectedAgent.model_id;
        // Clear group chat mode since we're using the dropdown shortcut
        isGroupChat = false;
        selectedAgentIds = [];
      }
    } else {
      selectedAgent = null;
      selectedModel = value;
    }
  }

  // When enabling group chat mode, clear the dropdown agent selection
  function toggleGroupChat() {
    isGroupChat = !isGroupChat;
    if (isGroupChat) {
      selectedAgent = null;
    } else {
      selectedAgentIds = [];
    }
  }

  // Get the current selection value for the dropdown
  const selectionValue = $derived(selectedAgent ? `agent:${selectedAgent.id}` : selectedModel);

  // Get display label for current selection
  const selectionLabel = $derived(() => {
    if (selectedAgent) {
      return selectedAgent.name;
    }
    return models.find((model) => model.model_id === selectedModel)?.label || 'Select AI model';
  });

  function handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      startChat();
    }
  }

  function autoResize() {
    if (!textareaRef) return;
    textareaRef.style.height = 'auto';
    textareaRef.style.height = `${Math.min(textareaRef.scrollHeight, 240)}px`;
  }

  function startChat() {
    if (!message.trim() && selectedFiles.length === 0) return;
    if (isGroupChat && selectedAgentIds.length === 0) return;
    if (processing) return;

    processing = true;

    // Use FormData to include files
    const formData = new FormData();
    formData.append('chat[model_id]', selectedModel);
    formData.append('chat[web_access]', webAccess.toString());
    formData.append('message', message);

    // Append each file
    selectedFiles.forEach((file) => {
      formData.append('files[]', file);
    });

    // If an agent is selected from dropdown, create a group chat with that single agent
    if (selectedAgent) {
      formData.append('agent_ids[]', selectedAgent.id);
    }
    // If group chat mode with manually selected agents
    else if (isGroupChat) {
      selectedAgentIds.forEach((agentId) => {
        formData.append('agent_ids[]', agentId);
      });
    }

    router.post(accountChatsPath(account.id), formData, {
      onSuccess: () => {
        message = '';
        selectedFiles = [];
        processing = false;
        if (textareaRef) textareaRef.style.height = 'auto';
      },
      onError: (errors) => {
        console.error('Chat creation failed:', errors);
        processing = false;
      },
    });
  }
</script>

<svelte:head>
  <title>New Chat</title>
</svelte:head>

<div class="flex h-[calc(100dvh-4rem)]">
  <!-- Left sidebar: Chat list -->
  <ChatList
    {chats}
    activeChatId={null}
    accountId={account.id}
    {selectedModel}
    isOpen={sidebarOpen}
    onClose={() => (sidebarOpen = false)} />

  <!-- Right side: New chat form -->
  <main class="flex-1 flex flex-col bg-background">
    <!-- Header -->
    <header class="border-b border-border bg-muted/30 px-4 md:px-6 py-3 md:py-4">
      <div class="flex items-center gap-3">
        <Button variant="ghost" size="sm" onclick={() => (sidebarOpen = true)} class="h-8 w-8 p-0 md:hidden">
          <List size={20} />
        </Button>
        <h1 class="text-lg font-semibold">New Chat</h1>
      </div>
      <div class="mt-2 ml-0 md:ml-0">
        {#if Array.isArray(models) && models.length > 0}
          <Select.Root type="single" value={selectionValue} onValueChange={handleSelection}>
            <Select.Trigger class="w-56">
              {#if selectedAgent}
                {@const IconComponent = iconComponents[selectedAgent.icon] || Robot}
                <span class="flex items-center gap-2">
                  <IconComponent
                    size={14}
                    weight="duotone"
                    class={selectedAgent.colour
                      ? `text-${selectedAgent.colour}-600 dark:text-${selectedAgent.colour}-400`
                      : ''} />
                  {selectedAgent.name}
                </span>
              {:else}
                {selectionLabel()}
              {/if}
            </Select.Trigger>
            <Select.Content sideOffset={4} class="max-h-80">
              <!-- Agents section (if any exist) -->
              {#if agents.length > 0}
                <Select.Group>
                  <Select.GroupHeading class="px-2 py-1.5 text-xs font-semibold text-muted-foreground">
                    Agents
                  </Select.GroupHeading>
                  {#each agents as agent (agent.id)}
                    {@const IconComponent = iconComponents[agent.icon] || Robot}
                    <Select.Item value={`agent:${agent.id}`} label={agent.name}>
                      <span class="flex items-center gap-2">
                        <IconComponent
                          size={14}
                          weight="duotone"
                          class={agent.colour ? `text-${agent.colour}-600 dark:text-${agent.colour}-400` : ''} />
                        {agent.name}
                      </span>
                    </Select.Item>
                  {/each}
                </Select.Group>
              {/if}
              <!-- Models section -->
              {#each groupedModels().groupOrder as groupName}
                <Select.Group>
                  <Select.GroupHeading class="px-2 py-1.5 text-xs font-semibold text-muted-foreground">
                    {groupName}
                  </Select.GroupHeading>
                  {#each groupedModels().groups[groupName] as model (model.model_id)}
                    <Select.Item value={model.model_id} label={model.label}>
                      {model.label}
                    </Select.Item>
                  {/each}
                </Select.Group>
              {/each}
            </Select.Content>
          </Select.Root>
        {/if}
      </div>
    </header>

    <!-- Settings bar with web access toggle and group chat option -->
    <div class="border-b border-border px-4 md:px-6 py-2 bg-muted/10 flex flex-wrap items-center gap-3 md:gap-6">
      <label class="flex items-center gap-2 cursor-pointer hover:opacity-80 transition-opacity w-fit">
        <input
          type="checkbox"
          bind:checked={webAccess}
          class="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
        <Globe size={16} class="text-muted-foreground" weight="duotone" />
        <span class="text-sm text-muted-foreground">Allow web access</span>
      </label>

      {#if agents.length > 0}
        <label class="flex items-center gap-2 cursor-pointer hover:opacity-80 transition-opacity w-fit">
          <input
            type="checkbox"
            checked={isGroupChat}
            onchange={toggleGroupChat}
            class="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
          <UsersThree size={16} class="text-muted-foreground" weight="duotone" />
          <span class="text-sm text-muted-foreground">Group chat with agents</span>
        </label>
      {/if}
    </div>

    <!-- Agent selection for group chat -->
    {#if isGroupChat && agents.length > 0}
      <div class="border-b border-border px-4 md:px-6 py-3 bg-muted/5">
        <div class="text-sm font-medium mb-2">Select agents to participate:</div>
        <div class="flex flex-wrap gap-2">
          {#each agents as agent (agent.id)}
            {@const IconComponent = iconComponents[agent.icon] || Robot}
            {@const isSelected = selectedAgentIds.includes(agent.id)}
            <button
              type="button"
              onclick={() => toggleAgent(agent.id)}
              class="inline-flex items-center gap-2 px-3 py-1.5 rounded-md text-sm border transition-colors
                     {isSelected
                ? agent.colour
                  ? `bg-${agent.colour}-100 dark:bg-${agent.colour}-900 border-${agent.colour}-400 dark:border-${agent.colour}-600 text-${agent.colour}-700 dark:text-${agent.colour}-300`
                  : 'bg-primary text-primary-foreground border-primary'
                : agent.colour
                  ? `bg-transparent border-${agent.colour}-300 dark:border-${agent.colour}-700 hover:bg-${agent.colour}-50 dark:hover:bg-${agent.colour}-950 text-${agent.colour}-600 dark:text-${agent.colour}-400`
                  : 'bg-muted hover:bg-muted/80 text-muted-foreground border-border'}">
              <IconComponent
                size={14}
                weight="duotone"
                class={agent.colour && !isSelected ? `text-${agent.colour}-600 dark:text-${agent.colour}-400` : ''} />
              {agent.name}
            </button>
          {/each}
        </div>
        {#if selectedAgentIds.length === 0}
          <p class="text-xs text-amber-600 mt-2">Select at least one agent to start a group chat</p>
        {/if}
      </div>
    {/if}

    <!-- Empty state -->
    <div class="flex-1 flex items-center justify-center px-4 md:px-6 py-4">
      <div class="text-center text-muted-foreground max-w-md">
        <h2 class="text-xl font-semibold mb-2">Start a new conversation</h2>
        <p>Select a model or agent above and type your first message below to begin.</p>
      </div>
    </div>

    <!-- Message input -->
    <div class="border-t border-border bg-muted/30 p-3 md:p-4">
      <div class="flex gap-2 md:gap-3 items-start">
        <FileUploadInput
          bind:files={selectedFiles}
          disabled={processing}
          allowedTypes={file_upload_config?.acceptable_types || []}
          allowedExtensions={file_upload_config?.acceptable_extensions || []}
          maxSize={file_upload_config?.max_size || 52428800} />

        <div class="flex-1">
          <textarea
            bind:this={textareaRef}
            bind:value={message}
            onkeydown={handleKeydown}
            oninput={autoResize}
            {placeholder}
            disabled={processing}
            class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                   focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent
                   min-h-[40px] max-h-[240px] overflow-y-auto"
            rows="1"></textarea>
        </div>
        <button
          onclick={startChat}
          disabled={(!message.trim() && selectedFiles.length === 0) ||
            processing ||
            (isGroupChat && selectedAgentIds.length === 0)}
          class="h-10 w-10 p-0 inline-flex items-center justify-center rounded-md bg-primary text-primary-foreground hover:bg-primary/90">
          <ArrowUp size={16} />
        </button>
      </div>
    </div>
  </main>
</div>
