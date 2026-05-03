<script>
  import { useForm, router } from '@inertiajs/svelte';
  import { useSync } from '$lib/use-sync';
  import {
    accountAgentsPath,
    accountAgentPath,
    accountAgentInitiationPath,
    accountAgentPredecessorPath,
  } from '@/routes';
  import { findModelLabel as modelLabelFor, firstModelId } from '$lib/agent-models';
  import AgentEmptyState from '$lib/components/agents/AgentEmptyState.svelte';
  import AgentGrid from '$lib/components/agents/AgentGrid.svelte';
  import AgentIndexHeader from '$lib/components/agents/AgentIndexHeader.svelte';
  import AgentUpgradeDialog from '$lib/components/agents/AgentUpgradeDialog.svelte';
  import CreateAgentDialog from '$lib/components/agents/CreateAgentDialog.svelte';

  let {
    agents = [],
    grouped_models = {},
    available_tools = [],
    colour_options = [],
    icon_options = [],
    account,
  } = $props();

  // Subscribe to both:
  // - Account:${id}:agents - individual agent updates (via collection subscription)
  // - Account:${id} - new agent creation (via broadcasts_to :account)
  useSync({
    [`Account:${account.id}:agents`]: 'agents',
    [`Account:${account.id}`]: 'agents',
  });

  let showCreateModal = $state(false);
  let selectedModel = $state(firstModelId(grouped_models));

  // Upgrade-with-predecessor modal state.
  // The agent the user clicked "Upgrade" on becomes the *successor* — its
  // model_id changes to targetModel, keeping its conversations, telegram bot,
  // voice. A *predecessor* is created at the current model with copied memories.
  let showUpgradeModal = $state(false);
  let upgradingAgent = $state(null);
  let predecessorName = $state('');
  let targetModel = $state('openrouter/auto');
  let upgradeProcessing = $state(false);

  // Build lookup map for tool display names
  const toolNameLookup = $derived(Object.fromEntries(available_tools.map((t) => [t.class_name, t.name])));

  let form = useForm({
    agent: {
      name: '',
      system_prompt: '',
      model_id: firstModelId(grouped_models),
      active: true,
      enabled_tools: [],
      colour: null,
      icon: null,
    },
  });

  function createAgent() {
    $form.agent.model_id = selectedModel;
    $form.post(accountAgentsPath(account.id), {
      onSuccess: () => {
        showCreateModal = false;
        resetForm();
      },
    });
  }

  function resetForm() {
    $form.agent.name = '';
    $form.agent.system_prompt = '';
    $form.agent.model_id = firstModelId(grouped_models);
    $form.agent.active = true;
    $form.agent.enabled_tools = [];
    $form.agent.colour = null;
    $form.agent.icon = null;
    selectedModel = $form.agent.model_id;
  }

  function deleteAgent(agent) {
    if (!confirm(`Delete agent "${agent.name}"? This cannot be undone.`)) return;
    router.delete(accountAgentPath(account.id, agent.id));
  }

  function openUpgradeModal(agent) {
    upgradingAgent = agent;
    predecessorName = `${agent.name} (${modelLabelFor(grouped_models, agent.model_id)})`;
    targetModel = agent.model_id;
    showUpgradeModal = true;
  }

  function submitUpgrade() {
    if (!upgradingAgent) return;
    upgradeProcessing = true;
    router.post(
      accountAgentPredecessorPath(account.id, upgradingAgent.id),
      { to_model: targetModel, predecessor_name: predecessorName },
      {
        onFinish: () => {
          upgradeProcessing = false;
        },
        onSuccess: () => {
          showUpgradeModal = false;
          upgradingAgent = null;
        },
      }
    );
  }
</script>

<svelte:head>
  <title>Agents</title>
</svelte:head>

<div class="p-8 max-w-6xl mx-auto">
  <AgentIndexHeader
    onInitiate={() => router.post(accountAgentInitiationPath(account.id))}
    onCreate={() => (showCreateModal = true)} />

  {#if agents.length === 0}
    <AgentEmptyState onCreate={() => (showCreateModal = true)} />
  {:else}
    <AgentGrid {agents} accountId={account.id} {toolNameLookup} onUpgrade={openUpgradeModal} onDelete={deleteAgent} />
  {/if}
</div>

<CreateAgentDialog
  bind:open={showCreateModal}
  {form}
  bind:selectedModel
  groupedModels={grouped_models}
  availableTools={available_tools}
  colourOptions={colour_options}
  iconOptions={icon_options}
  onsubmit={createAgent} />

<AgentUpgradeDialog
  bind:open={showUpgradeModal}
  agent={upgradingAgent}
  groupedModels={grouped_models}
  bind:predecessorName
  bind:targetModel
  processing={upgradeProcessing}
  onsubmit={submitUpgrade} />
