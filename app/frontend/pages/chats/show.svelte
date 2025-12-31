<script>
  import { page } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { createDynamicSync, streamingSync } from '$lib/use-sync';
  import { router } from '@inertiajs/svelte';
  import { onMount, onDestroy } from 'svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Badge } from '$lib/components/shadcn/badge/index.js';
  import { ArrowUp, ArrowClockwise, Spinner, Globe, List, GitFork } from 'phosphor-svelte';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import ChatList from './ChatList.svelte';
  import FileUploadInput from '$lib/components/chat/FileUploadInput.svelte';
  import FileAttachment from '$lib/components/chat/FileAttachment.svelte';
  import AgentTriggerBar from '$lib/components/chat/AgentTriggerBar.svelte';
  import ParticipantAvatars from '$lib/components/chat/ParticipantAvatars.svelte';
  import { accountChatMessagesPath, retryMessagePath, forkAccountChatPath } from '@/routes';
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

  // Browser check for event listeners
  const browser = typeof window !== 'undefined';

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
  let debugMode = $state(false);
  let debugLogs = $state([]);
  // Brief "select an agent" prompt for group chats after sending a message
  let showAgentPrompt = $state(false);
  // Mobile sidebar state
  let sidebarOpen = $state(false);
  // Textarea auto-resize
  let textareaRef = $state(null);
  // Random placeholder (10% chance for the tip)
  const placeholder =
    Math.random() < 0.1 ? 'Did you know? Press shift-enter for a new line...' : 'Type your message...';

  // Check if current user is a site admin
  const isSiteAdmin = $derived($page.props.user?.site_admin ?? false);

  // Check if user is near the bottom of the messages container (within 50px)
  function isNearBottom() {
    if (!messagesContainer) return true;
    const { scrollTop, scrollHeight, clientHeight } = messagesContainer;
    return scrollTop + clientHeight >= scrollHeight - 100;
  }

  // Scroll to bottom smoothly if user is near the bottom
  function scrollToBottomIfNeeded() {
    if (messagesContainer && isNearBottom()) {
      messagesContainer.scrollTo({
        top: messagesContainer.scrollHeight,
        behavior: 'smooth',
      });
    }
  }

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

  // Calculate total tokens used in the conversation
  const totalTokens = $derived(() => {
    if (!messages || messages.length === 0) return 0;
    return messages.reduce((sum, m) => sum + (m.input_tokens || 0) + (m.output_tokens || 0), 0);
  });

  // Format token count for display (e.g., 1.2k, 15.3k)
  function formatTokenCount(count) {
    if (count >= 1000) {
      return (count / 1000).toFixed(1).replace(/\.0$/, '') + 'k';
    }
    return count.toString();
  }

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

  // Check if chat is initializing (no title yet but has messages)
  const chatIsInitializing = $derived(chat && !chat.title && messages?.length > 0);

  // Check if any agent is currently responding (streaming)
  const agentIsResponding = $derived(messages?.some((m) => m.streaming) ?? false);

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

  // Handle debug log events from the sync channel
  function handleDebugLog(event) {
    const data = event.detail;
    debugLogs = [...debugLogs, { level: data.level, message: data.message, time: data.time }].slice(-100);
  }

  onDestroy(() => {
    if (timeoutCheckInterval) {
      clearInterval(timeoutCheckInterval);
    }
  });

  // Listen for debug log events when debug mode is enabled
  $effect(() => {
    if (debugMode && isSiteAdmin && browser) {
      window.addEventListener('debug-log', handleDebugLog);
      logging.debug('Debug log listener enabled');
      return () => {
        window.removeEventListener('debug-log', handleDebugLog);
        logging.debug('Debug log listener disabled');
      };
    }
  });

  // Set up real-time subscriptions
  $effect(() => {
    const subs = {};
    subs[`Account:${account.id}:chats`] = 'chats';

    if (chat) {
      subs[`Chat:${chat.id}`] = ['chat', 'messages']; // Both chat and messages when chat broadcasts
      subs[`Chat:${chat.id}:messages`] = 'messages'; // Individual message updates
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

  // Auto-scroll to bottom when messages change (only if user is near bottom)
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
        scrollToBottomIfNeeded();
      }, 100);
    }
  });

  streamingSync(
    (data) => {
      if (data.id) {
        const index = messages.findIndex((m) => m.id === data.id);
        if (index !== -1) {
          logging.debug('Updating message via streaming:', data.id, data.chunk);
          const currentMessage = messages[index] || {};
          const updatedMessage = {
            ...currentMessage,
            content: `${currentMessage.content || ''}${data.chunk || ''}`,
            streaming: true,
          };

          messages = messages.map((message, messageIndex) => (messageIndex === index ? updatedMessage : message));
          logging.debug('Message updated:', updatedMessage);

          // Scroll to bottom if user is near the bottom during streaming
          setTimeout(() => {
            scrollToBottomIfNeeded();
          }, 0);
        } else {
          logging.debug('No message found in streaming update:', data.id);
          logging.debug('Messages:', messages);
        }
      } else {
        logging.warn('No id found in streaming update:', data);
      }
    },
    (data) => {
      if (data.id) {
        const index = messages.findIndex((m) => m.id === data.id);
        if (index !== -1) {
          logging.debug('Updating message via streaming end:', data.id);
          messages = messages.map((message, messageIndex) =>
            messageIndex === index ? { ...message, streaming: false } : message
          );
        }
      } else {
        logging.warn('No id found in streaming end:', data);
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
        // Reset textarea height
        if (textareaRef) textareaRef.style.height = 'auto';

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

  function forkConversation() {
    if (!chat) return;

    const defaultTitle = `${chat.title_or_default} (Fork)`;
    const newTitle = prompt('Enter a name for the forked conversation:', defaultTitle);
    if (newTitle === null) return; // User cancelled

    router.post(forkAccountChatPath(account.id, chat.id), { title: newTitle });
  }

  function handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }

  function autoResize() {
    if (!textareaRef) return;
    textareaRef.style.height = 'auto';
    textareaRef.style.height = `${Math.min(textareaRef.scrollHeight, 240)}px`;
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
          <div class="text-sm text-muted-foreground flex items-center gap-2">
            {#if chat && !chat.title && messages?.length > 0}
              <Spinner size={12} class="animate-spin" />
              <span>Setting up...</span>
            {:else if chat?.manual_responses}
              <ParticipantAvatars {agents} {messages} />
              <span class="ml-2">{formatTokenCount(totalTokens())} tokens</span>
            {:else}
              {chat?.model_label || chat?.model_id || 'Auto'}
            {/if}
          </div>
        </div>
      </div>
    </header>

    <!-- Settings bar with web access toggle -->
    {#if chat}
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

        <button
          onclick={forkConversation}
          class="flex items-center gap-2 hover:opacity-80 transition-opacity text-sm text-muted-foreground">
          <GitFork size={16} weight="duotone" />
          <span>Fork</span>
        </button>

        {#if isSiteAdmin}
          <label class="flex items-center gap-2 cursor-pointer hover:opacity-80 transition-opacity w-fit">
            <input
              type="checkbox"
              bind:checked={showToolCalls}
              class="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
            <span class="text-sm text-muted-foreground">Show tool calls</span>
          </label>

          <label class="flex items-center gap-2 cursor-pointer hover:opacity-80 transition-opacity w-fit">
            <input
              type="checkbox"
              bind:checked={debugMode}
              class="w-4 h-4 rounded border-gray-300 text-orange-500 focus:ring-orange-500 focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
            <span class="text-sm text-orange-600">Debug mode</span>
          </label>
        {/if}
      </div>
    {/if}

    <!-- Debug panel for site admins -->
    {#if debugMode && isSiteAdmin}
      <div
        class="border-b border-orange-300 bg-orange-50 dark:bg-orange-950/30 px-4 md:px-6 py-2 max-h-48 overflow-y-auto">
        <div class="flex justify-between items-center mb-2">
          <span class="text-xs font-semibold text-orange-700 dark:text-orange-400">Debug Log</span>
          <button
            onclick={() => (debugLogs = [])}
            class="text-xs text-orange-600 hover:text-orange-800 dark:text-orange-400">
            Clear
          </button>
        </div>
        {#if debugLogs.length === 0}
          <p class="text-xs text-orange-600/70 dark:text-orange-400/70">
            No debug logs yet. Trigger an agent response to see logs.
          </p>
        {:else}
          <div class="space-y-1 font-mono text-xs">
            {#each debugLogs as log}
              <div
                class="flex gap-2 {log.level === 'error'
                  ? 'text-red-600'
                  : log.level === 'warn'
                    ? 'text-amber-600'
                    : 'text-orange-700 dark:text-orange-300'}">
                <span class="text-orange-400 dark:text-orange-500 shrink-0">[{log.time}]</span>
                <span class="break-all">{log.message}</span>
              </div>
            {/each}
          </div>
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
                            tokenize: 'word',
                            duration: 300,
                            timingFunction: 'ease-out',
                            animateOnMount: true,
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
      <AgentTriggerBar
        {agents}
        accountId={account.id}
        chatId={chat.id}
        disabled={chatIsInitializing || agentIsResponding} />
    {/if}

    <!-- Message input -->
    <div class="border-t border-border bg-muted/30 p-3 md:p-4">
      <div class="flex gap-2 md:gap-3 items-start">
        <FileUploadInput
          bind:files={selectedFiles}
          disabled={$messageForm.processing}
          allowedTypes={file_upload_config.acceptable_types || []}
          allowedExtensions={file_upload_config.acceptable_extensions || []}
          maxSize={file_upload_config.max_size || 50 * 1024 * 1024} />

        <div class="flex-1">
          <textarea
            bind:this={textareaRef}
            bind:value={$messageForm.message.content}
            onkeydown={handleKeydown}
            oninput={autoResize}
            {placeholder}
            disabled={$messageForm.processing}
            class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                   focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent
                   min-h-[40px] max-h-[240px] overflow-y-auto"
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
