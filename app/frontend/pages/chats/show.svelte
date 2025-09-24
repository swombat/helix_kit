<script>
  import { page } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { createDynamicSync } from '$lib/use-sync';
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { ArrowUp, ArrowClockwise } from 'phosphor-svelte';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import ChatList from './ChatList.svelte';
  import { accountChatMessagesPath, retryMessagePath } from '@/routes';

  let { chat, chats = [], messages = [], account } = $props();
  let messageInput = $state('');
  let messagesContainer;

  console.log('chat:', chat);
  console.log('chats:', chats);
  console.log('messages:', messages);
  console.log('account:', account);

  // Create dynamic sync for real-time updates
  const updateSync = createDynamicSync();

  // Set up real-time subscriptions
  $effect(() => {
    const subs = {}
    subs[`Account:${account.id}:chats`] = 'chats';

    if (chat) {
      subs[`Chat:${chat.id}`] = 'chat'; // Current chat updates
      subs[`Chat:${chat.id}:messages`] = 'messages'; // Messages updates
    }

    updateSync(subs);
    if (messages.length !== chat.message_count) {
      console.log('messages length vs chat messages count mismatch:', messages.length, chat.message_count);
      router.reload({
        only: ['messages'],
        preserveState: true,
        preserveScroll: true,
      });
    }
  });

  // Auto-scroll to bottom when messages change
  $effect(() => {
    messages; // Subscribe to messages changes
    if (messagesContainer) {
      setTimeout(() => {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      }, 100);
    }
  });

  // Initialize the form with the structure the controller expects
  let messageForm = useForm({
    message: {
      content: '',
    },
  });

  const retryForm = useForm({});

  function sendMessage() {
    console.log('messageForm:', $messageForm);
    if (!$messageForm.message.content.trim()) {
      console.log('Empty message, returning');
      return;
    }

    console.log('Preparing to send message');

    $messageForm.post(accountChatMessagesPath(account.id, chat.id), {
      onSuccess: () => {
        console.log('Message sent successfully');
        $messageForm.message.content = '';
      },
      onError: (errors) => {
        console.error('Message send failed:', errors);
      },
    });
  }

  function retryMessage(messageId) {
    $retryForm.post(retryMessagePath(messageId));
  }

  function handleKeydown(event) {
    console.log('Key pressed:', event.key, 'shiftKey:', event.shiftKey);
    if (event.key === 'Enter' && !event.shiftKey) {
      console.log('Enter key pressed, preventing default and sending message');
      event.preventDefault();
      sendMessage();
    }
  }

  function formatTime(dateString) {
    return new Date(dateString).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: true,
    });
  }

  function formatDate(value) {
    if (!value) return '';

    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date)) return '';

    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    if (date.toDateString() === today.toDateString()) {
      return 'Today';
    } else if (date.toDateString() === yesterday.toDateString()) {
      return 'Yesterday';
    } else {
      return date.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: date.getFullYear() !== today.getFullYear() ? 'numeric' : undefined,
      });
    }
  }

  // Group messages chronologically by calendar date
  let groupedMessages = $derived(() => {
    if (!Array.isArray(messages) || messages.length === 0) return [];

    const sortedMessages = [...messages].sort(
      (a, b) => new Date(a.created_at) - new Date(b.created_at)
    );

    const groups = [];
    const groupIndex = new Map();

    sortedMessages.forEach((message) => {
      const createdAt = new Date(message.created_at);
      if (Number.isNaN(createdAt)) return;

      const groupId = createdAt.toISOString().split('T')[0];
      let group = groupIndex.get(groupId);

      if (!group) {
        group = {
          id: groupId,
          date: createdAt,
          dateLabel: formatDate(createdAt),
          messages: [],
        };
        groupIndex.set(groupId, group);
        groups.push(group);
      }

      group.messages.push(message);
    });

    return groups;
  });
</script>

<svelte:head>
  <title>{chat?.title || 'Chat'}</title>
</svelte:head>

