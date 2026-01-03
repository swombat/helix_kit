<script>
  import { Link, router, page } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import {
    Plus,
    ChatCircle,
    ChatText,
    X,
    Spinner,
    Robot,
    Brain,
    Sparkle,
    Lightning,
    Star,
    Heart,
    Sun,
    Moon,
    Eye,
    Globe,
    Compass,
    Rocket,
    Atom,
    Lightbulb,
    Crown,
    Shield,
    Fire,
    Target,
    Trophy,
    Flask,
    Code,
    Cube,
    PuzzlePiece,
    Cat,
    Dog,
    Bird,
    Alien,
    Ghost,
    Detective,
    Butterfly,
    Flower,
    Tree,
    Leaf,
    Archive,
    Trash,
  } from 'phosphor-svelte';
  import { accountChatsPath, accountChatPath, newAccountChatPath } from '@/routes';

  const iconComponents = {
    Robot,
    Brain,
    Sparkle,
    Lightning,
    Star,
    Heart,
    Sun,
    Moon,
    Eye,
    Globe,
    Compass,
    Rocket,
    Atom,
    Lightbulb,
    Crown,
    Shield,
    Fire,
    Target,
    Trophy,
    Flask,
    Code,
    Cube,
    PuzzlePiece,
    Cat,
    Dog,
    Bird,
    Alien,
    Ghost,
    Detective,
    Butterfly,
    Flower,
    Tree,
    Leaf,
  };

  function getInitials(name) {
    if (!name) return '?';
    return name
      .split(' ')
      .map((part) => part.charAt(0))
      .slice(0, 2)
      .join('')
      .toUpperCase();
  }

  let { chats = [], activeChatId = null, accountId, isOpen = false, onClose = () => {} } = $props();

  // Check if user can see deleted chats
  const canSeeDeleted = $derived($page.props.is_account_admin || $page.props.user?.site_admin);

  // Show deleted toggle state
  let showDeleted = $state(
    typeof window !== 'undefined' ? new URLSearchParams(window.location.search).get('show_deleted') === 'true' : false
  );

  function toggleShowDeleted() {
    showDeleted = !showDeleted;
    const url = new URL(window.location.href);
    if (showDeleted) {
      url.searchParams.set('show_deleted', 'true');
    } else {
      url.searchParams.delete('show_deleted');
    }
    router.visit(url.toString(), { preserveState: true });
  }

  function createNewChat() {
    router.visit(newAccountChatPath(accountId));
  }

  function formatDate(dateString) {
    if (!dateString) return '';
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return '';
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
    });
  }
</script>

