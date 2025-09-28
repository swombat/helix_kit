<script>
  import { Link, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Plus, ChatCircle, ChatText } from 'phosphor-svelte';
  import { accountChatsPath, accountChatPath, newAccountChatPath } from '@/routes';

  let { chats = [], activeChatId = null, accountId } = $props();

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

<aside class="w-80 border-r border-border bg-card flex flex-col">
  <header class="p-4 border-b border-border bg-muted/30">
    <div class="flex items-center justify-between mb-3">
      <h2 class="text-lg font-semibold">Chats</h2>
      <Button variant="outline" size="sm" onclick={createNewChat} class="h-8 w-8 p-0">
        <Plus size={16} />
      </Button>
    </div>
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
                   {activeChatId === chat.id ? 'bg-primary/10 border-l-4 border-l-primary' : ''}">
            <div class="font-medium text-sm truncate">
              {chat.title_or_default || chat.title || 'New Chat'}
            </div>
            <div class="flex items-center gap-2 w-full group">
              <div class="text-xs text-muted-foreground flex-1/3 hidden group-hover:block">
                {chat.model_name}
              </div>
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
