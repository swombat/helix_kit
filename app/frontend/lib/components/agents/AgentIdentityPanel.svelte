<script>
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';

  let { form, availableVoices = [] } = $props();

  const isCustomVoice = $derived(
    $form.agent.voice_id && !availableVoices.some((voice) => voice.id === $form.agent.voice_id)
  );
</script>

<div class="space-y-6">
  <div>
    <h2 class="text-lg font-semibold">Agent Identity</h2>
    <p class="text-sm text-muted-foreground">Define the agent's name and personality</p>
  </div>

  <div class="space-y-2">
    <Label for="name">Name</Label>
    <Input
      id="name"
      type="text"
      bind:value={$form.agent.name}
      placeholder="e.g., Research Assistant"
      required
      maxlength={100} />
    {#if $form.errors.name}
      <p class="text-sm text-destructive">{$form.errors.name}</p>
    {/if}
  </div>

  <div class="space-y-2">
    <Label for="system_prompt">System Prompt</Label>
    <textarea
      id="system_prompt"
      bind:value={$form.agent.system_prompt}
      placeholder="You are a helpful research assistant that..."
      rows="6"
      class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
             focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
    <p class="text-xs text-muted-foreground">Define the agent's personality, expertise, and behavior guidelines.</p>
  </div>

  <div class="space-y-2">
    <Label for="reflection_prompt">Reflection Prompt</Label>
    <textarea
      id="reflection_prompt"
      bind:value={$form.agent.reflection_prompt}
      placeholder="Leave empty to use default reflection prompt"
      rows="8"
      class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
             focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
    <p class="text-xs text-muted-foreground">
      Customize how the agent reflects on conversations to extract memories. Leave empty to use the default prompt. The
      prompt can use %{'{'}system_prompt{'}'} and %{'{'}existing_memories{'}'} placeholders.
    </p>
  </div>

  <div class="space-y-2">
    <Label for="memory_reflection_prompt">Memory Reflection Prompt</Label>
    <textarea
      id="memory_reflection_prompt"
      bind:value={$form.agent.memory_reflection_prompt}
      placeholder="Leave empty to use default memory reflection prompt"
      rows="8"
      class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
             focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
    <p class="text-xs text-muted-foreground">
      Customize how the agent reviews journal entries to promote them to core memories. Leave empty to use the default
      prompt. The prompt can use %{'{'}core_memories{'}'} and %{'{'}journal_entries{'}'} placeholders.
    </p>
  </div>

  <div class="space-y-2">
    <Label for="summary_prompt">Summary Prompt</Label>
    <textarea
      id="summary_prompt"
      bind:value={$form.agent.summary_prompt}
      placeholder="Leave empty to use default summary prompt (focus on state, 2 lines)"
      rows="6"
      class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
             focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
    <p class="text-xs text-muted-foreground">
      Customize how this agent summarizes conversations for cross-conversation awareness. Leave empty for the default
      prompt that focuses on current state rather than narrative.
    </p>
  </div>

  <div class="space-y-2">
    <Label for="refinement_prompt">Refinement Prompt</Label>
    <textarea
      id="refinement_prompt"
      bind:value={$form.agent.refinement_prompt}
      placeholder="Leave empty to use default refinement guidelines"
      rows="6"
      class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background font-mono
             focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
    <p class="text-xs text-muted-foreground">
      Guidelines for memory refinement sessions. Added alongside the system prompt when the agent reviews its own
      memories. Leave empty for the default guidelines.
    </p>
  </div>

  <div class="space-y-2">
    <Label for="refinement_threshold">Refinement Retention Threshold</Label>
    <div class="flex items-center gap-3 max-w-xs">
      <Input
        id="refinement_threshold"
        type="number"
        min={0.5}
        max={1.0}
        step={0.05}
        bind:value={$form.agent.refinement_threshold}
        class="w-24" />
      <span class="text-sm text-muted-foreground">{Math.round($form.agent.refinement_threshold * 100)}%</span>
    </div>
    <p class="text-xs text-muted-foreground">
      Circuit breaker: if refinement reduces core memory below this percentage of its pre-session size, all changes are
      rolled back. Default is 90%.
    </p>
  </div>

  <div class="flex items-center justify-between">
    <div class="space-y-1">
      <Label for="active">Active</Label>
      <p class="text-sm text-muted-foreground">For future filtering in agent selection</p>
    </div>
    <Switch id="active" checked={$form.agent.active} onCheckedChange={(checked) => ($form.agent.active = checked)} />
  </div>

  <div class="flex items-center justify-between">
    <div class="space-y-1">
      <Label for="paused">Paused</Label>
      <p class="text-sm text-muted-foreground">
        Excludes this agent from cron-driven sweeps (memory refinement, reflection, conversation initiation, "Trigger
        Initiation"). Manual triggers — replying in chats, the agent_trigger endpoint, the API — still work. Use this
        for retired predecessors or any agent that should remain reachable but not act on its own.
      </p>
    </div>
    <Switch id="paused" checked={$form.agent.paused} onCheckedChange={(checked) => ($form.agent.paused = checked)} />
  </div>

  <div class="space-y-2">
    <Label for="voice_id">Voice</Label>
    <select
      id="voice_id"
      value={isCustomVoice ? 'custom' : $form.agent.voice_id || ''}
      onchange={(event) => {
        if (event.target.value === 'custom') {
          $form.agent.voice_id = $form.agent.voice_id || '';
        } else {
          $form.agent.voice_id = event.target.value;
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
      <Input
        type="text"
        bind:value={$form.agent.voice_id}
        placeholder="Paste ElevenLabs voice ID"
        class="max-w-md mt-2" />
    {/if}
    <p class="text-xs text-muted-foreground">Select a voice for text-to-speech playback, or leave empty to disable.</p>
  </div>
</div>
