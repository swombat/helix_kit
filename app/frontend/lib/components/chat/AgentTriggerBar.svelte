<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import {
    Robot,
    Spinner,
    UsersThree,
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
  } from 'phosphor-svelte';
  import { triggerAgentAccountChatPath, triggerAllAgentsAccountChatPath } from '@/routes';

  // Map icon names to components
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

  let { agents = [], accountId, chatId, disabled = false } = $props();
  let triggeringAgent = $state(null);
  let triggeringAll = $state(false);

  function triggerAgent(agent) {
    if (triggeringAgent || triggeringAll) return;
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

  function triggerAllAgents() {
    if (triggeringAgent || triggeringAll) return;
    triggeringAll = true;

    router.post(
      triggerAllAgentsAccountChatPath(accountId, chatId),
      {},
      {
        onFinish: () => {
          triggeringAll = false;
        },
        onError: () => {
          triggeringAll = false;
        },
      }
    );
  }

  const isTriggering = $derived(triggeringAgent !== null || triggeringAll);
</script>

{#if agents.length > 0}
  <div class="border-t border-border px-3 md:px-6 py-3 bg-muted/20">
    <div class="flex items-center gap-2 flex-wrap">
      <span class="text-xs text-muted-foreground mr-2 hidden md:inline">Ask agent:</span>
      {#each agents as agent (agent.id)}
        {@const IconComponent = iconComponents[agent.icon] || Robot}
        <Button
          variant="outline"
          size="sm"
          onclick={() => triggerAgent(agent)}
          disabled={disabled || isTriggering}
          class="gap-2 {agent.colour
            ? `border-${agent.colour}-300 dark:border-${agent.colour}-700 hover:bg-${agent.colour}-50 dark:hover:bg-${agent.colour}-950`
            : ''}"
          title={agent.name}>
          {#if triggeringAgent === agent.id}
            <Spinner size={14} class="animate-spin" />
          {:else}
            <IconComponent
              size={14}
              weight="duotone"
              class={agent.colour ? `text-${agent.colour}-600 dark:text-${agent.colour}-400` : ''} />
          {/if}
          <span class="hidden md:inline">{agent.name}</span>
        </Button>
      {/each}
      {#if agents.length > 1}
        <Button
          variant="default"
          size="sm"
          onclick={triggerAllAgents}
          disabled={disabled || isTriggering}
          class="gap-2 ml-2"
          title="Ask All Agents">
          {#if triggeringAll}
            <Spinner size={14} class="animate-spin" />
          {:else}
            <UsersThree size={14} weight="duotone" />
          {/if}
          <span class="hidden md:inline">Ask All</span>
        </Button>
      {/if}
    </div>
  </div>
{/if}
