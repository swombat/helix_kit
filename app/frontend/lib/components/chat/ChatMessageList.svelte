<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import MessageBubble from '$lib/components/chat/MessageBubble.svelte';
  import { ArrowClockwise, Spinner } from 'phosphor-svelte';
  import { fade } from 'svelte/transition';

  let {
    messagesContainer = $bindable(),
    loadingMore = false,
    hasMore = false,
    oldestId = null,
    visibleMessages = [],
    allMessages = [],
    chat = null,
    showAllMessages = false,
    lastMessageIsHiddenThinking = false,
    shouldShowSendingPlaceholder = false,
    isTimedOut = false,
    lastUserMessageNeedsResend = false,
    waitingForResponse = false,
    streamingThinking = {},
    shikiTheme = 'catppuccin-latte',
    showAgentPrompt = false,
    handleScroll = () => {},
    loadMoreMessages = () => {},
    shouldShowTimestamp = () => false,
    timestampLabel = () => '',
    startEditingMessage = () => {},
    deleteMessage = () => {},
    retryMessage = () => {},
    fixHallucinatedToolCalls = () => {},
    resendLastMessage = () => {},
    openImageLightbox = () => {},
    requestVoice = () => {},
  } = $props();
</script>

<!-- Messages container -->
<div bind:this={messagesContainer} onscroll={handleScroll} class="flex-1 overflow-y-auto px-3 md:px-6 py-4 space-y-4">
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

      <MessageBubble
        {message}
        isLastVisible={index === visibleMessages.length - 1}
        isGroupChat={chat?.manual_responses}
        showResend={index === visibleMessages.length - 1 &&
          lastUserMessageNeedsResend &&
          !waitingForResponse &&
          !chat?.manual_responses}
        streamingThinking={streamingThinking[message.id] || ''}
        {shikiTheme}
        onedit={startEditingMessage}
        ondelete={deleteMessage}
        onretry={retryMessage}
        onfix={fixHallucinatedToolCalls}
        onresend={resendLastMessage}
        onimagelightbox={openImageLightbox}
        onvoice={requestVoice} />
    {/each}

    <!-- Thinking bubble when last message is hidden (tool call or empty assistant) - only shown when not showing all messages -->
    {#if !showAllMessages && lastMessageIsHiddenThinking}
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
              {#if isTimedOut}
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
