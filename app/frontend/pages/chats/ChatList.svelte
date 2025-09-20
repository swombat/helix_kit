<script>
  import { Link } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Plus, ChatCircle } from 'phosphor-svelte';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import { accountChatsPath, accountChatPath } from '@/routes';

  let { chats = [], activeChatId = null, accountId } = $props();

  const createChatForm = useForm({
    ai_model_name: 'gpt-4o-mini',
  });

  function createNewChat() {
    $createChatForm.post(accountChatsPath(accountId));
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
      <Button
        variant="outline"
        size="sm"
        onclick={createNewChat}
        disabled={$createChatForm.processing}
        class="h-8 w-8 p-0">
        <Plus size={16} />
      </Button>
    </div>

    <Select.Root
      value={$createChatForm.data.ai_model_name}
      onValueChange={(value) => ($createChatForm.data.ai_model_name = value)}>
      <Select.Trigger class="w-full h-8 text-sm">
        <span>{$createChatForm.data.ai_model_name || 'Select AI model'}</span>
      </Select.Trigger>
      <Select.Content>
        <Select.Item value="gpt-4o-mini">GPT-4o Mini</Select.Item>
        <Select.Item value="gpt-4o">GPT-4o</Select.Item>
        <Select.Item value="claude-3-5-sonnet-20241022">Claude 3.5 Sonnet</Select.Item>
        <Select.Item value="claude-3-5-haiku-20241022">Claude 3.5 Haiku</Select.Item>
      </Select.Content>
    </Select.Root>
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
            <div class="text-xs text-muted-foreground mt-1">
              {chat.updated_at_short || formatDate(chat.updated_at)}
            </div>
          </Link>
        {/each}
      </nav>
    {/if}
  </div>
</aside>
