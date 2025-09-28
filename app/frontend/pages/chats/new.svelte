<script>
  import { useForm } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { ArrowUp } from 'phosphor-svelte';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import ChatList from './ChatList.svelte';
  import { accountChatsPath } from '@/routes';

  let { chats = [], account, models = [] } = $props();

  let selectedModel = $state(models?.[0]?.model_id ?? '');

  let createForm = useForm({
    chat: {
      model_id: selectedModel,
    },
    message: '',
  });

  function handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      startChat();
    }
  }

  function startChat() {
    if (!$createForm.message.trim()) return;

    $createForm.chat.model_id = selectedModel;
    $createForm.post(accountChatsPath(account.id));
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
            <Select.Content sideOffset={4}>
              {#each models as model (model.model_id)}
                <Select.Item value={model.model_id} label={model.label}>
                  {model.label}
                </Select.Item>
              {/each}
            </Select.Content>
          </Select.Root>
        {/if}
      </div>
    </header>

    <!-- Empty state -->
    <div class="flex-1 flex items-center justify-center px-6 py-4">
      <div class="text-center text-muted-foreground max-w-md">
        <h2 class="text-xl font-semibold mb-2">Start a new conversation</h2>
        <p>Select a model above and type your first message below to begin.</p>
      </div>
    </div>

    <!-- Message input -->
    <div class="border-t border-border bg-muted/30 p-4">
      <div class="flex gap-3 items-end">
        <div class="flex-1">
          <textarea
            bind:value={$createForm.message}
            onkeydown={handleKeydown}
            placeholder="Type your message to start the chat..."
            disabled={$createForm.processing}
            class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                   focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent
                   min-h-[40px] max-h-[120px]"
            rows="1"></textarea>
        </div>
        <Button
          on:click={startChat}
          disabled={!$createForm.message.trim() || $createForm.processing}
          size="sm"
          class="h-10 w-10 p-0">
          <ArrowUp size={16} />
        </Button>
      </div>
    </div>
  </main>
</div>
