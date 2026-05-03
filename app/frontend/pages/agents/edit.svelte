<script>
  import { useForm, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import { ArrowLeft, IdentificationCard, Palette, Cpu, Plug, Notebook } from 'phosphor-svelte';
  import {
    accountAgentsPath,
    accountAgentPath,
    accountAgentTelegramTestPath,
    accountAgentTelegramWebhookPath,
    accountAgentRefinementPath,
    accountAgentMemoriesPath,
    accountAgentMemoryDiscardPath,
    accountAgentMemoryProtectionPath,
  } from '@/routes';
  import { useSync } from '$lib/use-sync';
  import { modelSupportsThinking as modelCanThink } from '$lib/agent-models';
  import AgentAppearanceFields from '$lib/components/agents/AgentAppearanceFields.svelte';
  import AgentMemoryPanel from '$lib/components/agents/AgentMemoryPanel.svelte';
  import AgentModelSelect from '$lib/components/agents/AgentModelSelect.svelte';
  import AgentSettingsTabs from '$lib/components/agents/AgentSettingsTabs.svelte';
  import AgentToolChecklist from '$lib/components/agents/AgentToolChecklist.svelte';

  let {
    agent,
    telegram_deep_link: telegramDeepLink = null,
    telegram_subscriber_count: telegramSubscriberCount = 0,
    memories = [],
    grouped_models = {},
    available_tools = [],
    available_voices = [],
    colour_options = [],
    icon_options = [],
    account,
  } = $props();

  useSync({
    [`Agent:${agent.id}`]: ['agent', 'memories'],
  });

  let selectedModel = $state(agent.model_id);
  let sendingTestNotification = $state(false);
  let registeringWebhook = $state(false);
  let triggeringRefinement = $state(false);
  let activeTab = $state('identity');
  let customVoiceId = $state('');

  const isCustomVoice = $derived($form.agent.voice_id && !available_voices.some((v) => v.id === $form.agent.voice_id));

  const tabs = [
    { id: 'identity', label: 'Identity', icon: IdentificationCard },
    { id: 'appearance', label: 'Appearance', icon: Palette },
    { id: 'model', label: 'Model', icon: Cpu },
    { id: 'integrations', label: 'Integrations', icon: Plug },
    { id: 'memory', label: 'Memory', icon: Notebook },
  ];

  let form = useForm({
    agent: {
      name: agent.name,
      system_prompt: agent.system_prompt || '',
      reflection_prompt: agent.reflection_prompt || '',
      memory_reflection_prompt: agent.memory_reflection_prompt || '',
      summary_prompt: agent.summary_prompt || '',
      refinement_prompt: agent.refinement_prompt || '',
      refinement_threshold: agent.refinement_threshold ?? 0.9,
      model_id: agent.model_id,
      active: agent.active,
      paused: agent.paused || false,
      enabled_tools: agent.enabled_tools || [],
      colour: agent.colour || null,
      icon: agent.icon || null,
      thinking_enabled: agent.thinking_enabled || false,
      thinking_budget: agent.thinking_budget || 10000,
      telegram_bot_username: agent.telegram_bot_username || '',
      telegram_bot_token: agent.telegram_bot_token || '',
      voice_id: agent.voice_id || '',
    },
  });

  function updateAgent() {
    $form.agent.model_id = selectedModel;
    $form.patch(accountAgentPath(account.id, agent.id));
  }

  function deleteMemory(memoryId) {
    if (confirm('Discard this memory?')) {
      router.post(
        accountAgentMemoryDiscardPath(account.id, agent.id, memoryId),
        {},
        {
          preserveScroll: true,
        }
      );
    }
  }

  function undiscardMemory(memoryId) {
    router.delete(accountAgentMemoryDiscardPath(account.id, agent.id, memoryId), { preserveScroll: true });
  }

  function triggerRefinement(mode = 'full') {
    triggeringRefinement = true;
    router.post(
      accountAgentRefinementPath(account.id, agent.id),
      { mode },
      {
        preserveScroll: true,
        onFinish() {
          triggeringRefinement = false;
        },
      }
    );
  }

  function toggleConstitutional(memoryId, isCurrentlyProtected) {
    if (isCurrentlyProtected) {
      router.delete(accountAgentMemoryProtectionPath(account.id, agent.id, memoryId), { preserveScroll: true });
    } else {
      router.post(accountAgentMemoryProtectionPath(account.id, agent.id, memoryId), {}, { preserveScroll: true });
    }
  }

  function sendTestNotification() {
    sendingTestNotification = true;
    router.post(
      accountAgentTelegramTestPath(account.id, agent.id),
      {},
      {
        preserveScroll: true,
        onFinish() {
          sendingTestNotification = false;
        },
      }
    );
  }

  function registerWebhook() {
    registeringWebhook = true;
    router.post(
      accountAgentTelegramWebhookPath(account.id, agent.id),
      {},
      {
        preserveScroll: true,
        onFinish() {
          registeringWebhook = false;
        },
      }
    );
  }

  function createMemory({ content, memoryType }) {
    router.post(
      accountAgentMemoriesPath(account.id, agent.id),
      {
        memory: {
          content,
          memory_type: memoryType,
        },
      },
      {
        preserveScroll: true,
      }
    );
  }
</script>

<svelte:head>
  <title>Edit {agent.name}</title>
</svelte:head>

<div class="p-8 max-w-5xl mx-auto">
  <div class="mb-8">
    <a
      href={accountAgentsPath(account.id)}
      class="inline-flex items-center text-sm text-muted-foreground hover:text-foreground mb-4">
      <ArrowLeft class="mr-1 size-4" />
      Back to Agents
    </a>
    <h1 class="text-3xl font-bold">Edit Agent</h1>
    <p class="text-muted-foreground mt-1">Update {agent.name}'s configuration</p>
  </div>

  <form
    onsubmit={(e) => {
      e.preventDefault();
      updateAgent();
    }}>
    <div class="flex flex-col md:flex-row gap-6 md:gap-8">
      <AgentSettingsTabs {tabs} bind:activeTab />

      <!-- Content area -->
      <div class="flex-1 min-w-0 space-y-6">
        {#if activeTab === 'identity'}
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
              <p class="text-xs text-muted-foreground">
                Define the agent's personality, expertise, and behavior guidelines.
              </p>
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
                Customize how the agent reflects on conversations to extract memories. Leave empty to use the default
                prompt. The prompt can use %{'{'}system_prompt{'}'} and %{'{'}existing_memories{'}'} placeholders.
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
                Customize how the agent reviews journal entries to promote them to core memories. Leave empty to use the
                default prompt. The prompt can use %{'{'}core_memories{'}'} and %{'{'}journal_entries{'}'} placeholders.
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
                Customize how this agent summarizes conversations for cross-conversation awareness. Leave empty for the
                default prompt that focuses on current state rather than narrative.
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
                Guidelines for memory refinement sessions. Added alongside the system prompt when the agent reviews its
                own memories. Leave empty for the default guidelines.
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
                Circuit breaker: if refinement reduces core memory below this percentage of its pre-session size, all
                changes are rolled back. Default is 90%.
              </p>
            </div>

            <div class="flex items-center justify-between">
              <div class="space-y-1">
                <Label for="active">Active</Label>
                <p class="text-sm text-muted-foreground">For future filtering in agent selection</p>
              </div>
              <Switch
                id="active"
                checked={$form.agent.active}
                onCheckedChange={(checked) => ($form.agent.active = checked)} />
            </div>

            <div class="flex items-center justify-between">
              <div class="space-y-1">
                <Label for="paused">Paused</Label>
                <p class="text-sm text-muted-foreground">
                  Excludes this agent from cron-driven sweeps (memory refinement, reflection, conversation initiation,
                  "Trigger Initiation"). Manual triggers — replying in chats, the agent_trigger endpoint, the API —
                  still work. Use this for retired predecessors or any agent that should remain reachable but not act on
                  its own.
                </p>
              </div>
              <Switch
                id="paused"
                checked={$form.agent.paused}
                onCheckedChange={(checked) => ($form.agent.paused = checked)} />
            </div>

            <div class="space-y-2">
              <Label for="voice_id">Voice</Label>
              <select
                id="voice_id"
                value={isCustomVoice ? 'custom' : $form.agent.voice_id || ''}
                onchange={(e) => {
                  if (e.target.value === 'custom') {
                    customVoiceId = $form.agent.voice_id || '';
                    $form.agent.voice_id = customVoiceId;
                  } else {
                    $form.agent.voice_id = e.target.value;
                  }
                }}
                class="w-full max-w-md border border-input rounded-md px-3 py-2 text-sm bg-background
                       focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent">
                <option value="">No voice</option>
                {#each available_voices as voice (voice.id)}
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
              <p class="text-xs text-muted-foreground">
                Select a voice for text-to-speech playback, or leave empty to disable.
              </p>
            </div>
          </div>
        {:else if activeTab === 'appearance'}
          <div class="space-y-6">
            <div>
              <h2 class="text-lg font-semibold">Chat Appearance</h2>
              <p class="text-sm text-muted-foreground">Customise how this agent appears in group chats</p>
            </div>

            <AgentAppearanceFields
              bind:colour={$form.agent.colour}
              bind:icon={$form.agent.icon}
              colourOptions={colour_options}
              iconOptions={icon_options} />
          </div>
        {:else if activeTab === 'model'}
          <div class="space-y-8">
            <div class="space-y-4">
              <div>
                <h2 class="text-lg font-semibold">AI Model</h2>
                <p class="text-sm text-muted-foreground">Choose which AI model powers this agent</p>
              </div>
              <AgentModelSelect groupedModels={grouped_models} bind:value={selectedModel} />
            </div>

            <div class="space-y-4">
              <div>
                <h2 class="text-lg font-semibold">Extended Thinking</h2>
                <p class="text-sm text-muted-foreground">
                  Allow the model to show its reasoning process before responding
                </p>
              </div>
              {#if modelCanThink(grouped_models, selectedModel)}
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
                  The selected model does not support extended thinking. Choose Claude 4+, GPT-5, or Gemini 3 Pro to
                  enable this feature.
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
              <AgentToolChecklist tools={available_tools} bind:enabledTools={$form.agent.enabled_tools} />
            </div>
          </div>
        {:else if activeTab === 'integrations'}
          <div class="space-y-6">
            <div>
              <h2 class="text-lg font-semibold">Telegram Notifications</h2>
              <p class="text-sm text-muted-foreground">
                Connect a Telegram bot to send notifications when this agent initiates conversations or replies.
              </p>
            </div>

            <div class="space-y-2">
              <Label for="telegram_bot_username">Bot Username</Label>
              <Input
                id="telegram_bot_username"
                type="text"
                bind:value={$form.agent.telegram_bot_username}
                placeholder="e.g., my_agent_bot" />
              <p class="text-xs text-muted-foreground">
                Create a bot via <a
                  href="https://t.me/botfather"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="underline">@BotFather</a> on Telegram, then paste the username here.
              </p>
            </div>

            <div class="space-y-2">
              <Label for="telegram_bot_token">Bot Token</Label>
              <Input
                id="telegram_bot_token"
                type="password"
                bind:value={$form.agent.telegram_bot_token}
                placeholder="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11" />
              <p class="text-xs text-muted-foreground">
                The API token provided by BotFather. Leave blank to keep the current token. Stored encrypted.
              </p>
            </div>

            {#if agent.telegram_configured}
              <div class="p-3 rounded-lg bg-muted/50 space-y-2">
                <p class="text-sm font-medium">Your Registration Link</p>
                <p class="text-xs text-muted-foreground">
                  Use this to connect your own Telegram account for testing. Other users will see their own link in the
                  chat UI.
                </p>
                <code class="text-xs block p-2 bg-background rounded border break-all">
                  {telegramDeepLink}
                </code>
              </div>

              <div class="p-3 rounded-lg bg-muted/50 space-y-2">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm font-medium">Test Notifications</p>
                    <p class="text-xs text-muted-foreground">
                      {telegramSubscriberCount} subscriber{telegramSubscriberCount === 1 ? '' : 's'} connected
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    disabled={sendingTestNotification || telegramSubscriberCount === 0}
                    onclick={sendTestNotification}>
                    {sendingTestNotification ? 'Sending...' : 'Send Test Notification'}
                  </Button>
                </div>
              </div>

              <div class="p-3 rounded-lg bg-muted/50 space-y-2">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm font-medium">Webhook</p>
                    <p class="text-xs text-muted-foreground">
                      Re-register the webhook if Telegram isn't receiving updates.
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    disabled={registeringWebhook}
                    onclick={registerWebhook}>
                    {registeringWebhook ? 'Registering...' : 'Re-register Webhook'}
                  </Button>
                </div>
              </div>
            {/if}
          </div>
        {:else if activeTab === 'memory'}
          <AgentMemoryPanel
            {agent}
            {memories}
            {triggeringRefinement}
            onrefine={triggerRefinement}
            oncreate={createMemory}
            ondelete={deleteMemory}
            onundiscard={undiscardMemory}
            ontoggleProtected={toggleConstitutional} />
        {/if}

        <div class="flex justify-end gap-3">
          <a href={accountAgentsPath(account.id)}>
            <Button type="button" variant="outline">Cancel</Button>
          </a>
          <Button type="submit" disabled={$form.processing}>
            {$form.processing ? 'Saving...' : 'Update Agent'}
          </Button>
        </div>
      </div>
    </div>
  </form>
</div>
