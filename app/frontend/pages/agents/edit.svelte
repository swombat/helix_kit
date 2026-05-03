<script>
  import { useForm, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
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
  import AgentAppearanceFields from '$lib/components/agents/AgentAppearanceFields.svelte';
  import AgentIdentityPanel from '$lib/components/agents/AgentIdentityPanel.svelte';
  import AgentIntegrationsPanel from '$lib/components/agents/AgentIntegrationsPanel.svelte';
  import AgentMemoryPanel from '$lib/components/agents/AgentMemoryPanel.svelte';
  import AgentModelPanel from '$lib/components/agents/AgentModelPanel.svelte';
  import AgentSettingsTabs from '$lib/components/agents/AgentSettingsTabs.svelte';

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
          <AgentIdentityPanel {form} availableVoices={available_voices} />
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
          <AgentModelPanel {form} groupedModels={grouped_models} availableTools={available_tools} bind:selectedModel />
        {:else if activeTab === 'integrations'}
          <AgentIntegrationsPanel
            {form}
            {agent}
            {telegramDeepLink}
            {telegramSubscriberCount}
            {sendingTestNotification}
            {registeringWebhook}
            onsendTestNotification={sendTestNotification}
            onregisterWebhook={registerWebhook} />
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
