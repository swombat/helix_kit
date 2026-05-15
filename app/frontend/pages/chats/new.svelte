<script>
  import { router } from '@inertiajs/svelte';
  import ChatList from './ChatList.svelte';
  import GroupChatAgentPicker from '$lib/components/chat/GroupChatAgentPicker.svelte';
  import NewChatComposer from '$lib/components/chat/NewChatComposer.svelte';
  import NewChatEmptyState from '$lib/components/chat/NewChatEmptyState.svelte';
  import NewChatHeader from '$lib/components/chat/NewChatHeader.svelte';
  import NewChatSettingsBar from '$lib/components/chat/NewChatSettingsBar.svelte';
  import { accountChatsPath } from '@/routes';

  let { chats = [], account, models = [], agents = [], file_upload_config = null } = $props();

  const defaultConversationMode =
    account?.default_conversation_mode === 'agents' && agents.length > 0 ? 'agents' : 'model';
  const activeAgentIds = () => agents.filter((agent) => agent.active !== false).map((agent) => agent.id);

  let selectedModel = $state(models?.[0]?.model_id ?? '');
  let conversationMode = $state(defaultConversationMode);
  let previousConversationMode = $state(defaultConversationMode);
  let selectedAgentIds = $state(defaultConversationMode === 'agents' ? activeAgentIds() : []);
  let isGroupChat = $derived(conversationMode === 'agents');
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

  $effect(() => {
    if (conversationMode === previousConversationMode) return;

    if (conversationMode === 'agents') {
      selectedAgentIds = activeAgentIds();
    }

    if (conversationMode === 'model') {
      selectedAgentIds = [];
      webAccess = false;
    }

    previousConversationMode = conversationMode;
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
    <NewChatHeader onMenuOpen={() => (sidebarOpen = true)} />

    <NewChatSettingsBar {models} {agents} bind:selectedModel bind:conversationMode bind:webAccess />

    <!-- Agent selection for group chat -->
    {#if isGroupChat && agents.length > 0}
      <GroupChatAgentPicker {agents} bind:selectedAgentIds />
    {/if}

    <NewChatEmptyState />

    <NewChatComposer
      bind:selectedFiles
      bind:message
      bind:textareaRef
      fileUploadConfig={file_upload_config}
      {processing}
      {isGroupChat}
      {selectedAgentIds}
      {placeholder}
      onSubmit={startChat}
      onKeydown={handleKeydown}
      onInput={autoResize} />
  </main>
</div>
