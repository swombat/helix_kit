<script>
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import AgentAppearanceFields from '$lib/components/agents/AgentAppearanceFields.svelte';

  let {
    colour = $bindable(null),
    icon = $bindable(null),
    voiceId = $bindable(''),
    colourOptions = [],
    iconOptions = [],
    availableVoices = [],
  } = $props();

  const isCustomVoice = $derived(voiceId && !availableVoices.some((voice) => voice.id === voiceId));
</script>

<div class="space-y-6">
  <div>
    <h2 class="text-lg font-semibold">Chat Appearance</h2>
    <p class="text-sm text-muted-foreground">Customise how this agent appears in group chats</p>
  </div>

  <AgentAppearanceFields bind:colour bind:icon {colourOptions} {iconOptions} />

  <div class="space-y-2">
    <Label for="voice_id">Voice</Label>
    <select
      id="voice_id"
      value={isCustomVoice ? 'custom' : voiceId || ''}
      onchange={(event) => {
        if (event.target.value === 'custom') {
          voiceId = voiceId || '';
        } else {
          voiceId = event.target.value;
        }
      }}
      class="w-full max-w-md border border-input rounded-md px-3 py-2 text-sm bg-background
             focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent">
      <option value="">No voice</option>
      {#each availableVoices as voice (voice.id)}
        <option value={voice.id}>{voice.name}</option>
      {/each}
      <option value="custom">Custom voice ID...</option>
    </select>
    {#if isCustomVoice}
      <Input type="text" bind:value={voiceId} placeholder="Paste ElevenLabs voice ID" class="max-w-md mt-2" />
    {/if}
    <p class="text-xs text-muted-foreground">Select a voice for text-to-speech playback, or leave empty to disable.</p>
  </div>
</div>
