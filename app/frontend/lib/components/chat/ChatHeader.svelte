<script>
  import { page } from '@inertiajs/svelte';
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Badge } from '$lib/components/shadcn/badge/index.js';
  import * as DropdownMenu from '$lib/components/shadcn/dropdown-menu/index.js';
  import {
    List,
    Spinner,
    Globe,
    GitFork,
    Notepad,
    DotsThreeVertical,
    Robot,
    ShieldCheck,
    Archive,
    Trash,
    ArrowCounterClockwise,
  } from 'phosphor-svelte';
  import ParticipantAvatars from '$lib/components/chat/ParticipantAvatars.svelte';
  import {
    accountChatForkPath,
    accountChatModerationPath,
    accountChatArchivePath,
    accountChatDiscardPath,
  } from '@/routes';
  import * as logging from '$lib/logging';
  import { formatTokenCount } from '$lib/chat-utils';

  let {
    chat,
    account,
    agents = [],
    allMessages = [],
    totalTokens = 0,
    thresholds = { amber: 100_000, red: 150_000, critical: 200_000 },
    availableAgents = [],
    addableAgents = [],
    showAllMessages = $bindable(false),
    debugMode = $bindable(false),
    onsidebaropen,
    onassignagent,
    onaddagent,
    onwhiteboardopen,
    onerror,
    onsuccess,
  } = $props();

  // Check if current user is a site admin
  const isSiteAdmin = $derived($page.props.user?.site_admin ?? false);

  // Check if current user is an account admin
  const isAccountAdmin = $derived($page.props.is_account_admin ?? false);

  // Check if user can delete chats (account admin or site admin)
  const canDeleteChat = $derived(isAccountAdmin || isSiteAdmin);

  // Token warning level
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

  // Check if title is loading (no title yet but has messages) - cosmetic only
  const titleIsLoading = $derived(chat && !chat.title && allMessages?.length > 0);

  // Title editing state
  let titleEditing = $state(false);
  let titleEditValue = $state('');
  let titleInputRef = $state(null);
  let originalTitle = $state('');

  // Focus title input when editing starts
  $effect(() => {
    if (titleEditing && titleInputRef) {
      titleInputRef.focus();
      titleInputRef.select();
    }
  });

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
          onerror?.('Failed to update title');
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
        onsuccess?.(`Queued moderation for ${data.queued} messages`);
      } else {
        onerror?.('Failed to queue moderation');
      }
    } catch (error) {
      onerror?.('Failed to queue moderation');
    }
  }
</script>

<header class={headerClass}>
  <div class="flex items-center gap-3">
    <Button variant="ghost" size="sm" onclick={() => onsidebaropen?.()} class="h-8 w-8 p-0 md:hidden">
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
            {#if availableAgents.length > 0}
              <DropdownMenu.Item onclick={() => onassignagent?.()}>
                <Robot size={16} class="mr-2" weight="duotone" />
                Assign to Agent
              </DropdownMenu.Item>
            {/if}
            <DropdownMenu.Separator />
          {/if}
          {#if chat.manual_responses && addableAgents.length > 0}
            <DropdownMenu.Item onclick={() => onaddagent?.()}>
              <Robot size={16} class="mr-2" weight="duotone" />
              Add Agent
            </DropdownMenu.Item>
          {/if}

          <DropdownMenu.Item onclick={forkConversation}>
            <GitFork size={16} class="mr-2" weight="duotone" />
            Fork
          </DropdownMenu.Item>

          {#if chat?.active_whiteboard}
            <DropdownMenu.Item onclick={() => onwhiteboardopen?.()}>
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
              class={chat.discarded ? '' : 'text-red-600 dark:text-red-400 focus:text-red-600 dark:focus:text-red-400'}>
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
