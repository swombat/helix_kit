<script>
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import { modelSupportsThinking } from '$lib/agent-models';
  import AgentModelSelect from '$lib/components/agents/AgentModelSelect.svelte';
  import AgentToolChecklist from '$lib/components/agents/AgentToolChecklist.svelte';

  let { form, groupedModels = {}, availableTools = [], selectedModel = $bindable() } = $props();
</script>

<div class="space-y-8">
  <div class="space-y-4">
    <div>
      <h2 class="text-lg font-semibold">AI Model</h2>
      <p class="text-sm text-muted-foreground">Choose which AI model powers this agent</p>
    </div>
    <AgentModelSelect {groupedModels} bind:value={selectedModel} />
  </div>

  <div class="space-y-4">
    <div>
      <h2 class="text-lg font-semibold">Extended Thinking</h2>
      <p class="text-sm text-muted-foreground">Allow the model to show its reasoning process before responding</p>
    </div>
    {#if modelSupportsThinking(groupedModels, selectedModel)}
      <div class="flex items-center justify-between">
        <div class="space-y-1">
          <Label for="thinking_enabled">Enable Thinking</Label>
          <p class="text-sm text-muted-foreground">Show the model's reasoning process in responses</p>
        </div>
        <Switch
          id="thinking_enabled"
          checked={$form.agent.thinking_enabled}
          onCheckedChange={(checked) => ($form.agent.thinking_enabled = checked)} />
      </div>

      {#if $form.agent.thinking_enabled}
        <div class="space-y-2">
          <Label for="thinking_budget">Thinking Budget (tokens)</Label>
          <Input
            id="thinking_budget"
            type="number"
            min={1000}
            max={50000}
            step={1000}
            bind:value={$form.agent.thinking_budget}
            class="max-w-xs" />
          <p class="text-xs text-muted-foreground">Maximum tokens for reasoning (1,000 - 50,000)</p>
        </div>
      {/if}
    {:else}
      <p class="text-sm text-muted-foreground">
        The selected model does not support extended thinking. Choose Claude 4+, GPT-5, or Gemini 3 Pro to enable this
        feature.
      </p>
    {/if}
  </div>

  <div class="space-y-4">
    <div>
      <h2 class="text-lg font-semibold">Tools & Capabilities</h2>
      <p class="text-sm text-muted-foreground">
        Select which tools this agent can use. New tools will be disabled by default.
      </p>
    </div>
    <AgentToolChecklist tools={availableTools} bind:enabledTools={$form.agent.enabled_tools} />
  </div>
</div>
