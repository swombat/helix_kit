<script>
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import AgentAppearanceFields from '$lib/components/agents/AgentAppearanceFields.svelte';

  let {
    name = $bindable(''),
    colour = $bindable(null),
    icon = $bindable(null),
    nameError = null,
    colourOptions = [],
    iconOptions = [],
  } = $props();
</script>

<div class="space-y-6">
  <div>
    <h2 class="text-lg font-semibold">Appearance</h2>
    <p class="text-sm text-muted-foreground">Customise how this agent appears throughout HelixKit.</p>
  </div>

  <div class="space-y-2">
    <Label for="name">Display name</Label>
    <Input id="name" type="text" bind:value={name} required maxlength={100} class="max-w-md" />
    {#if nameError}
      <p class="text-sm text-destructive">{nameError}</p>
    {/if}
    <p class="text-xs text-muted-foreground">
      This changes the name displayed in HelixKit. It may or may not change the name the agent chooses for itself in
      <span class="font-mono">soul.md</span>.
    </p>
  </div>

  <AgentAppearanceFields bind:colour bind:icon {colourOptions} {iconOptions} />
</div>
