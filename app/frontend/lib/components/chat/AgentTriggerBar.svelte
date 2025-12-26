<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Robot, Spinner } from 'phosphor-svelte';
  import { triggerAgentAccountChatPath } from '@/routes';

  let { agents = [], accountId, chatId, disabled = false } = $props();
  let triggeringAgent = $state(null);

  function triggerAgent(agent) {
    if (triggeringAgent) return;
    triggeringAgent = agent.id;

    router.post(
      triggerAgentAccountChatPath(accountId, chatId, agent.id),
      {},
      {
        onFinish: () => {
          triggeringAgent = null;
        },
        onError: () => {
          triggeringAgent = null;
        },
      }
    );
  }
</script>

{#if agents.length > 0}
  <div class="border-t border-border px-6 py-3 bg-muted/20">
    <div class="flex items-center gap-2 flex-wrap">
      <span class="text-xs text-muted-foreground mr-2">Ask agent:</span>
      {#each agents as agent (agent.id)}
        <Button
          variant="outline"
          size="sm"
          onclick={() => triggerAgent(agent)}
          disabled={disabled || triggeringAgent !== null}
          class="gap-2">
          {#if triggeringAgent === agent.id}
            <Spinner size={14} class="animate-spin" />
          {:else}
            <Robot size={14} weight="duotone" />
          {/if}
          {agent.name}
        </Button>
      {/each}
    </div>
  </div>
{/if}