<!-- Mobile overlay -->
{#if isOpen}
  <button class="fixed inset-0 bg-black/50 z-40 md:hidden" onclick={onClose} aria-label="Close sidebar"></button>
{/if}

<aside
  class="w-80 border-r border-border bg-card flex flex-col
              fixed inset-y-0 left-0 z-50 transform transition-transform duration-200 ease-in-out
              md:relative md:translate-x-0 md:z-auto
              {isOpen ? 'translate-x-0' : '-translate-x-full'}">
  <header class="p-4 border-b border-border bg-muted/30">
    <div class="flex items-center justify-between mb-3">
      <h2 class="text-lg font-semibold">Chats</h2>
      <div class="flex items-center gap-2">
        <Button variant="outline" size="sm" onclick={createNewChat} class="h-8 w-8 p-0">
          <Plus size={16} />
        </Button>
        <Button variant="ghost" size="sm" onclick={onClose} class="h-8 w-8 p-0 md:hidden">
          <X size={16} />
        </Button>
      </div>
    </div>
    {#if canSeeDeleted}
      <label
        class="flex items-center gap-1.5 text-xs text-muted-foreground cursor-pointer hover:opacity-80 transition-opacity">
        <input
          type="checkbox"
          checked={showDeleted}
          onchange={toggleShowDeleted}
          class="w-3 h-3 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-1 transition-colors cursor-pointer" />
        <Trash size={12} />
        <span>Deleted</span>
      </label>
    {/if}
  </header>

  <div class="flex-1 overflow-y-auto">
    {#if chats.length === 0}
      <div class="p-4 text-center text-muted-foreground">
        <ChatCircle size={32} class="mx-auto mb-2 opacity-50" />
        <p class="text-sm">No chats yet</p>
      </div>
    {:else}
      <nav>
        {#each chats as chat (chat.id)}
          <Link
            href={accountChatPath(accountId, chat.id)}
            class="block p-3 hover:bg-muted/50 transition-colors border-b border-border
                   {activeChatId === chat.id ? 'bg-primary/10 border-l-4 border-l-primary' : ''}
                   {chat.archived ? 'opacity-50' : ''}
                   {chat.discarded ? 'opacity-40' : ''}">
            <div
              class="font-medium text-sm truncate flex items-center gap-2 {chat.discarded
                ? 'line-through text-red-600 dark:text-red-400'
                : ''}">
              {#if chat.archived && !chat.discarded}
                <Archive size={12} class="text-muted-foreground flex-shrink-0" />
              {/if}
              {#if chat.discarded}
                <Trash size={12} class="text-red-500 flex-shrink-0" />
              {/if}
              <span class="truncate">{chat.title_or_default || chat.title || 'New Chat'}</span>
              {#if !chat.title && chat.message_count > 0}
                <Spinner size={12} class="animate-spin text-muted-foreground flex-shrink-0" />
              {/if}
            </div>
            <div class="flex items-center gap-2 w-full group">
              {#if chat.manual_responses && chat.participants_json?.length > 0}
                <!-- Group chat: show participant avatars -->
                <div class="flex items-center -space-x-1 opacity-20 group-hover:opacity-100 transition-opacity">
                  {#each chat.participants_json.slice(0, 7) as participant, i (participant.name + i)}
                    {#if participant.type === 'agent'}
                      {@const IconComponent = iconComponents[participant.icon] || Robot}
                      <div
                        class="w-5 h-5 rounded-full flex items-center justify-center border border-background {participant.colour
                          ? `bg-${participant.colour}-100 dark:bg-${participant.colour}-900`
                          : 'bg-muted'}"
                        title={participant.name}>
                        <IconComponent
                          size={10}
                          weight="duotone"
                          class={participant.colour
                            ? `text-${participant.colour}-600 dark:text-${participant.colour}-400`
                            : 'text-muted-foreground'} />
                      </div>
                    {:else if participant.avatar_url}
                      <img
                        src={participant.avatar_url}
                        alt={participant.name}
                        title={participant.name}
                        class="w-5 h-5 rounded-full border border-background object-cover" />
                    {:else}
                      <div
                        class="w-5 h-5 rounded-full flex items-center justify-center border border-background text-[8px] font-medium {participant.colour
                          ? `bg-${participant.colour}-100 dark:bg-${participant.colour}-900 text-${participant.colour}-700 dark:text-${participant.colour}-300`
                          : 'bg-muted text-muted-foreground'}"
                        title={participant.name}>
                        {getInitials(participant.name)}
                      </div>
                    {/if}
                  {/each}
                  {#if chat.participants_json.length > 7}
                    <div
                      class="w-5 h-5 rounded-full flex items-center justify-center border border-background bg-muted text-[8px] font-medium text-muted-foreground"
                      title="{chat.participants_json.length - 7} more participants">
                      ...
                    </div>
                  {/if}
                </div>
              {:else}
                <!-- Regular chat: show model label on hover -->
                <div class="text-xs text-muted-foreground flex-1/3 hidden group-hover:block">
                  {chat.model_label}
                </div>
              {/if}
              <div class="text-xs text-muted-foreground flex-1/3 flex items-end justify-end hidden group-hover:block">
                {chat.updated_at_short || formatDate(chat.updated_at)}
              </div>
              <div class="text-xs text-muted-foreground flex-1/3 flex items-end justify-end gap-1">
                <ChatText size={12} />
                {chat.message_count}
              </div>
            </div>
          </Link>
        {/each}
      </nav>
    {/if}
  </div>
</aside>