<div class="flex h-[calc(100vh-4rem)]">
  <!-- Left sidebar: Chat list -->
  <ChatList {chats} activeChatId={chat?.id} accountId={account.id} />

  <!-- Right side: Chat messages -->
  <main class="flex-1 flex flex-col bg-background">
    <!-- Chat header -->
    <header class="border-b border-border bg-muted/30 px-6 py-4">
      <h1 class="text-lg font-semibold truncate">
        {chat?.title || 'New Chat'}
      </h1>
      <div class="text-sm text-muted-foreground">
        {chat?.ai_model_name}
      </div>
    </header>

    <!-- Messages container -->
    <div bind:this={messagesContainer} class="flex-1 overflow-y-auto px-6 py-4 space-y-4">
      {#if groupedMessages().length === 0}
        <div class="flex items-center justify-center h-full">
          <div class="text-center text-muted-foreground">
            <p>Start the conversation by sending a message below.</p>
          </div>
        </div>
      {:else}
        {#each groupedMessages() as group (group.id)}
          <!-- Date separator -->
          <div class="flex items-center gap-4 my-6">
            <div class="flex-1 border-t border-border"></div>
            <div class="px-3 py-1 bg-muted rounded-full text-xs font-medium text-muted-foreground">
              {group.dateLabel}
            </div>
            <div class="flex-1 border-t border-border"></div>
          </div>

          <!-- Messages for this date -->
          {#each group.messages as message (message.id)}
            <div class="space-y-1">
              <!-- User message -->
              {#if message.role === 'user'}
                <div class="flex justify-end">
                  <div class="max-w-[70%]">
                    <Card.Root class="bg-primary text-primary-foreground">
                      <Card.Content class="p-4">
                        <div class="whitespace-pre-wrap break-words">{message.content}</div>
                      </Card.Content>
                    </Card.Root>
                    <div class="text-xs text-muted-foreground text-right mt-1">
                      {formatTime(message.created_at)}
                    </div>
                  </div>
                </div>
              {:else}
                <!-- Assistant message -->
                <div class="flex justify-start">
                  <div class="max-w-[70%]">
                    <Card.Root>
                      <Card.Content class="p-4">
                        {#if message.status === 'failed'}
                          <div class="text-red-600 mb-2 text-sm">Failed to generate response</div>
                          <Button variant="outline" size="sm" on:click={() => retryMessage(message.id)} class="mb-3">
                            <ArrowClockwise size={14} class="mr-2" />
                            Retry
                          </Button>
                        {:else if message.status === 'pending'}
                          <div class="text-muted-foreground text-sm">Thinking...</div>
                        {:else if message.content_html}
                          <!-- Server-rendered HTML content -->
                          <div class="prose prose-sm max-w-none">
                            {@html message.content_html}
                          </div>
                        {:else}
                          <div class="whitespace-pre-wrap break-words">{message.content || ''}</div>
                        {/if}
                      </Card.Content>
                    </Card.Root>
                    <div class="text-xs text-muted-foreground mt-1">
                      {formatTime(message.created_at)}
                      {#if message.status === 'pending'}
                        <span class="ml-2 text-blue-600">●</span>
                      {/if}
                    </div>
                  </div>
                </div>
              {/if}
            </div>
          {/each}
        {/each}
      {/if}
    </div>

    <!-- Message input -->
    <div class="border-t border-border bg-muted/30 p-4">
      <div class="flex gap-3 items-end">
        <div class="flex-1">
          <textarea
            bind:value={$messageForm.message.content}
            on:keydown={handleKeydown}
            placeholder="Type your message..."
            disabled={messageForm.processing}
            class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                   focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent
                   min-h-[40px] max-h-[120px]"
            rows="1"></textarea>
        </div>
        <Button
          on:click={sendMessage}
          disabled={!messageInput.trim() || messageForm.processing}
          size="sm"
          class="h-10 w-10 p-0">
          <ArrowUp size={16} />
        </Button>
      </div>
    </div>
  </main>
</div>
