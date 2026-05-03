<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { ArrowUp, Globe, UsersThree, List } from 'phosphor-svelte';
  import ChatList from './ChatList.svelte';
  import FileUploadInput from '$lib/components/chat/FileUploadInput.svelte';
  import ChatTargetSelect from '$lib/components/chat/ChatTargetSelect.svelte';
  import GroupChatAgentPicker from '$lib/components/chat/GroupChatAgentPicker.svelte';
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

  let selectedFiles = $state([]);
  let webAccess = $state(false);
  let message = $state('');
  let processing = $state(false);

  // When enabling group chat mode, clear the dropdown agent selection
  function toggleGroupChat() {
    isGroupChat = !isGroupChat;
    if (isGroupChat) {
      selectedAgent = null;
    } else {
      selectedAgentIds = [];
    }
  }

  function clearGroupChatSelection() {
    isGroupChat = false;
    selectedAgentIds = [];
  }

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
        <ChatTargetSelect
          {models}
          {agents}
          bind:selectedModel
          bind:selectedAgent
          onAgentSelected={clearGroupChatSelection} />
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
      <GroupChatAgentPicker {agents} bind:selectedAgentIds />
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
