<script>
  import AgentAppearanceFields from '$lib/components/agents/AgentAppearanceFields.svelte';

  let { colour = $bindable(null), icon = $bindable(null), colourOptions = [], iconOptions = [] } = $props();
</script>

<div class="space-y-6">
  <div>
    <h2 class="text-lg font-semibold">Chat Appearance</h2>
    <p class="text-sm text-muted-foreground">Customise how this agent appears in group chats</p>
  </div>

  <AgentAppearanceFields bind:colour bind:icon {colourOptions} {iconOptions} />
</div>
