<script>
  import { agentIconFor } from '$lib/agent-icons';

  let { agents = [], selectedAgentIds = $bindable([]) } = $props();

  function toggleAgent(agentId) {
    if (selectedAgentIds.includes(agentId)) {
      selectedAgentIds = selectedAgentIds.filter((id) => id !== agentId);
      return;
    }

    selectedAgentIds = [...selectedAgentIds, agentId];
  }
</script>

{#if agents.length > 0}
  <div class="border-b border-border px-4 md:px-6 py-3 bg-muted/5">
    <div class="text-sm font-medium mb-2">Select agents to participate:</div>
    <div class="flex flex-wrap gap-2">
      {#each agents as agent (agent.id)}
        {@const IconComponent = agentIconFor(agent.icon)}
        {@const isSelected = selectedAgentIds.includes(agent.id)}
        <button
          type="button"
          onclick={() => toggleAgent(agent.id)}
          class="inline-flex items-center gap-2 px-3 py-1.5 rounded-md text-sm border transition-colors
                 {isSelected
            ? agent.colour
              ? `bg-${agent.colour}-100 dark:bg-${agent.colour}-900 border-${agent.colour}-400 dark:border-${agent.colour}-600 text-${agent.colour}-700 dark:text-${agent.colour}-300`
              : 'bg-primary text-primary-foreground border-primary'
            : agent.colour
              ? `bg-transparent border-${agent.colour}-300 dark:border-${agent.colour}-700 hover:bg-${agent.colour}-50 dark:hover:bg-${agent.colour}-950 text-${agent.colour}-600 dark:text-${agent.colour}-400`
              : 'bg-muted hover:bg-muted/80 text-muted-foreground border-border'}">
          <IconComponent
            size={14}
            weight="duotone"
            class={agent.colour && !isSelected ? `text-${agent.colour}-600 dark:text-${agent.colour}-400` : ''} />
          {agent.name}
        </button>
      {/each}
    </div>
    {#if selectedAgentIds.length === 0}
      <p class="text-xs text-amber-600 mt-2">Select at least one agent to start a group chat</p>
    {/if}
  </div>
{/if}
