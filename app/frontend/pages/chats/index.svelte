<script>
  import { page } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { ChatCircle, Plus, Sparkle } from 'phosphor-svelte';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import ChatList from './ChatList.svelte';
  import { accountChatsPath } from '@/routes';

  let { chats = [], account } = $props();

  const createChatForm = useForm({
    ai_model_name: 'gpt-4o-mini',
  });

  function createNewChat() {
    $createChatForm.post(accountChatsPath(account.id));
  }
</script>

<svelte:head>
  <title>Chats</title>
</svelte:head>

<div class="flex h-[calc(100vh-4rem)]">
  <!-- Left sidebar: Chat list -->
  <ChatList {chats} activeChatId={null} accountId={account.id} />

  <!-- Right side: Welcome message -->
  <main class="flex-1 overflow-y-auto bg-background">
    <div class="flex items-center justify-center h-full">
      <div class="text-center max-w-md mx-auto px-4">
        <div class="w-20 h-20 mx-auto mb-6 rounded-full bg-primary/10 flex items-center justify-center">
          <ChatCircle size={40} class="text-primary" />
        </div>

        <h1 class="text-2xl font-semibold mb-3">Start a conversation</h1>
        <p class="text-muted-foreground mb-8">
          Choose an AI model and begin chatting. Your conversations will appear in the sidebar.
        </p>

        <Card.Root class="max-w-sm mx-auto">
          <Card.Header class="pb-4">
            <Card.Title class="text-lg flex items-center gap-2">
              <Sparkle size={20} class="text-primary" />
              New Chat
            </Card.Title>
          </Card.Header>
          <Card.Content class="space-y-4">
            <div>
              <label for="model-select" class="block text-sm font-medium mb-2"> Select AI Model </label>
              <Select.Root bind:value={$createChatForm.data.ai_model_name}>
                <Select.Trigger class="w-full" id="model-select">
                  <Select.Value placeholder="Select AI model" />
                </Select.Trigger>
                <Select.Content>
                  <Select.Item value="gpt-4o-mini">GPT-4o Mini</Select.Item>
                  <Select.Item value="gpt-4o">GPT-4o</Select.Item>
                  <Select.Item value="claude-3-5-sonnet-20241022">Claude 3.5 Sonnet</Select.Item>
                  <Select.Item value="claude-3-5-haiku-20241022">Claude 3.5 Haiku</Select.Item>
                </Select.Content>
              </Select.Root>
            </div>

            <Button onclick={createNewChat} disabled={$createChatForm.processing} class="w-full">
              {#if $createChatForm.processing}
                Creating...
              {:else}
                <Plus size={16} class="mr-2" />
                Start New Chat
              {/if}
            </Button>
          </Card.Content>
        </Card.Root>
      </div>
    </div>
  </main>
</div>
