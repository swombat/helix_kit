<script>
  import { agentIconFor } from '$lib/agent-icons';
  import { initialsFor } from '$lib/chat-display';

  let { participants = [] } = $props();
</script>

<div class="flex items-center -space-x-1 opacity-20 group-hover:opacity-100 transition-opacity">
  {#each participants.slice(0, 7) as participant, i (participant.name + i)}
    {#if participant.type === 'agent'}
      {@const IconComponent = agentIconFor(participant.icon)}
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
        {initialsFor(participant.name)}
      </div>
    {/if}
  {/each}
  {#if participants.length > 7}
    <div
      class="w-5 h-5 rounded-full flex items-center justify-center border border-background bg-muted text-[8px] font-medium text-muted-foreground"
      title="{participants.length - 7} more participants">
      ...
    </div>
  {/if}
</div>
