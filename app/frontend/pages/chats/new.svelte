<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { ArrowUp, Globe, Robot, UsersThree } from 'phosphor-svelte';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import ChatList from './ChatList.svelte';
  import FileUploadInput from '$lib/components/chat/FileUploadInput.svelte';
  import { accountChatsPath } from '@/routes';

  let { chats = [], account, models = [], agents = [], file_upload_config = null } = $props();

  let selectedModel = $state(models?.[0]?.model_id ?? '');
  let isGroupChat = $state(false);
  let selectedAgentIds = $state([]);

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

  function handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      startChat();
    }
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

    // Append agent IDs for group chat
    if (isGroupChat) {
      selectedAgentIds.forEach((agentId) => {
        formData.append('agent_ids[]', agentId);
      });
    }

    router.post(accountChatsPath(account.id), formData, {
      onSuccess: () => {
        message = '';
        selectedFiles = [];
        processing = false;
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

<div class="flex h-[calc(100vh-4rem)]">
  <!-- Left sidebar: Chat list -->
  <ChatList {chats} activeChatId={null} accountId={account.id} {selectedModel} />

  <!-- Right side: New chat form -->
  <main class="flex-1 flex flex-col bg-background">
    <!-- Header -->
    <header class="border-b border-border bg-muted/30 px-6 py-4">
      <h1 class="text-lg font-semibold">New Chat</h1>
      <div class="mt-2">
        {#if Array.isArray(models) && models.length > 0}
          <Select.Root
            type="single"
            value={selectedModel}
            onValueChange={(value) => {
              selectedModel = value;
            }}>
            <Select.Trigger class="w-56">
              {models.find((model) => model.model_id === selectedModel)?.label || 'Select AI model'}
            </Select.Trigger>
            <Select.Content sideOffset={4} class="max-h-80">
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
    <div class="border-b border-border px-6 py-2 bg-muted/10 flex items-center gap-6">
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
            bind:checked={isGroupChat}
            class="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
          <UsersThree size={16} class="text-muted-foreground" weight="duotone" />
          <span class="text-sm text-muted-foreground">Group chat with agents</span>
        </label>
      {/if}
    </div>

    <!-- Agent selection for group chat -->
    {#if isGroupChat && agents.length > 0}
      <div class="border-b border-border px-6 py-3 bg-muted/5">
        <div class="text-sm font-medium mb-2">Select agents to participate:</div>
        <div class="flex flex-wrap gap-2">
          {#each agents as agent (agent.id)}
            <button
              type="button"
              onclick={() => toggleAgent(agent.id)}
              class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm transition-colors
                     {selectedAgentIds.includes(agent.id)
                ? 'bg-primary text-primary-foreground'
                : 'bg-muted hover:bg-muted/80 text-muted-foreground'}">
              <Robot size={14} weight="duotone" />
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
    <div class="flex-1 flex items-center justify-center px-6 py-4">
      <div class="text-center text-muted-foreground max-w-md">
        <h2 class="text-xl font-semibold mb-2">Start a new conversation</h2>
        <p>Select a model above and type your first message below to begin.</p>
      </div>
    </div>

    <!-- Message input -->
    <div class="border-t border-border bg-muted/30 p-4">
      <div class="flex gap-3 items-start">
        <FileUploadInput
          bind:files={selectedFiles}
          disabled={processing}
          allowedTypes={file_upload_config?.acceptable_types || []}
          maxSize={file_upload_config?.max_size || 52428800} />

        <div class="flex-1">
          <textarea
            bind:value={message}
            onkeydown={handleKeydown}
            placeholder="Type your message to start the chat..."
            disabled={processing}
            class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                   focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent
                   min-h-[40px] max-h-[120px]"
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
