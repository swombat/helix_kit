<script>
  import { page } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { createDynamicSync, streamingSync } from '$lib/use-sync';
  import { router } from '@inertiajs/svelte';
  import { onMount } from 'svelte';
  import { createConsumer } from '@rails/actioncable';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { ArrowUp, ArrowClockwise, Spinner } from 'phosphor-svelte';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import ChatList from './ChatList.svelte';
  import FileUploadInput from '$lib/components/chat/FileUploadInput.svelte';
  import FileAttachment from '$lib/components/chat/FileAttachment.svelte';
  import { accountChatMessagesPath, retryMessagePath } from '@/routes';
  import { marked } from 'marked';
  import * as logging from '$lib/logging';
  import { formatTime, formatDate, formatDateTime } from '$lib/utils';
  import { fade } from 'svelte/transition';
  import { Streamdown } from 'svelte-streamdown';

  // Create ActionCable consumer
  const consumer = typeof window !== 'undefined' ? createConsumer() : null;

  let { chat, chats = [], messages = [], account, models = [], file_upload_config = {} } = $props();

  let selectedModel = $state(models?.[0]?.model_id ?? '');
  let messageInput = $state('');
  let selectedFiles = $state([]);
  let messagesContainer;

  // Create dynamic sync for real-time updates
  const updateSync = createDynamicSync();
  let syncSignature = null;

  // Set up real-time subscriptions
  $effect(() => {
    const subs = {};
    subs[`Account:${account.id}:chats`] = 'chats';

    if (chat) {
      subs[`Chat:${chat.id}`] = 'chat'; // Current chat updates
      subs[`Chat:${chat.id}:messages`] = 'messages'; // Messages updates (not including streaming)
    }

    const messageSignature = Array.isArray(messages) ? messages.map((message) => message.id).join(':') : '';
    const nextSignature = `${account.id}|${chat?.id ?? 'none'}|${messageSignature}`;

    if (nextSignature !== syncSignature) {
      syncSignature = nextSignature;
      updateSync(subs);
    }

    // If the messages length does not match the chat messages count, reload the page
    if (chat && messages.length !== chat.message_count) {
      logging.debug('Reloading: messages length vs chat messages count mismatch:', messages.length, chat.message_count);
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

  streamingSync(
    (data) => {
      if (data.id) {
        const index = messages.findIndex((m) => m.id === data.id);
        if (index !== -1) {
          logging.debug('✏️ Updating message via streaming:', data.id, data.chunk);
          const currentMessage = messages[index] || {};
          const updatedMessage = {
            ...currentMessage,
            content: `${currentMessage.content || ''}${data.chunk || ''}`,
            streaming: true,
          };

          messages = messages.map((message, messageIndex) => (messageIndex === index ? updatedMessage : message));
          logging.debug('Message updated:', updatedMessage);
        } else {
          logging.debug('🔍 No message found in streaming update:', data.id);
          logging.debug('🔍 Messages:', messages);
        }
      } else {
        logging.warn('🔍 No id found in streaming update:', data);
      }
    },
    (data) => {
      if (data.id) {
        const index = messages.findIndex((m) => m.id === data.id);
        if (index !== -1) {
          logging.debug('✏️ Updating message via streaming end:', data.id);
          messages = messages.map((message, messageIndex) =>
            messageIndex === index ? { ...message, streaming: false } : message
          );
        }
      } else {
        logging.warn('🔍 No id found in streaming end:', data);
      }
    }
  );

  // Initialize the form with the structure the controller expects
  let messageForm = useForm({
    message: {
      content: '',
      model_id: selectedModel,
    },
  });

  const retryForm = useForm({});

  function sendMessage() {
    logging.debug('messageForm:', $messageForm);
    $messageForm.message.model_id = selectedModel;

    if (!$messageForm.message.content.trim() && selectedFiles.length === 0) {
      logging.debug('Empty message and no files, returning');
      return;
    }

    const formData = new FormData();
    formData.append('message[content]', $messageForm.message.content);
    formData.append('message[model_id]', selectedModel);
    selectedFiles.forEach((file) => formData.append('files[]', file));

    router.post(accountChatMessagesPath(account.id, chat.id), formData, {
      onSuccess: () => {
        logging.debug('Message sent successfully');
        $messageForm.message.content = '';
        selectedFiles = [];
      },
      onError: (errors) => {
        logging.error('Message send failed:', errors);
      },
    });
  }

  function retryMessage(messageId) {
    $retryForm.post(retryMessagePath(messageId));
  }

  function handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }

  function shouldShowTimestamp(index) {
    if (
      !Array.isArray(messages) ||
      messages.length === 0 ||
      messages[index] === undefined ||
      Number.isNaN(new Date(messages[index].created_at))
    ) {
      return false;
    }

    const message = messages[index];
    const currentCreatedAt = new Date(message.created_at);

    if (index === 0) return true;

    const previousMessage = messages[index - 1];
    if (!previousMessage) return true;

    const previousCreatedAt = new Date(previousMessage.created_at);
    if (Number.isNaN(previousCreatedAt)) return true;

    const sameDay = currentCreatedAt.toDateString() === previousCreatedAt.toDateString();
    if (!sameDay) return true;

    const timeDifference = currentCreatedAt.getTime() - previousCreatedAt.getTime();
    const hourInMs = 60 * 60 * 1000;

    return timeDifference >= hourInMs;
  }

  function timestampLabel(index) {
    const message = messages[index];
    if (!message) return '';

    const createdAt = new Date(message.created_at);
    if (Number.isNaN(createdAt)) return '';

    if (index === 0) return formatDate(createdAt);

    const previousMessage = messages[index - 1];
    const previousCreatedAt = previousMessage ? new Date(previousMessage.created_at) : null;

    if (!previousCreatedAt || Number.isNaN(previousCreatedAt)) {
      return formatDate(createdAt);
    }

    if (createdAt.toDateString() !== previousCreatedAt.toDateString()) {
      return formatDate(createdAt);
    }

    return formatTime(createdAt);
  }
</script>

<svelte:head>
  <title>{chat?.title || 'Chat'}</title>
</svelte:head>

<div class="flex h-[calc(100vh-4rem)]">
  <!-- Left sidebar: Chat list -->
  <ChatList {chats} activeChatId={chat?.id} accountId={account.id} {selectedModel} />

  <!-- Right side: Chat messages -->
  <main class="flex-1 flex flex-col bg-background">
    <!-- Chat header -->
    <header class="border-b border-border bg-muted/30 px-6 py-4">
      <h1 class="text-lg font-semibold truncate">
        {chat?.title || 'New Chat'}
      </h1>
      <div class="mt-2">
        <div class="text-sm text-muted-foreground">
          {chat?.model_name || chat?.model_id || 'Auto'}
        </div>
      </div>
    </header>

    <!-- Messages container -->
    <div bind:this={messagesContainer} class="flex-1 overflow-y-auto px-6 py-4 space-y-4">
      {#if !Array.isArray(messages) || messages.length === 0}
        <div class="flex items-center justify-center h-full">
          <div class="text-center text-muted-foreground">
            <p>Start the conversation by sending a message below.</p>
          </div>
        </div>
      {:else}
        {#each messages as message, index (message.id)}
          {#if shouldShowTimestamp(index)}
            <div class="flex items-center gap-4 my-6">
              <div class="flex-1 border-t border-border"></div>
              <div class="px-3 py-1 bg-muted rounded-full text-xs font-medium text-muted-foreground">
                {timestampLabel(index)}
              </div>
              <div class="flex-1 border-t border-border"></div>
            </div>
          {/if}

          <div class="space-y-1">
            {#if message.role === 'user'}
              <div class="flex justify-end">
                <div class="max-w-[70%]">
                  <Card.Root class="bg-indigo-200">
                    <Card.Content class="p-4">
                      {#if message.files_json && message.files_json.length > 0}
                        <div class="space-y-2 mb-3">
                          {#each message.files_json as file}
                            <FileAttachment {file} />
                          {/each}
                        </div>
                      {/if}
                      <Streamdown
                        content={message.content}
                        parseIncompleteMarkdown
                        baseTheme="shadcn"
                        class="prose"
                        animation={{
                          enabled: true,
                          type: 'fade',
                          tokenize: 'word',
                          duration: 300,
                          timingFunction: 'ease-out',
                          animateOnMount: false,
                        }} />
                    </Card.Content>
                  </Card.Root>
                  <div class="text-xs text-muted-foreground text-right mt-1">
                    <span class="group">
                      <span class="hidden group-hover:inline-block">({formatDateTime(message.created_at, true)})</span>
                      {formatTime(message.created_at)}
                    </span>
                  </div>
                </div>
              </div>
            {:else}
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
                      {:else if message.streaming && (!message.content || message.content.trim() === '')}
                        <div class="flex items-center gap-2 text-muted-foreground">
                          <Spinner size={16} class="animate-spin" />
                          <span class="text-sm">Generating response...</span>
                        </div>
                      {:else}
                        <Streamdown
                          content={message.content}
                          parseIncompleteMarkdown
                          baseTheme="shadcn"
                          class="prose"
                          animation={{
                            enabled: true,
                            type: 'fade',
                            tokenize: 'word', // <- key for typewriter feel
                            duration: 300, // tune to taste
                            timingFunction: 'ease-out',
                            animateOnMount: true, // animate the first batch too
                          }} />
                      {/if}
                    </Card.Content>
                  </Card.Root>
                  <div class="text-xs text-muted-foreground mt-1">
                    <span class="group">
                      {formatTime(message.created_at)}
                      <span class="hidden group-hover:inline-block">({formatDateTime(message.created_at, true)})</span>
                    </span>
                    {#if message.status === 'pending'}
                      <span class="ml-2 text-blue-600">●</span>
                    {:else if message.streaming}
                      <span class="ml-2 text-green-600 animate-pulse">●</span>
                    {/if}
                  </div>
                </div>
              </div>
            {/if}
          </div>
        {/each}
      {/if}
    </div>

    <!-- Message input -->
    <div class="border-t border-border bg-muted/30 p-4">
      <div class="flex gap-3 items-start">
        <FileUploadInput
          bind:files={selectedFiles}
          disabled={messageForm.processing}
          allowedTypes={file_upload_config.acceptable_types || []}
          maxSize={file_upload_config.max_size || 50 * 1024 * 1024} />

        <div class="flex-1">
          <textarea
            bind:value={$messageForm.message.content}
            onkeydown={handleKeydown}
            placeholder="Type your message..."
            disabled={messageForm.processing}
            class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                   focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent
                   min-h-[40px] max-h-[120px]"
            rows="1"></textarea>
        </div>
        <Button
          onclick={sendMessage}
          disabled={(!$messageForm.message.content.trim() && selectedFiles.length === 0) || messageForm.processing}
          size="sm"
          class="h-10 w-10 p-0">
          <ArrowUp size={16} />
        </Button>
      </div>
    </div>
  </main>
</div>
