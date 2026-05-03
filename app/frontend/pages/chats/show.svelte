<script>
  import { page } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { createDynamicSync, streamingSync } from '$lib/use-sync';
  import { router } from '@inertiajs/svelte';
  import { onMount, onDestroy } from 'svelte';
  import { WarningCircle } from 'phosphor-svelte';
  import ChatList from './ChatList.svelte';
  import ChatHeader from '$lib/components/chat/ChatHeader.svelte';
  import ImageLightbox from '$lib/components/chat/ImageLightbox.svelte';
  import AgentTriggerBar from '$lib/components/chat/AgentTriggerBar.svelte';
  import AgentPickerDialog from '$lib/components/chat/AgentPickerDialog.svelte';
  import WhiteboardDrawer from '$lib/components/chat/WhiteboardDrawer.svelte';
  import ChatMessageList from '$lib/components/chat/ChatMessageList.svelte';
  import MessageComposer from '$lib/components/chat/MessageComposer.svelte';
  import EditMessageDrawer from '$lib/components/chat/EditMessageDrawer.svelte';
  import TelegramBanner from '$lib/components/chat/TelegramBanner.svelte';
  import DebugPanel from '$lib/components/chat/DebugPanel.svelte';
  import ToastNotification from '$lib/components/chat/ToastNotification.svelte';
  import {
    accountChatMessagesPath,
    messageRetryPath,
    accountChatAgentAssignmentPath,
    messagePath,
    messageHallucinationFixPath,
    accountChatParticipantPath,
  } from '@/routes';
  import * as logging from '$lib/logging';
  import { formatTime, formatDate } from '$lib/utils';
  import { formatTokenCount } from '$lib/chat-utils';
  import {
    isChatResponseTimedOut,
    lastMessageIsHiddenThinking as messageStateLastMessageIsHiddenThinking,
    lastMessageIsUserWithoutResponse as messageStateLastMessageIsUserWithoutResponse,
    lastUserMessageNeedsResend as messageStateLastUserMessageNeedsResend,
    lastUserMessageTime as messageStateLastUserMessageTime,
    shouldShowSendingPlaceholder as messageStateShouldShowSendingPlaceholder,
    shouldShowTimestampForMessages,
    timestampLabelForMessages,
    visibleChatMessages,
  } from '$lib/chat-message-state';
  import { applyStreamingEnd, applyStreamingUpdate } from '$lib/chat-streaming-state';
  import { buildChatSubscriptions, chatSyncSignature } from '$lib/chat-sync-subscriptions';
  import { mode } from 'mode-watcher';

  const shikiTheme = $derived(mode.current === 'dark' ? 'catppuccin-mocha' : 'catppuccin-latte');

  // Browser check for event listeners
  const browser = typeof window !== 'undefined';

  // Scroll threshold for loading more messages
  const SCROLL_THRESHOLD = 200;

  // CSRF token helper
  function csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || '';
  }

  // Voice route helper (until js:routes:generate is run with the new route)
  function messageVoicePath(messageId) {
    return `/messages/${messageId}/voice`;
  }

  let {
    chat,
    chats = [],
    messages: recentMessages = [],
    has_more_messages: serverHasMore = false,
    oldest_message_id: serverOldestId = null,
    account,
    models = [],
    agents = [],
    available_agents = [],
    addable_agents = [],
    file_upload_config = {},
    telegram_deep_link: telegramDeepLink = null,
  } = $props();

  // Older messages loaded via pagination (not managed by Inertia)
  let olderMessages = $state([]);
  let hasMore = $state(serverHasMore);
  let oldestId = $state(serverOldestId);
  let loadingMore = $state(false);

  // Combined messages for display (deduplicated - recentMessages wins on overlap)
  const allMessages = $derived.by(() => {
    const seen = new Set();
    return [...olderMessages, ...recentMessages].filter((m) => {
      if (seen.has(m.id)) return false;
      seen.add(m.id);
      return true;
    });
  });

  // Token thresholds from server
  const thresholds = $derived($page.props.token_thresholds || { amber: 100_000, red: 150_000, critical: 200_000 });

  // Server-provided context (active replayed prompt) and cost (lifetime billed) tokens
  const contextTokens = $derived(chat?.context_tokens || 0);
  const costTokens = $derived(chat?.cost_tokens || { input: 0, output: 0 });

  // Token warning level — driven by active context size, not lifetime cost
  const tokenWarningLevel = $derived(
    contextTokens >= thresholds.critical
      ? 'critical'
      : contextTokens >= thresholds.red
        ? 'red'
        : contextTokens >= thresholds.amber
          ? 'amber'
          : null
  );

  // Explicit chat reset tracking
  let previousChatId = null;

  $effect(() => {
    if (chat?.id !== previousChatId) {
      previousChatId = chat?.id;
      olderMessages = [];
      hasMore = serverHasMore;
      oldestId = serverOldestId;
    }
  });

  // Update pagination state when server props change, but only if we haven't paginated yet
  $effect(() => {
    if (olderMessages.length === 0) {
      hasMore = serverHasMore;
      oldestId = serverOldestId;
    }
  });

  let messagesContainer = $state();
  let waitingForResponse = $state(false);
  let messageSentAt = $state(null);
  let currentTime = $state(Date.now());
  let timeoutCheckInterval;
  let showAllMessages = $state(false);
  let debugMode = $state(false);
  let debugLogs = $state([]);
  // Brief "select an agent" prompt for group chats after sending a message
  let showAgentPrompt = $state(false);
  // Mobile sidebar state
  let sidebarOpen = $state(false);

  // Whiteboard state
  let whiteboardOpen = $state(false);

  // Assign agent dialog state
  let assignAgentOpen = $state(false);
  let assigningAgent = $state(false);

  // Add agent dialog state
  let addAgentOpen = $state(false);
  let addAgentProcessing = $state(false);

  // Thinking streaming state
  let streamingThinking = $state({});

  // Streaming safety-net refresh timer
  let streamingRefreshTimer = null;

  function scheduleStreamingRefresh(delayMs = 5000) {
    if (streamingRefreshTimer) clearTimeout(streamingRefreshTimer);
    streamingRefreshTimer = setTimeout(() => {
      streamingRefreshTimer = null;
      router.reload({
        only: ['messages'],
        preserveScroll: true,
        onSuccess: () => {
          // If any message is still streaming, schedule another refresh in 10s
          if (recentMessages?.some((m) => m.streaming)) {
            scheduleStreamingRefresh(10000);
          }
        },
      });
    }, delayMs);
  }

  // Error handling state
  let errorMessage = $state(null);
  let successMessage = $state(null);

  // Image lightbox state
  let lightboxOpen = $state(false);
  let lightboxImage = $state(null);

  function openImageLightbox(file) {
    lightboxImage = file;
    lightboxOpen = true;
  }

  // Edit message state
  let editDrawerOpen = $state(false);
  let editingMessageId = $state(null);
  let editingContent = $state('');

  // Check if current user is a site admin
  const isSiteAdmin = $derived($page.props.user?.site_admin ?? false);

  // Check if current user is an account admin
  const isAccountAdmin = $derived($page.props.is_account_admin ?? false);

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

  // Scroll to bottom unconditionally (e.g. after user sends a message)
  function scrollToBottom() {
    if (messagesContainer) {
      messagesContainer.scrollTo({
        top: messagesContainer.scrollHeight,
        behavior: 'smooth',
      });
    }
  }

  // Handle scroll for loading more messages
  function handleScroll() {
    if (!messagesContainer) return;
    if (messagesContainer.scrollTop < SCROLL_THRESHOLD && hasMore && !loadingMore && oldestId) {
      loadMoreMessages();
    }
  }

  // Load more messages from the server
  async function loadMoreMessages() {
    if (loadingMore || !hasMore || !oldestId) return;

    loadingMore = true;
    const container = messagesContainer;
    const previousHeight = container.scrollHeight;

    try {
      const response = await fetch(accountChatMessagesPath(account.id, chat.id, { before_id: oldestId }), {
        headers: {
          Accept: 'application/json',
          'X-CSRF-Token': csrfToken(),
        },
      });

      if (response.ok) {
        const data = await response.json();
        olderMessages = [...data.messages, ...olderMessages];
        hasMore = data.has_more;
        oldestId = data.oldest_id;

        // Simple scroll preservation with requestAnimationFrame
        requestAnimationFrame(() => {
          container.scrollTop += container.scrollHeight - previousHeight;
        });
      }
    } catch (error) {
      logging.error('Failed to load more messages:', error);
    } finally {
      loadingMore = false;
    }
  }

  // Helper to update a message in both recentMessages and olderMessages
  function updateMessage(messageId, patch) {
    recentMessages = recentMessages.map((m) => (m.id === messageId ? { ...m, ...patch } : m));
    olderMessages = olderMessages.map((m) => (m.id === messageId ? { ...m, ...patch } : m));
  }

  // Request voice synthesis for a message
  async function requestVoice(messageId) {
    updateMessage(messageId, { _voice_loading: true });

    try {
      const response = await fetch(messageVoicePath(messageId), {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken(), Accept: 'application/json' },
      });

      if (response.status === 200) {
        const { voice_audio_url } = await response.json();
        updateMessage(messageId, { voice_audio_url, _voice_loading: false });
      } else if (response.status !== 202) {
        updateMessage(messageId, { _voice_loading: false });
      }
      // 202: loading state clears when Broadcastable refresh replaces the message
    } catch {
      updateMessage(messageId, { _voice_loading: false });
    }
  }

  // Filter out tool messages and empty assistant messages unless admin has enabled "show all messages"
  const visibleMessages = $derived(visibleChatMessages(allMessages, showAllMessages));

  // Count unique human participants in group chats
  const uniqueHumanCount = $derived.by(() => {
    if (!allMessages || allMessages.length === 0) return 0;
    const humanNames = new Set(allMessages.filter((m) => m.role === 'user' && m.author_name).map((m) => m.author_name));
    return humanNames.size;
  });

  // Check if the last actual message is hidden (tool call or empty assistant) - model is still thinking
  const lastMessageIsHiddenThinking = $derived.by(() => {
    return messageStateLastMessageIsHiddenThinking(allMessages);
  });

  // Check if the last message is a user message without a response
  const lastMessageIsUserWithoutResponse = $derived.by(() => {
    return messageStateLastMessageIsUserWithoutResponse(allMessages);
  });

  // Check if any agent is currently responding (streaming)
  const agentIsResponding = $derived(allMessages?.some((m) => m.streaming) ?? false);

  // Auto-detect waiting state based on messages
  // Don't show for manual_responses chats (group chats) since they don't auto-respond
  const shouldShowSendingPlaceholder = $derived(
    messageStateShouldShowSendingPlaceholder({ chat, messages: allMessages, waitingForResponse })
  );

  // Get the timestamp of when the last user message was sent
  const lastUserMessageTime = $derived.by(() => {
    return messageStateLastUserMessageTime(allMessages);
  });

  // Check if we've been waiting too long (over 1 minute)
  const isTimedOut = $derived.by(() => {
    return isChatResponseTimedOut({ chat, messages: allMessages, waitingForResponse, messageSentAt, currentTime });
  });

  // Check if last message needs resend option
  const lastUserMessageNeedsResend = $derived.by(() => {
    return messageStateLastUserMessageNeedsResend(allMessages, currentTime);
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
    if (streamingRefreshTimer) {
      clearTimeout(streamingRefreshTimer);
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

  // Set up real-time subscriptions - SIMPLIFIED (no message count comparison)
  $effect(() => {
    const subs = buildChatSubscriptions({ account, chat });
    const nextSignature = chatSyncSignature({ account, chat, recentMessages });

    if (nextSignature !== syncSignature) {
      syncSignature = nextSignature;
      updateSync(subs);
    }
    // ActionCable broadcasts handle new messages automatically
  });

  // Auto-scroll to bottom when messages change (only if user is near bottom)
  $effect(() => {
    recentMessages; // Subscribe to messages changes

    // Clear waiting state if an assistant message appeared
    if (waitingForResponse && recentMessages.length > 0) {
      const lastMessage = recentMessages[recentMessages.length - 1];
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
        const index = recentMessages.findIndex((m) => m.id === data.id);
        if (index !== -1) {
          const result = applyStreamingUpdate({ messages: recentMessages, streamingThinking }, data);
          if (result.handled) {
            streamingThinking = result.streamingThinking;
            recentMessages = result.messages;

            // Scroll to bottom if user is near the bottom during streaming
            setTimeout(() => {
              scrollToBottomIfNeeded();
            }, 0);
          }
        } else {
          logging.debug('No message found in streaming update:', data.id);
          logging.debug('Messages:', recentMessages);
        }
      } else if (data.action === 'error') {
        // Handle transient errors
        errorMessage = data.message;
        setTimeout(() => (errorMessage = null), 5000);
      } else {
        logging.warn('No id found in streaming update:', data);
      }
    },
    (data) => {
      if (data.id) {
        const result = applyStreamingEnd({ messages: recentMessages, streamingThinking }, data);
        streamingThinking = result.streamingThinking;
        recentMessages = result.messages;

        if (result.handled) {
          logging.debug('Updating message via streaming end:', data.id);
        }
      } else {
        logging.warn('No id found in streaming end:', data);
      }
    }
  );

  const retryForm = useForm({});

  function retryMessage(messageId) {
    $retryForm.post(messageRetryPath(messageId), {
      onSuccess: () => {
        scheduleStreamingRefresh();
      },
    });
  }

  function resendLastMessage() {
    // Find the last user message and retry the AI response
    logging.debug('resendLastMessage called, messages:', allMessages?.length);
    if (allMessages && allMessages.length > 0) {
      // Find the actual last user message (may not be the very last message if AI started responding)
      const lastUserMessage = [...allMessages].reverse().find((m) => m.role === 'user');
      logging.debug('lastUserMessage:', lastUserMessage);
      if (lastUserMessage) {
        // Retry the AI response for this message
        const retryPath = messageRetryPath(lastUserMessage.id);
        logging.debug('Posting to retry path:', retryPath);
        waitingForResponse = true;
        messageSentAt = Date.now();

        $retryForm.post(retryPath, {
          onSuccess: () => {
            logging.debug('Retry triggered successfully');
            scheduleStreamingRefresh();
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

  async function fixHallucinatedToolCalls(messageId) {
    await fetch(messageHallucinationFixPath(messageId), {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrfToken() },
    });
    router.reload({ only: ['messages'], preserveScroll: true });
  }

  function assignToAgent(agentId) {
    if (!chat || !agentId) return;
    assigningAgent = true;
    router.post(
      accountChatAgentAssignmentPath(account.id, chat.id),
      { agent_id: agentId },
      {
        onFinish: () => {
          assigningAgent = false;
          assignAgentOpen = false;
        },
      }
    );
  }

  function addAgentToChat(agentId) {
    if (!chat || !agentId) return;
    addAgentProcessing = true;
    router.post(
      accountChatParticipantPath(account.id, chat.id),
      { agent_id: agentId },
      {
        onFinish: () => {
          addAgentProcessing = false;
          addAgentOpen = false;
        },
      }
    );
  }

  function startEditingMessage(message) {
    editingMessageId = message.id;
    editingContent = message.content;
    editDrawerOpen = true;
  }

  async function deleteMessage(messageId) {
    if (!confirm('Delete this message?')) return;

    try {
      const response = await fetch(messagePath(messageId), {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': csrfToken(),
        },
      });

      if (response.ok) {
        // Remove from local state immediately
        recentMessages = recentMessages.filter((m) => m.id !== messageId);
        olderMessages = olderMessages.filter((m) => m.id !== messageId);
        // Reload to get proper server state
        router.reload({ only: ['messages'], preserveScroll: true });
      } else {
        errorMessage = 'Failed to delete message';
        setTimeout(() => (errorMessage = null), 3000);
      }
    } catch (error) {
      errorMessage = 'Failed to delete message';
      setTimeout(() => (errorMessage = null), 3000);
    }
  }

  function shouldShowTimestamp(index) {
    return shouldShowTimestampForMessages(visibleMessages, index);
  }

  function timestampLabel(index) {
    return timestampLabelForMessages(visibleMessages, index, { formatDate, formatTime });
  }
</script>

<svelte:head>
  <title>{chat?.title || 'Chat'}</title>
</svelte:head>

<div class="flex h-[calc(100dvh-4rem)]">
  <!-- Left sidebar: Chat list -->
  <ChatList
    {chats}
    activeChatId={chat?.id}
    accountId={account.id}
    isOpen={sidebarOpen}
    onClose={() => (sidebarOpen = false)} />

  <!-- Right side: Chat messages -->
  <main class="flex-1 flex flex-col bg-background min-w-0">
    <!-- Chat header -->
    <ChatHeader
      {chat}
      {account}
      {agents}
      {allMessages}
      {contextTokens}
      {costTokens}
      {thresholds}
      availableAgents={available_agents}
      addableAgents={addable_agents}
      bind:showAllMessages
      bind:debugMode
      onsidebaropen={() => (sidebarOpen = true)}
      onassignagent={() => (assignAgentOpen = true)}
      onaddagent={() => (addAgentOpen = true)}
      onwhiteboardopen={() => (whiteboardOpen = true)}
      onerror={(msg) => {
        errorMessage = msg;
        setTimeout(() => (errorMessage = null), 3000);
      }}
      onsuccess={(msg) => {
        successMessage = msg;
        setTimeout(() => (successMessage = null), 3000);
      }} />

    <!-- Critical token warning banner -->
    {#if tokenWarningLevel === 'critical'}
      <div
        class="bg-red-100 dark:bg-red-900/50 border-b border-red-200 dark:border-red-800 px-4 py-2 text-sm text-red-800 dark:text-red-200">
        <WarningCircle size={16} class="inline mr-2" weight="fill" />
        This conversation is very long ({formatTokenCount(contextTokens)} tokens of context). Consider starting a new conversation.
      </div>
    {/if}

    <!-- Telegram notification banner -->
    <TelegramBanner {telegramDeepLink} {agents} chatId={chat?.id} />

    <!-- Debug panel for site admins -->
    {#if debugMode && isSiteAdmin}
      <DebugPanel logs={debugLogs} onclear={() => (debugLogs = [])} />
    {/if}

    <ChatMessageList
      bind:messagesContainer
      {loadingMore}
      {hasMore}
      {oldestId}
      {visibleMessages}
      {allMessages}
      {chat}
      {showAllMessages}
      {lastMessageIsHiddenThinking}
      {shouldShowSendingPlaceholder}
      {isTimedOut}
      {lastUserMessageNeedsResend}
      {waitingForResponse}
      {streamingThinking}
      {shikiTheme}
      {showAgentPrompt}
      {handleScroll}
      {loadMoreMessages}
      {shouldShowTimestamp}
      {timestampLabel}
      {startEditingMessage}
      {deleteMessage}
      {retryMessage}
      {fixHallucinatedToolCalls}
      {resendLastMessage}
      {openImageLightbox}
      {requestVoice} />

    <!-- Agent trigger bar for group chats -->
    {#if chat?.manual_responses && agents?.length > 0}
      <AgentTriggerBar
        {agents}
        accountId={account.id}
        chatId={chat.id}
        disabled={agentIsResponding || !chat?.respondable}
        onTrigger={scheduleStreamingRefresh} />
    {/if}

    <!-- Not respondable banner -->
    {#if chat && !chat.respondable}
      <div
        class="border-t border-amber-500 bg-amber-50 dark:bg-amber-950/30 px-4 py-2 text-center text-amber-700 dark:text-amber-400 text-sm">
        {#if chat.discarded}
          This conversation has been deleted.
        {:else}
          This conversation has been archived.
        {/if}
      </div>
    {/if}

    <MessageComposer
      accountId={account.id}
      chatId={chat?.id}
      disabled={!chat?.respondable}
      manualResponses={chat?.manual_responses}
      fileUploadConfig={file_upload_config}
      onsent={(data) => {
        if (data?.id) {
          const seen = new Set(recentMessages.map((m) => m.id));
          if (!seen.has(data.id)) {
            recentMessages = [...recentMessages, data];
          }
        }
        if (!chat?.manual_responses) scheduleStreamingRefresh();
        setTimeout(() => scrollToBottom(), 50);
      }}
      onwaiting={() => {
        if (!chat?.manual_responses) {
          waitingForResponse = true;
          messageSentAt = Date.now();
        }
      }}
      onerror={(msg) => {
        errorMessage = msg;
        setTimeout(() => (errorMessage = null), 5000);
        waitingForResponse = false;
        messageSentAt = null;
      }}
      onagentprompt={() => {
        showAgentPrompt = true;
        setTimeout(() => {
          showAgentPrompt = false;
        }, 3000);
      }} />
  </main>
</div>

{#if chat?.active_whiteboard}
  <WhiteboardDrawer
    bind:open={whiteboardOpen}
    whiteboard={chat.active_whiteboard}
    accountId={account.id}
    {agentIsResponding}
    {shikiTheme} />
{/if}

<!-- Edit Message Drawer -->
<EditMessageDrawer
  bind:open={editDrawerOpen}
  messageId={editingMessageId}
  initialContent={editingContent}
  onsaved={(messageId, trimmedContent) => {
    updateMessage(messageId, { content: trimmedContent, editable: false });
    editDrawerOpen = false;
    editingMessageId = null;
    editingContent = '';
  }}
  onerror={(msg) => {
    errorMessage = msg;
    setTimeout(() => (errorMessage = null), 3000);
  }} />

<!-- Error toast -->
<ToastNotification message={errorMessage} variant="error" />

<!-- Success toast -->
<ToastNotification message={successMessage} variant="success" />

<!-- Assign Agent Dialog -->
<AgentPickerDialog
  bind:open={assignAgentOpen}
  agents={available_agents}
  title="Assign to Agent"
  description="Select an agent to take over this conversation. The agent will be informed that previous messages were with a model that had no identity or memories."
  confirmLabel="Assign"
  confirmingLabel="Assigning..."
  processing={assigningAgent}
  onconfirm={assignToAgent} />

<!-- Add Agent Dialog -->
<AgentPickerDialog
  bind:open={addAgentOpen}
  agents={addable_agents}
  title="Add Agent to Conversation"
  description="Select an agent to add to this group chat."
  confirmLabel="Add"
  confirmingLabel="Adding..."
  processing={addAgentProcessing}
  onconfirm={addAgentToChat} />

<ImageLightbox bind:open={lightboxOpen} file={lightboxImage} />
