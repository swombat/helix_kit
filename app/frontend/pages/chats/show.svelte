<script>
  import { page } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { createDynamicSync, streamingSync } from '$lib/use-sync';
  import { router } from '@inertiajs/svelte';
  import { onMount, onDestroy } from 'svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Badge } from '$lib/components/shadcn/badge/index.js';
  import {
    ArrowUp,
    ArrowClockwise,
    Spinner,
    Globe,
    List,
    GitFork,
    Notepad,
    FloppyDisk,
    PencilSimple,
    X,
    WarningCircle,
    Archive,
    Trash,
    ArrowCounterClockwise,
    DotsThreeVertical,
    Robot,
    ShieldCheck,
    Wrench,
  } from 'phosphor-svelte';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import * as Drawer from '$lib/components/shadcn/drawer/index.js';
  import * as DropdownMenu from '$lib/components/shadcn/dropdown-menu/index.js';
  import * as Dialog from '$lib/components/shadcn/dialog/index.js';
  import ChatList from './ChatList.svelte';
  import FileUploadInput from '$lib/components/chat/FileUploadInput.svelte';
  import FileAttachment from '$lib/components/chat/FileAttachment.svelte';
  import ImageLightbox from '$lib/components/chat/ImageLightbox.svelte';
  import AgentTriggerBar from '$lib/components/chat/AgentTriggerBar.svelte';
  import ParticipantAvatars from '$lib/components/chat/ParticipantAvatars.svelte';
  import ThinkingBlock from '$lib/components/chat/ThinkingBlock.svelte';
  import ModerationIndicator from '$lib/components/chat/ModerationIndicator.svelte';
  import AgentPickerDialog from '$lib/components/chat/AgentPickerDialog.svelte';
  import MicButton from '$lib/components/chat/MicButton.svelte';
  import {
    accountChatMessagesPath,
    messageRetryPath,
    accountChatForkPath,
    accountChatAgentAssignmentPath,
    messagePath,
    accountChatModerationPath,
    messageHallucinationFixPath,
    accountChatArchivePath,
    accountChatDiscardPath,
    accountChatParticipantPath,
  } from '@/routes';
  import { marked } from 'marked';
  import * as logging from '$lib/logging';
  import { formatTime, formatDate, formatDateTime } from '$lib/utils';
  import { mode } from 'mode-watcher';
  import { fade } from 'svelte/transition';
  import { Streamdown } from 'svelte-streamdown';

  const shikiTheme = $derived(mode.current === 'dark' ? 'catppuccin-mocha' : 'catppuccin-latte');

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

  // Scroll threshold for loading more messages
  const SCROLL_THRESHOLD = 200;

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

  // Use server-provided total tokens from chat
  const totalTokens = $derived(chat?.total_tokens || 0);

  // Direct ternary expression for token warning level
  const tokenWarningLevel = $derived(
    totalTokens >= thresholds.critical
      ? 'critical'
      : totalTokens >= thresholds.red
        ? 'red'
        : totalTokens >= thresholds.amber
          ? 'amber'
          : null
  );

  // Header class computed based on token warning level
  const headerClass = $derived(
    tokenWarningLevel === 'critical'
      ? 'border-b border-border px-4 md:px-6 py-3 md:py-4 bg-red-50 dark:bg-red-950/30'
      : 'border-b border-border px-4 md:px-6 py-3 md:py-4 bg-muted/30'
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

  let selectedModel = $state(models?.[0]?.model_id ?? '');
  let messageInput = $state('');
  let selectedFiles = $state([]);
  let submitting = $state(false);
  let messagesContainer;
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
  // Textarea auto-resize
  let textareaRef = $state(null);
  // Random placeholder (10% chance for the tip)
  const placeholder =
    Math.random() < 0.1 ? 'Did you know? Press shift-enter for a new line...' : 'Type your message...';

  // Whiteboard state
  let whiteboardOpen = $state(false);
  let whiteboardEditing = $state(false);
  let whiteboardEditContent = $state('');
  let whiteboardConflict = $state(null);
  let whiteboardSaving = $state(false);

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

  // Title editing state
  let titleEditing = $state(false);
  let titleEditValue = $state('');
  let titleInputRef = $state(null);
  let originalTitle = $state('');

  // Edit message state
  let editDrawerOpen = $state(false);
  let editingMessageId = $state(null);
  let editingContent = $state('');
  let editSaving = $state(false);

  // Telegram banner dismissal state
  let telegramBannerDismissed = $state(false);

  // Check localStorage for previously dismissed Telegram banners
  $effect(() => {
    if (browser && chat?.id) {
      const dismissedAgents = JSON.parse(localStorage.getItem('telegram_banner_dismissed') || '{}');
      // Find agent id from the deep link context - use first agent's id
      const agentId = agents?.[0]?.id;
      if (agentId && dismissedAgents[agentId]) {
        telegramBannerDismissed = true;
      } else {
        telegramBannerDismissed = false;
      }
    }
  });

  function dismissTelegramBanner() {
    telegramBannerDismissed = true;
    if (browser) {
      const agentId = agents?.[0]?.id;
      if (agentId) {
        const dismissed = JSON.parse(localStorage.getItem('telegram_banner_dismissed') || '{}');
        dismissed[agentId] = true;
        localStorage.setItem('telegram_banner_dismissed', JSON.stringify(dismissed));
      }
    }
  }

  // Telegram agent name for the banner
  const telegramAgentName = $derived(
    agents?.find((a) => a.telegram_configured)?.name || agents?.[0]?.name || 'this agent'
  );

  // Check if current user is a site admin
  const isSiteAdmin = $derived($page.props.user?.site_admin ?? false);

  // Check if current user is an account admin
  const isAccountAdmin = $derived($page.props.is_account_admin ?? false);

  // Check if user can delete chats (account admin or site admin)
  const canDeleteChat = $derived(isAccountAdmin || isSiteAdmin);

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
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
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

  // Filter out tool messages and empty assistant messages unless admin has enabled "show all messages"
  const visibleMessages = $derived(
    showAllMessages
      ? allMessages
      : allMessages.filter((m) => {
          // Hide tool messages
          if (m.role === 'tool') return false;
          // Hide empty assistant messages (these appear before tool calls)
          if (m.role === 'assistant' && (!m.content || m.content.trim() === '') && !m.streaming) return false;
          // Hide assistant messages that are PURE JSON tool results (no text content after the JSON)
          // Some messages may have JSON prefix followed by actual text - those should be shown
          if (m.role === 'assistant' && m.content && !m.streaming) {
            const trimmed = m.content.trim();
            if (trimmed.startsWith('{')) {
              // Only hide if it looks like pure JSON (ends with } and nothing substantial after)
              // This allows messages like "{...}Actual response text" to be shown
              const lastBrace = trimmed.lastIndexOf('}');
              if (lastBrace !== -1) {
                const afterJson = trimmed.substring(lastBrace + 1).trim();
                if (afterJson === '') return false; // Pure JSON, hide it
              }
            }
          }
          return true;
        })
  );

  // Count unique human participants in group chats
  const uniqueHumanCount = $derived(() => {
    if (!allMessages || allMessages.length === 0) return 0;
    const humanNames = new Set(allMessages.filter((m) => m.role === 'user' && m.author_name).map((m) => m.author_name));
    return humanNames.size;
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
    if (!allMessages || allMessages.length === 0) return false;
    const lastMessage = allMessages[allMessages.length - 1];
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
    if (!allMessages || allMessages.length === 0) return false;
    const lastMessage = allMessages[allMessages.length - 1];
    return lastMessage && lastMessage.role === 'user';
  });

  // Check if title is loading (no title yet but has messages) - cosmetic only, doesn't block functionality
  const titleIsLoading = $derived(chat && !chat.title && allMessages?.length > 0);

  // Check if any agent is currently responding (streaming)
  const agentIsResponding = $derived(allMessages?.some((m) => m.streaming) ?? false);

  // Auto-detect waiting state based on messages
  // Don't show for manual_responses chats (group chats) since they don't auto-respond
  const shouldShowSendingPlaceholder = $derived(
    !chat?.manual_responses && (waitingForResponse || lastMessageIsUserWithoutResponse())
  );

  // Get the timestamp of when the last user message was sent
  const lastUserMessageTime = $derived(() => {
    if (!allMessages || allMessages.length === 0) return null;
    const lastMessage = allMessages[allMessages.length - 1];
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
    if (!allMessages || allMessages.length === 0) return false;
    const lastMessage = allMessages[allMessages.length - 1];
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
    const subs = {};
    subs[`Account:${account.id}:chats`] = 'chats';

    if (chat) {
      subs[`Chat:${chat.id}`] = ['chat', 'messages']; // Both chat and messages when chat broadcasts
      subs[`Chat:${chat.id}:messages`] = 'messages'; // Individual message updates

      if (chat.active_whiteboard) {
        subs[`Whiteboard:${chat.active_whiteboard.id}`] = ['chat', 'messages'];
      }
    }

    const messageSignature = Array.isArray(recentMessages) ? recentMessages.map((message) => message.id).join(':') : '';
    const nextSignature = `${account.id}|${chat?.id ?? 'none'}|${messageSignature}`;

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

  // Focus title input when editing starts
  $effect(() => {
    if (titleEditing && titleInputRef) {
      titleInputRef.focus();
      titleInputRef.select();
    }
  });

  streamingSync(
    (data) => {
      if (data.id) {
        const index = recentMessages.findIndex((m) => m.id === data.id);
        if (index !== -1) {
          if (data.action === 'thinking_update') {
            // Handle thinking updates
            streamingThinking[data.id] = (streamingThinking[data.id] || '') + (data.chunk || '');
          } else if (data.action === 'streaming_update') {
            // Handle content streaming
            logging.debug('Updating message via streaming:', data.id, data.chunk);
            const currentMessage = recentMessages[index] || {};
            const updatedMessage = {
              ...currentMessage,
              content: `${currentMessage.content || ''}${data.chunk || ''}`,
              streaming: true,
            };

            recentMessages = recentMessages.map((message, messageIndex) =>
              messageIndex === index ? updatedMessage : message
            );
            logging.debug('Message updated:', updatedMessage);

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
        // Clear streaming thinking on stream end
        if (streamingThinking[data.id]) {
          delete streamingThinking[data.id];
          streamingThinking = { ...streamingThinking };
        }

        const index = recentMessages.findIndex((m) => m.id === data.id);
        if (index !== -1) {
          logging.debug('Updating message via streaming end:', data.id);
          recentMessages = recentMessages.map((message, messageIndex) =>
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

    if (submitting) {
      logging.debug('Already submitting, returning');
      return;
    }

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

    submitting = true;

    router.post(accountChatMessagesPath(account.id, chat.id), formData, {
      onSuccess: () => {
        logging.debug('Message sent successfully');
        submitting = false;
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

        // Safety-net refresh in case streaming doesn't come through
        if (!chat?.manual_responses) {
          scheduleStreamingRefresh();
        }
      },
      onError: (errors) => {
        logging.error('Message send failed:', errors);
        submitting = false;
        waitingForResponse = false;
        messageSentAt = null;
      },
    });
  }

  function handleTranscription(text) {
    $messageForm.message.content = text;
    sendMessage();
  }

  function handleTranscriptionError(message) {
    errorMessage = message;
    setTimeout(() => (errorMessage = null), 5000);
  }

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
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || '';
    await fetch(messageHallucinationFixPath(messageId), {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrfToken },
    });
    router.reload({ only: ['messages'], preserveScroll: true });
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

    router.post(accountChatForkPath(account.id, chat.id), { title: newTitle });
  }

  function archiveChat() {
    if (!chat) return;
    if (chat.archived) {
      router.delete(accountChatArchivePath(account.id, chat.id), { preserveScroll: true });
    } else {
      router.post(accountChatArchivePath(account.id, chat.id), {}, { preserveScroll: true });
    }
  }

  function deleteChat() {
    if (!chat) return;
    if (!chat.discarded && !confirm('Are you sure you want to delete this conversation?')) return;
    if (chat.discarded) {
      router.delete(accountChatDiscardPath(account.id, chat.id), { preserveScroll: true });
    } else {
      router.post(accountChatDiscardPath(account.id, chat.id), {}, { preserveScroll: true });
    }
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

  function startEditingTitle() {
    if (!chat) return;
    originalTitle = chat.title || 'New Chat';
    titleEditValue = originalTitle;
    titleEditing = true;
  }

  function cancelEditingTitle() {
    titleEditing = false;
    titleEditValue = '';
  }

  function saveTitle() {
    if (!chat || !titleEditValue.trim()) {
      cancelEditingTitle();
      return;
    }

    const newTitle = titleEditValue.trim();

    // Optimistically update the UI
    const previousTitle = chat.title;
    chat.title = newTitle;
    titleEditing = false;

    router.patch(
      `/accounts/${account.id}/chats/${chat.id}`,
      {
        chat: { title: newTitle },
      },
      {
        preserveScroll: true,
        preserveState: true,
        onSuccess: () => {
          logging.debug('Title updated successfully');
        },
        onError: (errors) => {
          logging.error('Failed to update title:', errors);
          // Revert to original title on error
          chat.title = previousTitle;
          errorMessage = 'Failed to update title';
          setTimeout(() => (errorMessage = null), 3000);
        },
      }
    );
  }

  function handleTitleKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      saveTitle();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      cancelEditingTitle();
    }
  }

  function handleTitleBlur() {
    saveTitle();
  }

  function handleTitleClick(event) {
    // Single tap on mobile
    if ('ontouchstart' in window) {
      startEditingTitle();
    }
  }

  function handleTitleDoubleClick(event) {
    // Double-click on desktop
    if (!('ontouchstart' in window)) {
      startEditingTitle();
    }
  }

  function startEditingMessage(message) {
    editingMessageId = message.id;
    editingContent = message.content;
    editDrawerOpen = true;
  }

  function cancelEditingMessage() {
    editDrawerOpen = false;
    editingMessageId = null;
    editingContent = '';
  }

  async function saveEditedMessage() {
    if (editSaving) return;
    editSaving = true;

    const trimmedContent = editingContent.trim();
    const messageId = editingMessageId;

    try {
      const response = await fetch(`/messages/${messageId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
        },
        body: JSON.stringify({ message: { content: trimmedContent } }),
      });

      if (response.ok) {
        // Immediately update the message in local state for instant feedback
        recentMessages = recentMessages.map((m) =>
          m.id === messageId ? { ...m, content: trimmedContent, editable: false } : m
        );
        olderMessages = olderMessages.map((m) =>
          m.id === messageId ? { ...m, content: trimmedContent, editable: false } : m
        );

        cancelEditingMessage();
        // Also reload to get proper server state (markdown rendering, etc.)
        router.reload({ only: ['messages'], preserveScroll: true });
      } else {
        errorMessage = 'Failed to save message';
        setTimeout(() => (errorMessage = null), 3000);
      }
    } catch (error) {
      errorMessage = 'Failed to save message';
      setTimeout(() => (errorMessage = null), 3000);
    } finally {
      editSaving = false;
    }
  }

  async function deleteMessage(messageId) {
    if (!confirm('Delete this message?')) return;

    try {
      const response = await fetch(messagePath(messageId), {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
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

  // Moderate all messages in the chat (site admin only)
  async function moderateAllMessages() {
    try {
      const response = await fetch(accountChatModerationPath(account.id, chat.id), {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
          Accept: 'application/json',
        },
      });

      if (response.ok) {
        const data = await response.json();
        successMessage = `Queued moderation for ${data.queued} messages`;
        setTimeout(() => (successMessage = null), 3000);
      } else {
        errorMessage = 'Failed to queue moderation';
        setTimeout(() => (errorMessage = null), 3000);
      }
    } catch (error) {
      errorMessage = 'Failed to queue moderation';
      setTimeout(() => (errorMessage = null), 3000);
    }
  }

  async function saveWhiteboard() {
    if (!chat?.active_whiteboard) return;

    whiteboardSaving = true;
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

    try {
      const response = await fetch(`/accounts/${account.id}/whiteboards/${chat.active_whiteboard.id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken || '',
        },
        body: JSON.stringify({
          whiteboard: { content: whiteboardEditContent },
          expected_revision: chat.active_whiteboard.revision,
        }),
      });

      if (response.ok) {
        whiteboardEditing = false;
        whiteboardOpen = false;
        whiteboardConflict = null;
        whiteboardSaving = false;
        // Reload page data to get updated whiteboard
        router.reload({ only: ['chat', 'messages'], preserveScroll: true });
      } else {
        const data = await response.json();
        whiteboardSaving = false;
        if (data.error === 'conflict') {
          whiteboardConflict = {
            serverContent: data.current_content,
            serverRevision: data.current_revision,
            myContent: whiteboardEditContent,
          };
        } else {
          alert('Failed to save. Please try again.');
        }
      }
    } catch (error) {
      whiteboardSaving = false;
      alert('Failed to save. Please try again.');
    }
  }

  function useServerVersion() {
    if (!whiteboardConflict) return;
    whiteboardEditContent = whiteboardConflict.serverContent;
    whiteboardConflict = null;
  }

  function keepMyVersion() {
    whiteboardConflict = null;
    saveWhiteboard();
  }

  function startEditingWhiteboard() {
    whiteboardEditContent = chat?.active_whiteboard?.content || '';
    whiteboardEditing = true;
  }

  function cancelEditingWhiteboard() {
    whiteboardEditing = false;
    whiteboardEditContent = '';
    whiteboardConflict = null;
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

<div class="flex h-[calc(100dvh-4rem)]">
  <!-- Left sidebar: Chat list -->
  <ChatList
    {chats}
    activeChatId={chat?.id}
    accountId={account.id}
    {selectedModel}
    isOpen={sidebarOpen}
    onClose={() => (sidebarOpen = false)} />

  <!-- Right side: Chat messages -->
  <main class="flex-1 flex flex-col bg-background min-w-0">
    <!-- Chat header -->
    <header class={headerClass}>
      <div class="flex items-center gap-3">
        <Button variant="ghost" size="sm" onclick={() => (sidebarOpen = true)} class="h-8 w-8 p-0 md:hidden">
          <List size={20} />
        </Button>
        <div class="flex-1 min-w-0">
          {#if titleEditing}
            <input
              bind:this={titleInputRef}
              bind:value={titleEditValue}
              onkeydown={handleTitleKeydown}
              onblur={handleTitleBlur}
              type="text"
              class="text-lg font-semibold bg-background border border-primary rounded px-2 py-1 w-full focus:outline-none focus:ring-2 focus:ring-ring" />
          {:else}
            <h1
              class="text-lg font-semibold cursor-pointer hover:opacity-70 transition-opacity flex items-center gap-2 min-w-0"
              onclick={handleTitleClick}
              ondblclick={handleTitleDoubleClick}
              title="Click to edit (double-click on desktop, single tap on mobile)">
              <span class="truncate">{chat?.title || 'New Chat'}</span>
              {#if titleIsLoading}
                <Spinner size={14} class="animate-spin text-muted-foreground flex-shrink-0" />
              {/if}
            </h1>
          {/if}
          <div class="text-sm text-muted-foreground flex items-center gap-2 flex-wrap">
            {#if chat?.manual_responses}
              <ParticipantAvatars {agents} messages={allMessages} />
              <span class="ml-2">{formatTokenCount(totalTokens)} tokens</span>
            {:else}
              {chat?.model_label || chat?.model_id || 'Auto'}
              <span class="ml-2 text-xs">({formatTokenCount(totalTokens)} tokens)</span>
            {/if}

            {#if tokenWarningLevel === 'amber'}
              <Badge
                variant="outline"
                class="bg-amber-100 text-amber-800 border-amber-300 dark:bg-amber-900/30 dark:text-amber-400 dark:border-amber-700">
                Long conversation
              </Badge>
            {:else if tokenWarningLevel === 'red'}
              <Badge
                variant="outline"
                class="bg-red-100 text-red-800 border-red-300 dark:bg-red-900/30 dark:text-red-400 dark:border-red-700">
                Very long
              </Badge>
            {:else if tokenWarningLevel === 'critical'}
              <Badge variant="destructive">Extremely long</Badge>
            {/if}
          </div>
        </div>

        <!-- Actions dropdown menu -->
        {#if chat}
          <DropdownMenu.Root>
            <DropdownMenu.Trigger
              class="inline-flex items-center justify-center h-8 w-8 rounded-md text-sm font-medium ring-offset-background transition-colors hover:bg-accent hover:text-accent-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2">
              <DotsThreeVertical size={20} weight="bold" />
            </DropdownMenu.Trigger>
            <DropdownMenu.Content align="end" class="w-48">
              {#if !chat.manual_responses}
                <DropdownMenu.CheckboxItem checked={chat.web_access} onCheckedChange={toggleWebAccess}>
                  <Globe size={16} class="mr-2" weight="duotone" />
                  Allow web access
                </DropdownMenu.CheckboxItem>
                {#if available_agents.length > 0}
                  <DropdownMenu.Item onclick={() => (assignAgentOpen = true)}>
                    <Robot size={16} class="mr-2" weight="duotone" />
                    Assign to Agent
                  </DropdownMenu.Item>
                {/if}
                <DropdownMenu.Separator />
              {/if}
              {#if chat.manual_responses && addable_agents.length > 0}
                <DropdownMenu.Item onclick={() => (addAgentOpen = true)}>
                  <Robot size={16} class="mr-2" weight="duotone" />
                  Add Agent
                </DropdownMenu.Item>
              {/if}

              <DropdownMenu.Item onclick={forkConversation}>
                <GitFork size={16} class="mr-2" weight="duotone" />
                Fork
              </DropdownMenu.Item>

              {#if chat?.active_whiteboard}
                <DropdownMenu.Item onclick={() => (whiteboardOpen = true)}>
                  <Notepad size={16} class="mr-2" weight="duotone" />
                  Whiteboard
                </DropdownMenu.Item>
              {/if}

              <DropdownMenu.Separator />

              <DropdownMenu.Item onclick={archiveChat}>
                <Archive size={16} class="mr-2" weight="duotone" />
                {chat.archived ? 'Unarchive' : 'Archive'}
              </DropdownMenu.Item>

              {#if canDeleteChat}
                <DropdownMenu.Item
                  onclick={deleteChat}
                  class={chat.discarded
                    ? ''
                    : 'text-red-600 dark:text-red-400 focus:text-red-600 dark:focus:text-red-400'}>
                  {#if chat.discarded}
                    <ArrowCounterClockwise size={16} class="mr-2" weight="duotone" />
                    Restore
                  {:else}
                    <Trash size={16} class="mr-2" weight="duotone" />
                    Delete
                  {/if}
                </DropdownMenu.Item>
              {/if}

              {#if isSiteAdmin}
                <DropdownMenu.Separator />
                <DropdownMenu.Item onclick={moderateAllMessages}>
                  <ShieldCheck size={16} class="mr-2" weight="duotone" />
                  Moderate All Messages
                </DropdownMenu.Item>
                <DropdownMenu.CheckboxItem
                  checked={showAllMessages}
                  onCheckedChange={(checked) => (showAllMessages = checked)}>
                  Show all messages
                </DropdownMenu.CheckboxItem>
                <DropdownMenu.CheckboxItem
                  checked={debugMode}
                  onCheckedChange={(checked) => (debugMode = checked)}
                  class="text-orange-600 focus:text-orange-600">
                  Debug mode
                </DropdownMenu.CheckboxItem>
              {/if}
            </DropdownMenu.Content>
          </DropdownMenu.Root>
        {/if}
      </div>
    </header>

    <!-- Critical token warning banner -->
    {#if tokenWarningLevel === 'critical'}
      <div
        class="bg-red-100 dark:bg-red-900/50 border-b border-red-200 dark:border-red-800 px-4 py-2 text-sm text-red-800 dark:text-red-200">
        <WarningCircle size={16} class="inline mr-2" weight="fill" />
        This conversation is very long ({formatTokenCount(totalTokens)} tokens). Consider starting a new conversation.
      </div>
    {/if}

    <!-- Telegram notification banner -->
    {#if telegramDeepLink && !telegramBannerDismissed}
      <div
        class="border-b border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-950/30 px-4 py-2 text-sm flex items-center justify-between gap-3">
        <div>
          <span class="font-medium text-blue-800 dark:text-blue-200">Get notified on Telegram</span>
          <span class="text-blue-700 dark:text-blue-300 ml-1">
            -- Receive a notification when {telegramAgentName} reaches out.
          </span>
          <a
            href={telegramDeepLink}
            target="_blank"
            rel="noopener noreferrer"
            class="ml-2 text-blue-600 dark:text-blue-400 underline hover:text-blue-800 dark:hover:text-blue-200">
            Connect on Telegram
          </a>
        </div>
        <button
          onclick={dismissTelegramBanner}
          class="flex-shrink-0 p-1 text-blue-400 hover:text-blue-600 dark:text-blue-500 dark:hover:text-blue-300"
          title="Dismiss">
          <X size={16} />
        </button>
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
    <div
      bind:this={messagesContainer}
      onscroll={handleScroll}
      class="flex-1 overflow-y-auto px-3 md:px-6 py-4 space-y-4">
      {#if loadingMore}
        <div class="flex justify-center py-4">
          <Spinner size={24} class="animate-spin text-muted-foreground" />
        </div>
      {:else if hasMore && oldestId}
        <div class="flex justify-center py-2">
          <button onclick={loadMoreMessages} class="text-sm text-muted-foreground hover:text-foreground">
            Load earlier messages
          </button>
        </div>
      {/if}

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
              <div class="flex justify-end group">
                <div class="max-w-[85%] md:max-w-[70%]">
                  <div class="flex justify-end items-center gap-2">
                    {#if message.editable}
                      <button
                        onclick={() => startEditingMessage(message)}
                        class="p-1.5 rounded-full text-muted-foreground/50 hover:text-muted-foreground hover:bg-muted
                               opacity-50 hover:opacity-100 md:opacity-0 md:group-hover:opacity-100 transition-opacity
                               focus:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring"
                        title="Edit message">
                        <PencilSimple size={20} weight="regular" />
                      </button>
                    {/if}
                    {#if message.deletable}
                      <button
                        onclick={() => deleteMessage(message.id)}
                        class="p-1.5 rounded-full text-muted-foreground/50 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-950
                               opacity-50 hover:opacity-100 md:opacity-0 md:group-hover:opacity-100 transition-opacity
                               focus:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring"
                        title="Delete message">
                        <Trash size={20} weight="regular" />
                      </button>
                    {/if}
                    <Card.Root class="{getBubbleClass(message.author_colour)} w-fit">
                      <Card.Content class="p-4">
                        {#if message.files_json && message.files_json.length > 0}
                          <div class="space-y-2 mb-3">
                            {#each message.files_json as file}
                              <FileAttachment {file} onImageClick={openImageLightbox} />
                            {/each}
                          </div>
                        {/if}
                        <Streamdown
                          content={message.content}
                          parseIncompleteMarkdown
                          baseTheme="shadcn"
                          {shikiTheme}
                          shikiPreloadThemes={['catppuccin-latte', 'catppuccin-mocha']}
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
                  </div>
                  <div class="text-xs text-muted-foreground text-right mt-1 flex items-center justify-end gap-2">
                    <span class="group">
                      <span class="hidden group-hover:inline-block">({formatDateTime(message.created_at, true)})</span>
                      {formatTime(message.created_at)}
                    </span>
                    {#if chat?.manual_responses && message.author_name}
                      <span class="ml-1">· {message.author_name}</span>
                    {/if}
                    {#if message.moderation_scores}
                      <ModerationIndicator scores={message.moderation_scores} />
                    {/if}
                    {#if index === visibleMessages.length - 1 && lastUserMessageNeedsResend() && !waitingForResponse && !chat?.manual_responses}
                      <button onclick={resendLastMessage} class="ml-2 text-blue-600 hover:text-blue-700 underline">
                        Resend
                      </button>
                    {/if}
                  </div>
                </div>
              </div>
            {:else}
              <div class="flex justify-start group">
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
                        <!-- Show thinking block if thinking content exists -->
                        {#if message.thinking || streamingThinking[message.id]}
                          <ThinkingBlock
                            content={message.thinking || streamingThinking[message.id] || ''}
                            isStreaming={message.streaming && !message.thinking}
                            preview={message.thinking_preview} />
                        {/if}

                        <Streamdown
                          content={message.content}
                          parseIncompleteMarkdown
                          baseTheme="shadcn"
                          {shikiTheme}
                          shikiPreloadThemes={['catppuccin-latte', 'catppuccin-mocha']}
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
                  <div class="text-xs text-muted-foreground mt-1 flex items-center gap-2">
                    {#if message.moderation_scores}
                      <ModerationIndicator scores={message.moderation_scores} />
                    {/if}
                    {#if chat?.manual_responses && message.author_name}
                      <span class="mr-1">{message.author_name} ·</span>
                    {/if}
                    <span class="group">
                      {formatTime(message.created_at)}
                      <span class="hidden group-hover:inline-block">({formatDateTime(message.created_at, true)})</span>
                    </span>
                    {#if message.status === 'pending'}
                      <span class="ml-2 text-blue-600">...</span>
                    {:else if message.streaming}
                      <span class="ml-2 text-green-600 animate-pulse">...</span>
                    {/if}
                    {#if message.fixable}
                      <button
                        onclick={() => fixHallucinatedToolCalls(message.id)}
                        class="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-amber-500 transition-colors md:opacity-0 md:group-hover:opacity-100"
                        title="Fix hallucinated tool call">
                        <Wrench size={14} />
                        Fix
                      </button>
                    {/if}
                  </div>
                </div>
              </div>
            {/if}
          </div>
        {/each}

        <!-- Thinking bubble when last message is hidden (tool call or empty assistant) - only shown when not showing all messages -->
        {#if !showAllMessages && lastMessageIsHiddenThinking()}
          {@const lastMessage = allMessages[allMessages.length - 1]}
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

    <!-- Message input -->
    <div class="border-t border-border bg-muted/30 p-3 md:p-4">
      <div class="flex gap-2 md:gap-3 items-start">
        <FileUploadInput
          bind:files={selectedFiles}
          disabled={submitting || !chat?.respondable}
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
            disabled={submitting || !chat?.respondable}
            class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                   focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent
                   min-h-[40px] max-h-[240px] overflow-y-auto disabled:opacity-50 disabled:cursor-not-allowed"
            rows="1"></textarea>
        </div>
        <MicButton
          disabled={submitting || !chat?.respondable}
          accountId={account.id}
          chatId={chat.id}
          onsuccess={handleTranscription}
          onerror={handleTranscriptionError} />
        <button
          onclick={sendMessage}
          disabled={(!$messageForm.message.content.trim() && selectedFiles.length === 0) ||
            submitting ||
            !chat?.respondable}
          class="h-10 w-10 p-0 inline-flex items-center justify-center rounded-md bg-primary text-primary-foreground hover:bg-primary/90 disabled:pointer-events-none disabled:opacity-50">
          {#if submitting}
            <Spinner size={16} class="animate-spin" />
          {:else}
            <ArrowUp size={16} />
          {/if}
        </button>
      </div>
    </div>
  </main>
</div>

{#if chat?.active_whiteboard}
  <Drawer.Root bind:open={whiteboardOpen} direction="bottom">
    <Drawer.Content class="max-h-[85vh]">
      <Drawer.Header class="sr-only">
        <Drawer.Title>Whiteboard</Drawer.Title>
        <Drawer.Description>View and edit the active whiteboard</Drawer.Description>
      </Drawer.Header>

      <div class="flex flex-col h-full max-h-[80vh]">
        <div class="flex items-center justify-between px-4 py-3 border-b border-border">
          <div>
            <h3 class="font-semibold text-lg">{chat.active_whiteboard.name}</h3>
            {#if chat.active_whiteboard.last_edited_at}
              <p class="text-xs text-muted-foreground">
                Last edited {chat.active_whiteboard.last_edited_at}
                {#if chat.active_whiteboard.editor_name}
                  by {chat.active_whiteboard.editor_name}
                {/if}
              </p>
            {/if}
          </div>

          <div class="flex items-center gap-2">
            {#if whiteboardEditing}
              <Button variant="outline" size="sm" onclick={cancelEditingWhiteboard} disabled={whiteboardSaving}>
                <X class="mr-1 size-4" />
                Cancel
              </Button>
              <Button size="sm" onclick={saveWhiteboard} disabled={whiteboardSaving}>
                {#if whiteboardSaving}
                  <Spinner class="mr-1 size-4 animate-spin" />
                {:else}
                  <FloppyDisk class="mr-1 size-4" />
                {/if}
                Save
              </Button>
            {:else}
              <Button
                variant="outline"
                size="sm"
                onclick={startEditingWhiteboard}
                disabled={agentIsResponding}
                title={agentIsResponding ? 'Agent is updating whiteboard...' : undefined}>
                <PencilSimple class="mr-1 size-4" />
                Edit
              </Button>
            {/if}
          </div>
        </div>

        {#if whiteboardConflict}
          <div class="px-4 py-3 bg-amber-50 dark:bg-amber-950/30 border-b border-amber-200 dark:border-amber-800">
            <p class="font-semibold text-amber-800 dark:text-amber-200 mb-1">Someone else edited this whiteboard</p>
            <p class="text-sm text-amber-700 dark:text-amber-300 mb-3">
              Your changes have been preserved. Choose which version to keep:
            </p>
            <div class="flex gap-2">
              <Button variant="outline" size="sm" onclick={useServerVersion}>Use their version</Button>
              <Button size="sm" onclick={keepMyVersion}>Keep mine and save</Button>
            </div>
          </div>
        {/if}

        {#if agentIsResponding && !whiteboardEditing}
          <div
            class="px-4 py-2 bg-amber-50 dark:bg-amber-950/30 text-amber-700 dark:text-amber-400 text-sm flex items-center gap-2">
            <WarningCircle class="size-4" weight="fill" />
            Agent is updating whiteboard...
          </div>
        {/if}

        <div class="flex-1 overflow-y-auto p-4">
          {#if whiteboardEditing}
            <textarea
              bind:value={whiteboardEditContent}
              class="w-full h-full min-h-[300px] resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
                     focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"
              placeholder="Write your whiteboard content here..."></textarea>
          {:else if chat.active_whiteboard.content?.trim()}
            <div class="prose dark:prose-invert max-w-none">
              <Streamdown
                content={chat.active_whiteboard.content}
                parseIncompleteMarkdown={false}
                baseTheme="shadcn"
                {shikiTheme}
                shikiPreloadThemes={['catppuccin-latte', 'catppuccin-mocha']} />
            </div>
          {:else}
            <p class="text-muted-foreground text-center py-8">No content yet. Click Edit to add content.</p>
          {/if}
        </div>
      </div>
    </Drawer.Content>
  </Drawer.Root>
{/if}

<!-- Edit Message Drawer -->
<Drawer.Root bind:open={editDrawerOpen} onClose={() => !editSaving && cancelEditingMessage()}>
  <Drawer.Content class="max-h-[50vh]">
    <Drawer.Header>
      <Drawer.Title>Edit Message</Drawer.Title>
    </Drawer.Header>
    <div class="p-4 space-y-4">
      <textarea
        bind:value={editingContent}
        disabled={editSaving}
        class="w-full min-h-[100px] resize-none border border-input rounded-md px-3 py-2 text-sm bg-background focus:outline-none focus:ring-2 focus:ring-ring disabled:opacity-50"
      ></textarea>
      <div class="flex justify-end gap-2">
        <Button variant="outline" onclick={cancelEditingMessage} disabled={editSaving}>Cancel</Button>
        <Button onclick={saveEditedMessage} disabled={!editingContent.trim() || editSaving}>
          {#if editSaving}
            <Spinner size={16} class="mr-2 animate-spin" />
            Saving...
          {:else}
            Save
          {/if}
        </Button>
      </div>
    </div>
  </Drawer.Content>
</Drawer.Root>

<!-- Error toast -->
{#if errorMessage}
  <div
    class="fixed bottom-4 right-4 bg-destructive text-destructive-foreground px-4 py-2 rounded-lg shadow-lg z-50"
    transition:fade>
    {errorMessage}
  </div>
{/if}

<!-- Success toast -->
{#if successMessage}
  <div class="fixed bottom-4 right-4 bg-green-600 text-white px-4 py-2 rounded-lg shadow-lg z-50" transition:fade>
    {successMessage}
  </div>
{/if}

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
