<script>
  import * as Card from '$lib/components/shadcn/card/index.js';
  import { ChatCircle, Notepad } from 'phosphor-svelte';

  let { whiteboards = [], selected = null, onSelect } = $props();

  function characterCount(whiteboard) {
    if (whiteboard.content_length >= 1000) {
      return `${(whiteboard.content_length / 1000).toFixed(1)}k`;
    }

    return whiteboard.content_length;
  }
</script>

<div class="space-y-3">
  {#each whiteboards as whiteboard (whiteboard.id)}
    <button onclick={() => onSelect(whiteboard.id)} class="w-full text-left">
      <Card.Root
        class="hover:border-primary/50 transition-colors {selected?.id === whiteboard.id
          ? 'border-primary ring-1 ring-primary'
          : ''}">
        <Card.Content class="p-4">
          <div class="flex items-start justify-between gap-2">
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold truncate">{whiteboard.name}</h3>
              {#if whiteboard.summary}
                <p class="text-sm text-muted-foreground line-clamp-2 mt-1">{whiteboard.summary}</p>
              {/if}
            </div>
            <Notepad class="size-5 text-muted-foreground shrink-0" weight="duotone" />
          </div>

          <div class="flex items-center gap-3 mt-3 text-xs text-muted-foreground">
            <span>{characterCount(whiteboard)} chars</span>
            <span>Rev {whiteboard.revision}</span>
            {#if whiteboard.active_chat_count > 0}
              <span class="flex items-center gap-1">
                <ChatCircle class="size-3" />
                {whiteboard.active_chat_count}
                {whiteboard.active_chat_count === 1 ? 'chat' : 'chats'}
              </span>
            {/if}
          </div>
        </Card.Content>
      </Card.Root>
    </button>
  {/each}
</div>
