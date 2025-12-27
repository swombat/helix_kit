<script>
  import { page } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { createDynamicSync, streamingSync } from '$lib/use-sync';
  import { router } from '@inertiajs/svelte';
  import { onMount, onDestroy } from 'svelte';
  import { createConsumer } from '@rails/actioncable';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Badge } from '$lib/components/shadcn/badge/index.js';
  import { ArrowUp, ArrowClockwise, Spinner, Globe, List } from 'phosphor-svelte';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import ChatList from './ChatList.svelte';
  import FileUploadInput from '$lib/components/chat/FileUploadInput.svelte';
  import FileAttachment from '$lib/components/chat/FileAttachment.svelte';
  import AgentTriggerBar from '$lib/components/chat/AgentTriggerBar.svelte';
  import { accountChatMessagesPath, retryMessagePath } from '@/routes';
  import { marked } from 'marked';
  import * as logging from '$lib/logging';
  import { formatTime, formatDate, formatDateTime } from '$lib/utils';
  import { fade } from 'svelte/transition';
  import { Streamdown } from 'svelte-streamdown';

  // Format tools_used for display - extracts domain from URLs or cleans up legacy format
  function formatToolsUsed(toolsUsed) {
    if (!toolsUsed || toolsUsed.length === 0) return [];

    return toolsUsed.map((tool) => {
      // Handle legacy Ruby object strings like "#<RubyLLM/tool call:0x...>"
      if (tool.startsWith('#<')) {
        return 'Web access';
      }

      // Try to extract domain from URL
      try {
        const url = new URL(tool);
        return url.hostname;
      } catch {
        // Not a valid URL, return as-is
        return tool;
      }
    });
  }

  // Generate bubble background class based on author colour
  function getBubbleClass(colour) {
    if (!colour) return '';
    return `bg-${colour}-100 dark:bg-${colour}-900`;
  }

  // Create ActionCable consumer
  const consumer = typeof window !== 'undefined' ? createConsumer() : null;

  let { chat, chats = [], messages = [], account, models = [], agents = [], file_upload_config = {} } = $props();

  let selectedModel = $state(models?.[0]?.model_id ?? '');
  let messageInput = $state('');
  let selectedFiles = $state([]);
  let messagesContainer;
  let waitingForResponse = $state(false);
  let messageSentAt = $state(null);
  let currentTime = $state(Date.now());
  let timeoutCheckInterval;
  let showToolCalls = $state(false);
  // Brief "select an agent" prompt for group chats after sending a message
  let showAgentPrompt = $state(false);
  // Mobile sidebar state
  let sidebarOpen = $state(false);

  // Check if current user is a site admin
  const isSiteAdmin = $derived($page.props.user?.site_admin ?? false);

  // Filter out tool messages and empty assistant messages unless showToolCalls is enabled
  const visibleMessages = $derived(
    showToolCalls
      ? messages
      : messages.filter((m) => {
          // Hide tool messages
          if (m.role === 'tool') return false;
          // Hide empty assistant messages (these appear before tool calls)
          if (m.role === 'assistant' && (!m.content || m.content.trim() === '') && !m.streaming) return false;
          // Hide assistant messages that are raw tool results (JSON objects)
          // These are stored as assistant role but contain tool call output
          if (m.role === 'assistant' && m.content && m.content.trim().startsWith('{') && !m.streaming) return false;
          return true;
        })
  );

  // Count unique human participants in group chats
  const uniqueHumanCount = $derived(() => {
    if (!messages || messages.length === 0) return 0;
    const humanNames = new Set(messages.filter((m) => m.role === 'user' && m.author_name).map((m) => m.author_name));
    return humanNames.size;
  });

  // Check if the last actual message is hidden (tool call or empty assistant) - model is still thinking
  const lastMessageIsHiddenThinking = $derived(() => {
    if (!messages || messages.length === 0) return false;
    const lastMessage = messages[messages.length - 1];
    if (!lastMessage) return false;
    // Tool message means model is processing tool results
    if (lastMessage.role === 'tool') return true;
    // Empty assistant message (not streaming) means waiting for tool call
    if (
      lastMessage.role === 'assistant' &&
      (!lastMessage.content || lastMessage.content.trim() === '') &&
      !lastMessage.streaming
    )
      return true;
    // JSON tool result message (not streaming) means tool just completed
    if (
      lastMessage.role === 'assistant' &&
      lastMessage.content &&
      lastMessage.content.trim().startsWith('{') &&
      !lastMessage.streaming
    )
      return true;
    return false;
  });

  // Check if the last message is a user message without a response
  const lastMessageIsUserWithoutResponse = $derived(() => {
    if (!messages || messages.length === 0) return false;
    const lastMessage = messages[messages.length - 1];
    return lastMessage && lastMessage.role === 'user';
  });

  // Auto-detect waiting state based on messages
  // Don't show for manual_responses chats (group chats) since they don't auto-respond
  const shouldShowSendingPlaceholder = $derived(
    !chat?.manual_responses && (waitingForResponse || lastMessageIsUserWithoutResponse())
  );

  // Get the timestamp of when the last user message was sent
  const lastUserMessageTime = $derived(() => {
    if (!messages || messages.length === 0) return null;
    const lastMessage = messages[messages.length - 1];
    if (lastMessage && lastMessage.role === 'user') {
      return new Date(lastMessage.created_at).getTime();
    }
    return null;
  });

  // Check if we've been waiting too long (over 1 minute)
  const isTimedOut = $derived(() => {
    const messageTime = messageSentAt || lastUserMessageTime();
    return shouldShowSendingPlaceholder && messageTime && currentTime - messageTime > 60000;
  });

  // Check if last message needs resend option
  const lastUserMessageNeedsResend = $derived(() => {
    if (!messages || messages.length === 0) return false;
    const lastMessage = messages[messages.length - 1];
    if (!lastMessage || lastMessage.role !== 'user') return false;

    // Check if there's been more than 1 minute since message was created
    const createdAt = new Date(lastMessage.created_at).getTime();
    return currentTime - createdAt > 60000;
  });

  // Create dynamic sync for real-time updates
  const updateSync = createDynamicSync();
  let syncSignature = null;

  // Set up timer to check for timeouts
  onMount(() => {
    if (messagesContainer) {
      messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }

    // Set up interval to check for timeouts
    timeoutCheckInterval = setInterval(() => {
      currentTime = Date.now();
    }, 5000); // Check every 5 seconds
  });

  onDestroy(() => {
    if (timeoutCheckInterval) {
      clearInterval(timeoutCheckInterval);
    }
  });

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

    // Clear waiting state if an assistant message appeared
    if (waitingForResponse && messages.length > 0) {
      const lastMessage = messages[messages.length - 1];
      if (lastMessage.role === 'assistant') {
        waitingForResponse = false;
        messageSentAt = null;
      }
    }

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

    if (!$messageForm.message.content.trim() && selectedFiles.length === 0) {
      logging.debug('Empty message and no files, returning');
      return;
    }

    const formData = new FormData();
    formData.append('message[content]', $messageForm.message.content);
    selectedFiles.forEach((file) => formData.append('files[]', file));

    // Track that we're waiting for response (only for non-manual_responses chats)
    if (!chat?.manual_responses) {
      waitingForResponse = true;
      messageSentAt = Date.now();
    }

    router.post(accountChatMessagesPath(account.id, chat.id), formData, {
      onSuccess: () => {
        logging.debug('Message sent successfully');
        $messageForm.message.content = '';
        selectedFiles = [];

        // For group chats, show the agent prompt briefly
        if (chat?.manual_responses) {
          showAgentPrompt = true;
          setTimeout(() => {
            showAgentPrompt = false;
          }, 3000); // Hide after 3 seconds
        }
      },
      onError: (errors) => {
        logging.error('Message send failed:', errors);
        waitingForResponse = false;
        messageSentAt = null;
      },
    });
  }

  function retryMessage(messageId) {
    $retryForm.post(retryMessagePath(messageId));
  }

  function resendLastMessage() {
    // Find the last user message and retry the AI response
    logging.debug('resendLastMessage called, messages:', messages?.length);
    if (messages && messages.length > 0) {
      // Find the actual last user message (may not be the very last message if AI started responding)
      const lastUserMessage = [...messages].reverse().find((m) => m.role === 'user');
      logging.debug('lastUserMessage:', lastUserMessage);
      if (lastUserMessage) {
        // Retry the AI response for this message
        const retryPath = retryMessagePath(lastUserMessage.id);
        logging.debug('Posting to retry path:', retryPath);
        waitingForResponse = true;
        messageSentAt = Date.now();

        $retryForm.post(retryPath, {
          onSuccess: () => {
            logging.debug('Retry triggered successfully');
          },
          onError: (errors) => {
            logging.error('Retry failed:', errors);
            waitingForResponse = false;
            messageSentAt = null;
          },
        });
      } else {
        logging.error('No user message found to retry');
      }
    } else {
      logging.error('No messages available for retry');
    }
  }

  function toggleWebAccess() {
    if (!chat) return;

    router.patch(
      `/accounts/${account.id}/chats/${chat.id}`,
      {
        chat: { web_access: !chat.web_access },
      },
      {
        preserveScroll: true,
        preserveState: true,
        onSuccess: () => {
          logging.debug('Web access toggled successfully');
        },
        onError: (errors) => {
          logging.error('Failed to toggle web access:', errors);
        },
      }
    );
  }

  function handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }

  function shouldShowTimestamp(index) {
    if (
      !Array.isArray(visibleMessages) ||
      visibleMessages.length === 0 ||
      visibleMessages[index] === undefined ||
      Number.isNaN(new Date(visibleMessages[index].created_at))
    ) {
      return false;
    }

    const message = visibleMessages[index];
    const currentCreatedAt = new Date(message.created_at);

    if (index === 0) return true;

    const previousMessage = visibleMessages[index - 1];
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
    const message = visibleMessages[index];
    if (!message) return '';

    const createdAt = new Date(message.created_at);
    if (Number.isNaN(createdAt)) return '';

    if (index === 0) return formatDate(createdAt);

    const previousMessage = visibleMessages[index - 1];
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
  <ChatList
    {chats}
    activeChatId={chat?.id}
    accountId={account.id}
    {selectedModel}
    isOpen={sidebarOpen}
    onClose={() => (sidebarOpen = false)} />

  <!-- Right side: Chat messages -->
  <main class="flex-1 flex flex-col bg-background">
    <!-- Chat header -->
    <header class="border-b border-border bg-muted/30 px-4 md:px-6 py-3 md:py-4">
      <div class="flex items-center gap-3">
        <Button variant="ghost" size="sm" onclick={() => (sidebarOpen = true)} class="h-8 w-8 p-0 md:hidden">
          <List size={20} />
        </Button>
        <div class="flex-1 min-w-0">
          <h1 class="text-lg font-semibold truncate">
            {chat?.title || 'New Chat'}
          </h1>
          <div class="text-sm text-muted-foreground">
            {#if chat?.manual_responses}
              {agents?.length || 0} AI{agents?.length === 1 ? '' : 's'}, {uniqueHumanCount()} human{uniqueHumanCount() ===
              1
                ? ''
                : 's'}
            {:else}
              {chat?.model_label || chat?.model_id || 'Auto'}
            {/if}
          </div>
        </div>
      </div>
    </header>

    <!-- Settings bar with web access toggle -->
    {#if chat && (!chat.manual_responses || isSiteAdmin)}
      <div class="border-b border-border px-4 md:px-6 py-2 bg-muted/10 flex flex-wrap items-center gap-3 md:gap-6">
        {#if !chat.manual_responses}
          <label class="flex items-center gap-2 cursor-pointer hover:opacity-80 transition-opacity w-fit">
            <input
              type="checkbox"
              checked={chat.web_access}
              onchange={toggleWebAccess}
              class="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
            <Globe size={16} class="text-muted-foreground" weight="duotone" />
            <span class="text-sm text-muted-foreground">Allow web access</span>
          </label>
        {/if}

        {#if isSiteAdmin}
          <label class="flex items-center gap-2 cursor-pointer hover:opacity-80 transition-opacity w-fit">
            <input
              type="checkbox"
              bind:checked={showToolCalls}
              class="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
            <span class="text-sm text-muted-foreground">Show tool calls</span>
          </label>
        {/if}
      </div>
    {/if}

    <!-- Messages container -->
    <div bind:this={messagesContainer} class="flex-1 overflow-y-auto px-3 md:px-6 py-4 space-y-4">
      {#if !Array.isArray(visibleMessages) || visibleMessages.length === 0}
        <div class="flex items-center justify-center h-full">
          <div class="text-center text-muted-foreground">
            <p>Start the conversation by sending a message below.</p>
          </div>
        </div>
      {:else}
        {#each visibleMessages as message, index (message.id)}
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
                <div class="max-w-[85%] md:max-w-[70%]">
                  <Card.Root class={getBubbleClass(message.author_colour)}>
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
                    {#if chat?.manual_responses && message.author_name}
                      <span class="ml-1">· {message.author_name}</span>
                    {/if}
                    {#if index === visibleMessages.length - 1 && lastUserMessageNeedsResend() && !waitingForResponse}
                      <button onclick={resendLastMessage} class="ml-2 text-blue-600 hover:text-blue-700 underline">
                        Resend
                      </button>
                    {/if}
                  </div>
                </div>
              </div>
            {:else}
              <div class="flex justify-start">
                <div class="max-w-[85%] md:max-w-[70%]">
                  <Card.Root class={getBubbleClass(message.author_colour)}>
                    <Card.Content class="p-4">
                      {#if message.status === 'failed'}
                        <div class="text-red-600 mb-2 text-sm">Failed to generate response</div>
                        <Button variant="outline" size="sm" onclick={() => retryMessage(message.id)} class="mb-3">
                          <ArrowClockwise size={14} class="mr-2" />
                          Retry
                        </Button>
                      {:else if message.status === 'pending'}
                        <div class="text-muted-foreground text-sm">Thinking...</div>
                      {:else if message.streaming && (!message.content || message.content.trim() === '')}
                        <div class="flex items-center gap-2 text-muted-foreground">
                          <Spinner size={16} class="animate-spin" />
                          <span class="text-sm">{message.tool_status || 'Generating response...'}</span>
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

                      {#if message.tools_used && message.tools_used.length > 0}
                        <div class="flex items-center gap-2 mt-3 pt-3 border-t border-border/50">
                          <Globe size={14} class="text-muted-foreground" weight="duotone" />
                          <div class="flex flex-wrap gap-1">
                            {#each formatToolsUsed(message.tools_used) as tool}
                              <Badge variant="secondary" class="text-xs">
                                {tool}
                              </Badge>
                            {/each}
                          </div>
                        </div>
                      {/if}
                    </Card.Content>
                  </Card.Root>
                  <div class="text-xs text-muted-foreground mt-1">
                    {#if chat?.manual_responses && message.author_name}
                      <span class="mr-1">{message.author_name} ·</span>
                    {/if}
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

        <!-- Thinking bubble when last message is hidden (tool call or empty assistant) -->
        {#if !showToolCalls && lastMessageIsHiddenThinking()}
          {@const lastMessage = messages[messages.length - 1]}
          <div class="flex justify-start">
            <div class="max-w-[85%] md:max-w-[70%]">
              <Card.Root>
                <Card.Content class="p-4">
                  <div class="flex items-center gap-2 text-muted-foreground">
                    <Spinner size={16} class="animate-spin" />
                    <span class="text-sm">{lastMessage?.tool_status || 'Thinking...'}</span>
                  </div>
                </Card.Content>
              </Card.Root>
            </div>
          </div>
        {/if}

        <!-- Sending message placeholder (show while waiting for assistant response) -->
        {#if shouldShowSendingPlaceholder}
          <div class="flex justify-start">
            <div class="max-w-[85%] md:max-w-[70%]">
              <Card.Root>
                <Card.Content class="p-4">
                  {#if isTimedOut()}
                    <div class="text-red-600 text-sm mb-2">
                      It appears there might have been an error while sending the message.
                    </div>
                    <Button variant="outline" size="sm" onclick={resendLastMessage}>
                      <ArrowClockwise size={14} class="mr-2" />
                      Try again
                    </Button>
                  {:else}
                    <div class="flex items-center gap-2 text-muted-foreground">
                      <Spinner size={16} class="animate-spin" />
                      <span class="text-sm">Sending message...</span>
                    </div>
                  {/if}
                </Card.Content>
              </Card.Root>
            </div>
          </div>
        {/if}

        <!-- Agent prompt for group chats after sending a message -->
        {#if showAgentPrompt && chat?.manual_responses}
          <div class="flex justify-start" transition:fade={{ duration: 200 }}>
            <div class="max-w-[85%] md:max-w-[70%]">
              <Card.Root class="border-dashed border-2 border-muted-foreground/30 bg-muted/20">
                <Card.Content class="p-4">
                  <div class="text-muted-foreground text-sm">Please select an agent to respond</div>
                </Card.Content>
              </Card.Root>
            </div>
          </div>
        {/if}
      {/if}
    </div>

    <!-- Agent trigger bar for group chats -->
    {#if chat?.manual_responses && agents?.length > 0}
      <AgentTriggerBar {agents} accountId={account.id} chatId={chat.id} />
    {/if}

    <!-- Message input -->
    <div class="border-t border-border bg-muted/30 p-3 md:p-4">
      <div class="flex gap-2 md:gap-3 items-start">
        <FileUploadInput
          bind:files={selectedFiles}
          disabled={$messageForm.processing}
          allowedTypes={file_upload_config.acceptable_types || []}
          maxSize={file_upload_config.max_size || 50 * 1024 * 1024} />

        <div class="flex-1">
          <textarea
            bind:value={$messageForm.message.content}
            onkeydown={handleKeydown}
            placeholder="Type your message..."
            disabled={$messageForm.processing}
            class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                   focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent
                   min-h-[40px] max-h-[120px]"
            rows="1"></textarea>
        </div>
        <button
          onclick={sendMessage}
          disabled={(!$messageForm.message.content.trim() && selectedFiles.length === 0) || $messageForm.processing}
          class="h-10 w-10 p-0 inline-flex items-center justify-center rounded-md bg-primary text-primary-foreground hover:bg-primary/90 disabled:pointer-events-none disabled:opacity-50">
          <ArrowUp size={16} />
        </button>
      </div>
    </div>
  </main>
</div>
