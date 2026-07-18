<script>
  import { useForm, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import { IdentificationCard, Palette, Cpu, Plug, Notebook, CloudArrowUp } from 'phosphor-svelte';
  import {
    accountAgentsPath,
    accountAgentPath,
    accountAgentTelegramTestPath,
    accountAgentTelegramWebhookPath,
    accountAgentRefinementPath,
    accountAgentMemoriesPath,
    accountAgentMemoryDiscardPath,
    accountAgentMemoryProtectionPath,
    beginPromoteAccountAgentPath,
    cancelPromoteAccountAgentPath,
    sendOrientationAccountAgentPath,
    sendTestRequestAccountAgentPath,
  } from '@/routes';
  import { useSync } from '$lib/use-sync';
  import AgentAppearancePanel from '$lib/components/agents/AgentAppearancePanel.svelte';
  import AgentEditHeader from '$lib/components/agents/AgentEditHeader.svelte';
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
    active_tab: activeTabProp = null,
    local_dev_endpoint_mode: localDevEndpointMode = false,
    identity_export_url: identityExportUrl = null,
    hosting_diagnostics_url: hostingDiagnosticsUrl = null,
    runtime_observability_url: runtimeObservabilityUrl = null,
    sandbox_recreation_url: sandboxRecreationUrl = null,
    runtime_interactions: runtimeInteractions = [],
    account,
  } = $props();

  useSync({
    [`Agent:${agent.id}`]: ['agent', 'memories', 'runtime_interactions'],
  });

  let selectedModel = $state(agent.model_id);
  let sendingTestNotification = $state(false);
  let registeringWebhook = $state(false);
  let triggeringRefinement = $state(false);
  let activeTab = $state(activeTabProp || 'identity');
  let identityLocked = $derived(agent.runtime === 'external' || agent.runtime === 'offline');
  let runtimeManaged = $derived(agent.runtime === 'external' || agent.runtime === 'offline');
  let promoting = $state(false);
  let sendingTestRequest = $state(false);
  let sendingOrientation = $state(false);
  let recreatingSandbox = $state(false);
  let testResult = $state(null);
  let orientationResult = $state(null);
  let sandboxStatus = $state({
    docker_available: null,
    image_present: agent.container_image ? null : false,
    container_exists: agent.container_name && (agent.runtime === 'external' || agent.runtime === 'migrating'),
    identity_volume_exists: agent.uuid ? null : false,
    chaos_volume_exists: agent.uuid ? null : false,
    repo_volume_exists: agent.uuid ? null : false,
  });
  let filesystemDump = $state({});
  let containerFilesystemDump = $state({});
  let filePreviews = $state({});
  let expandedFilesystemDirs = $state({});
  let diagnosticsLoading = $state(false);
  let diagnosticsLoaded = $state(false);
  let diagnosticsError = $state(null);
  let showFormActions = $derived(
    !runtimeManaged ||
      activeTab === 'appearance' ||
      activeTab === 'model' ||
      activeTab === 'integrations' ||
      activeTab === 'hosting'
  );
  let filesystemSections = $derived([
    {
      title: 'Container home filesystem',
      description:
        'Read-only dump of the running container home directory. The persisted Chaos state folder is intentionally hidden.',
      dump: containerFilesystemDump,
      target: 'container_home',
      fallbackRoot: '/home/agent',
    },
    {
      title: 'Identity filesystem',
      description: 'Read-only dump of the mounted identity filesystem.',
      dump: filesystemDump,
      target: 'identity',
      fallbackRoot: '/home/agent/identity',
    },
  ]);

  const tabs = [
    { id: 'identity', label: 'Identity', icon: IdentificationCard },
    { id: 'appearance', label: 'Appearance', icon: Palette },
    { id: 'model', label: 'Model', icon: Cpu },
    { id: 'integrations', label: 'Integrations', icon: Plug },
    { id: 'memory', label: 'Memory', icon: Notebook },
    { id: 'hosting', label: 'Hosting', icon: CloudArrowUp },
  ];

  let beginPromotePath = $derived(beginPromoteAccountAgentPath(account.id, agent.id));
  let cancelPromotePath = $derived(cancelPromoteAccountAgentPath(account.id, agent.id));
  let testRequestPath = $derived(sendTestRequestAccountAgentPath(account.id, agent.id));
  let orientationPath = $derived(sendOrientationAccountAgentPath(account.id, agent.id));

  $effect(() => {
    if (activeTab === 'hosting' && !diagnosticsLoaded && !diagnosticsLoading && !diagnosticsError) {
      loadHostingDiagnostics();
    }
  });

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
      persistent_session: agent.persistent_session || false,
      persistent_wake_session: agent.persistent_wake_session || false,
      scheduled_wakes_enabled: agent.scheduled_wakes_enabled ?? true,
      half_hourly_wake: agent.half_hourly_wake || false,
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

  function recreateSandbox() {
    if (!sandboxRecreationUrl || recreatingSandbox) return;

    if (
      !confirm(
        'Refresh this hosted sandbox runtime? This replaces the container with one built from the current runtime image. The identity and Chaos volumes will be preserved, but any container-local files outside mounted volumes will be lost.'
      )
    ) {
      return;
    }

    recreatingSandbox = true;
    router.post(
      sandboxRecreationUrl,
      {},
      {
        preserveScroll: true,
        onFinish() {
          recreatingSandbox = false;
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

  function csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || '';
  }

  function loadHostingDiagnostics() {
    if (!hostingDiagnosticsUrl || diagnosticsLoading) return;

    diagnosticsLoading = true;
    diagnosticsError = null;

    fetch(hostingDiagnosticsUrl, {
      headers: {
        Accept: 'application/json',
      },
    })
      .then((response) => response.json().then((body) => ({ ok: response.ok, body })))
      .then(({ ok, body }) => {
        if (!ok) {
          throw new Error(body.error || 'Could not load hosting diagnostics');
        }

        sandboxStatus = body.sandbox_status || {};
        filesystemDump = body.filesystem_dump || {};
        containerFilesystemDump = body.container_filesystem_dump || {};
        diagnosticsLoaded = true;
      })
      .catch((error) => {
        diagnosticsError = error.message;
      })
      .finally(() => {
        diagnosticsLoading = false;
      });
  }

  function directoryKey(section, entryOrPath) {
    const path = typeof entryOrPath === 'string' ? entryOrPath : entryOrPath.path;
    return `${section.target}:${path}`;
  }

  function directoryExpanded(section, entry) {
    return expandedFilesystemDirs[directoryKey(section, entry)] === true;
  }

  function toggleDirectory(section, entry) {
    const key = directoryKey(section, entry);
    expandedFilesystemDirs = { ...expandedFilesystemDirs, [key]: !expandedFilesystemDirs[key] };
  }

  function entryVisible(section, entry) {
    if (entry.depth === 0) return true;

    const parts = entry.path.split('/');
    let ancestor = '';
    for (let index = 0; index < parts.length - 1; index += 1) {
      ancestor = ancestor ? `${ancestor}/${parts[index]}` : parts[index];
      if (!expandedFilesystemDirs[directoryKey(section, ancestor)]) return false;
    }

    return true;
  }

  function filePreviewKey(section, entry) {
    return `${section.target}:${entry.path}`;
  }

  function filePreviewUrl(section, entry) {
    const url = new URL(`${hostingDiagnosticsUrl}/file_preview`, window.location.origin);
    url.searchParams.set('target', section.target);
    url.searchParams.set('path', entry.path);
    return url.toString();
  }

  function loadFilePreview(section, entry, event) {
    if (!event.currentTarget.open || !entry.previewable || !hostingDiagnosticsUrl) return;

    const key = filePreviewKey(section, entry);
    if (filePreviews[key]?.loading || filePreviews[key]?.loaded) return;

    filePreviews = { ...filePreviews, [key]: { loading: true } };

    fetch(filePreviewUrl(section, entry), { headers: { Accept: 'application/json' } })
      .then((response) => response.json().then((body) => ({ ok: response.ok, body })))
      .then(({ ok, body }) => {
        filePreviews = {
          ...filePreviews,
          [key]: ok ? { ...body, loaded: true } : { error: body.error || 'Could not load preview', loaded: true },
        };
      })
      .catch((error) => {
        filePreviews = { ...filePreviews, [key]: { error: error.message, loaded: true } };
      });
  }

  function beginPromotion() {
    promoting = true;
    router.post(
      beginPromotePath,
      {},
      {
        preserveScroll: true,
        onFinish: () => {
          promoting = false;
        },
      }
    );
  }

  function cancelPromotion() {
    router.post(cancelPromotePath, {}, { preserveScroll: true });
  }

  function sendTestRequest() {
    sendingTestRequest = true;
    testResult = null;

    fetch(testRequestPath, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken(),
      },
    })
      .then((response) => response.json().then((body) => ({ ok: response.ok, body })))
      .then(({ ok, body }) => {
        testResult = ok ? body : { status: 'transport_failed', error: body.error || 'Test request failed' };
        loadHostingDiagnostics();
      })
      .catch((error) => {
        testResult = { status: 'transport_failed', error: error.message };
      })
      .finally(() => {
        sendingTestRequest = false;
      });
  }

  function sendOrientation() {
    sendingOrientation = true;
    orientationResult = null;

    fetch(orientationPath, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken(),
      },
    })
      .then((response) => response.json().then((body) => ({ ok: response.ok, body })))
      .then(({ ok, body }) => {
        orientationResult = ok ? body : { status: 'transport_failed', error: body.error || 'Orientation failed' };
        router.reload({ only: ['agent', 'runtime_interactions'], preserveScroll: true });
        loadHostingDiagnostics();
      })
      .catch((error) => {
        orientationResult = { status: 'transport_failed', error: error.message };
      })
      .finally(() => {
        sendingOrientation = false;
      });
  }
</script>

<svelte:head>
  <title>Edit {agent.name}</title>
</svelte:head>

<div class="p-8 max-w-5xl mx-auto">
  <AgentEditHeader backHref={accountAgentsPath(account.id)} agentName={agent.name} />

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
          <AgentIdentityPanel {form} {identityLocked} />
        {:else if activeTab === 'appearance'}
          <AgentAppearancePanel
            bind:colour={$form.agent.colour}
            bind:icon={$form.agent.icon}
            bind:voiceId={$form.agent.voice_id}
            colourOptions={colour_options}
            iconOptions={icon_options}
            availableVoices={available_voices} />
        {:else if activeTab === 'model'}
          <AgentModelPanel
            {form}
            groupedModels={grouped_models}
            availableTools={available_tools}
            {runtimeManaged}
            bind:selectedModel />
          {#if runtimeManaged}
            <div class="border rounded-lg p-4 text-sm text-muted-foreground">
              Model changes take effect on the next trigger; no sandbox rebuild is needed. Extended-thinking and tool
              settings remain managed by the external coding runtime.
            </div>
          {/if}
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
            locked={runtimeManaged}
            onrefine={triggerRefinement}
            oncreate={createMemory}
            ondelete={deleteMemory}
            onundiscard={undiscardMemory}
            ontoggleProtected={toggleConstitutional} />
        {:else if activeTab === 'hosting'}
          <div class="space-y-6">
            <div class="border rounded-lg p-6 space-y-5">
              <div class="space-y-1">
                <h2 class="text-xl font-semibold">Hosting</h2>
                <p class="text-sm text-muted-foreground">
                  Current runtime: <span class="font-medium text-foreground">{agent.runtime || 'inline'}</span>
                </p>
              </div>

              <div class="grid gap-2 text-sm sm:grid-cols-2">
                {#if agent.container_name}
                  <p>Container: <span class="font-mono">{agent.container_name}</span></p>
                {/if}
                {#if agent.container_image}
                  <p>Image: <span class="font-mono">{agent.container_image}</span></p>
                {/if}
                {#if agent.sandbox_host}
                  <p>Sandbox host: <span class="font-mono">{agent.sandbox_host}</span></p>
                {/if}
                {#if agent.endpoint_url}
                  <p>Dev endpoint: <span class="font-mono">{agent.endpoint_url}</span></p>
                {/if}
                <p>Health: <span class="font-medium">{agent.health_state || 'unknown'}</span></p>
              </div>

              <div class="flex items-center justify-between gap-6 rounded border bg-muted/30 p-4">
                <div class="space-y-1">
                  <Label for="scheduled_wakes_enabled">Scheduled heartbeats</Label>
                  <p class="text-sm text-muted-foreground">
                    Allow HelixKit to wake this agent for hourly heartbeats and any optional 30-minute heartbeats.
                  </p>
                </div>
                <Switch
                  id="scheduled_wakes_enabled"
                  checked={$form.agent.scheduled_wakes_enabled}
                  disabled={!runtimeManaged}
                  onCheckedChange={(checked) => ($form.agent.scheduled_wakes_enabled = checked)} />
              </div>

              <div class="flex items-center justify-between gap-6 rounded border bg-muted/30 p-4">
                <div class="space-y-1">
                  <Label for="persistent_session">Persistent conversation sessions</Label>
                  <p class="text-sm text-muted-foreground">
                    Resume each conversation's Chaos session and send only new transcript messages after the first turn.
                    This reduces repeated identity and transcript token usage.
                  </p>
                </div>
                <Switch
                  id="persistent_session"
                  checked={$form.agent.persistent_session}
                  disabled={!runtimeManaged}
                  onCheckedChange={(checked) => ($form.agent.persistent_session = checked)} />
              </div>

              <div class="flex items-center justify-between gap-6 rounded border bg-muted/30 p-4">
                <div class="space-y-1">
                  <Label for="persistent_wake_session">Persistent hourly heartbeat session</Label>
                  <p class="text-sm text-muted-foreground">
                    Run hourly heartbeats in one continuing Chaos session instead of starting fresh each time. This
                    preserves heartbeat context and allows provider caching across wakes.
                  </p>
                </div>
                <Switch
                  id="persistent_wake_session"
                  checked={$form.agent.persistent_wake_session}
                  disabled={!runtimeManaged}
                  onCheckedChange={(checked) => ($form.agent.persistent_wake_session = checked)} />
              </div>

              <div class="flex items-center justify-between gap-6 rounded border bg-muted/30 p-4">
                <div class="space-y-1">
                  <Label for="half_hourly_wake">30-minute heartbeats</Label>
                  <p class="text-sm text-muted-foreground">
                    Add a second heartbeat at minute :35, between the normal hourly heartbeats at minute :05.
                  </p>
                </div>
                <Switch
                  id="half_hourly_wake"
                  checked={$form.agent.half_hourly_wake}
                  disabled={!runtimeManaged || !$form.agent.scheduled_wakes_enabled}
                  onCheckedChange={(checked) => ($form.agent.half_hourly_wake = checked)} />
              </div>

              {#if !runtimeManaged}
                <p class="text-xs text-muted-foreground">
                  Persistent sessions become available after this agent is promoted to an external runtime.
                </p>
              {/if}

              {#if agent.sandbox_last_error}
                <div class="rounded border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                  <div class="font-medium">Last promotion error</div>
                  <div class="mt-1 font-mono text-xs whitespace-pre-wrap">{agent.sandbox_last_error}</div>
                  {#if agent.sandbox_last_error_at}
                    <div class="mt-1 text-xs opacity-80">At {agent.sandbox_last_error_at}</div>
                  {/if}
                </div>
              {/if}

              {#if agent.runtime === 'inline'}
                <div class="space-y-3">
                  <p class="text-sm text-muted-foreground">
                    Run this agent in a HelixKit-managed Docker sandbox. HelixKit will create the identity volume, start
                    the runtime, and send requests to the external agent.
                    {#if localDevEndpointMode}
                      In local development, the shim port is published to <span class="font-mono">127.0.0.1</span>
                      automatically so this can be tested on your Mac.
                    {/if}
                  </p>
                  <Button type="button" onclick={beginPromotion} disabled={promoting}>
                    {promoting ? 'Promoting...' : 'Promote to external runtime'}
                  </Button>
                </div>
              {:else if agent.runtime === 'migrating'}
                <div class="flex flex-wrap gap-3">
                  <Button type="button" disabled>Promotion in progress...</Button>
                  <Button type="button" variant="outline" onclick={cancelPromotion}>Cancel</Button>
                </div>
              {:else}
                <div class="space-y-3">
                  <p class="text-sm text-muted-foreground">
                    Identity fields in HelixKit are now read-only backups. The running agent's identity lives in its
                    hosted filesystem below.
                  </p>
                  <div class="rounded border bg-muted/30 p-3 text-sm">
                    <div class="font-medium">First-wake orientation</div>
                    {#if agent.oriented_at}
                      <p class="mt-1 text-muted-foreground">Oriented at {agent.oriented_at}.</p>
                    {:else if orientationResult && orientationResult.status === 'orientation_sent'}
                      <p class="mt-1 text-muted-foreground">
                        Orientation sent. No first journal entry has been detected yet.
                      </p>
                    {:else}
                      <p class="mt-1 text-muted-foreground">
                        Not yet oriented. Send an invitation for the agent to read its files and find its footing.
                      </p>
                    {/if}
                  </div>
                  <div class="flex flex-wrap gap-3">
                    <Button
                      type="button"
                      variant="outline"
                      onclick={sendOrientation}
                      disabled={sendingOrientation || agent.health_state !== 'healthy'}>
                      {sendingOrientation
                        ? 'Orienting...'
                        : agent.oriented_at
                          ? 'Re-send orientation'
                          : 'Send orientation'}
                    </Button>
                    <Button type="button" onclick={sendTestRequest} disabled={sendingTestRequest}>
                      {sendingTestRequest ? 'Sending...' : 'Send test trigger'}
                    </Button>
                    {#if sandboxRecreationUrl}
                      <Button
                        type="button"
                        variant="outline"
                        onclick={recreateSandbox}
                        disabled={recreatingSandbox || !runtimeManaged}>
                        {recreatingSandbox ? 'Queueing...' : 'Refresh runtime image'}
                      </Button>
                    {/if}
                    {#if identityExportUrl}
                      <a href={identityExportUrl}>
                        <Button type="button" variant="outline">Download identity export</Button>
                      </a>
                    {/if}
                    {#if runtimeObservabilityUrl}
                      <a href={runtimeObservabilityUrl}>
                        <Button type="button" variant="outline">Runtime usage</Button>
                      </a>
                    {/if}
                  </div>
                </div>
              {/if}

              {#if orientationResult}
                <div class="rounded border bg-muted p-3 text-sm">
                  <div>Orientation: <span class="font-mono">{orientationResult.status}</span></div>
                  {#if orientationResult.oriented_at}<div>Oriented at: {orientationResult.oriented_at}</div>{/if}
                  {#if orientationResult.oriented === false}
                    <div class="text-muted-foreground">No new or grown daily journal file was detected.</div>
                  {/if}
                  {#if orientationResult.error}<div class="text-destructive">{orientationResult.error}</div>{/if}
                  {#if orientationResult.runtime_stderr}
                    <details class="mt-2">
                      <summary class="cursor-pointer font-medium text-destructive">Runtime stderr</summary>
                      <pre
                        class="mt-1 overflow-x-auto whitespace-pre-wrap text-xs">{orientationResult.runtime_stderr}</pre>
                    </details>
                  {/if}
                  {#if orientationResult.runtime_stdout}
                    <details class="mt-2">
                      <summary class="cursor-pointer font-medium">Runtime stdout</summary>
                      <pre
                        class="mt-1 overflow-x-auto whitespace-pre-wrap text-xs">{orientationResult.runtime_stdout}</pre>
                    </details>
                  {/if}
                </div>
              {/if}

              {#if testResult}
                <div class="rounded border bg-muted p-3 text-sm">
                  <div>Status: <span class="font-mono">{testResult.status}</span></div>
                  {#if testResult.transport_status}<div>Transport: {testResult.transport_status}</div>{/if}
                  {#if testResult.runtime_status}<div>Runtime: {testResult.runtime_status}</div>{/if}
                  {#if testResult.error}<div class="text-destructive">{testResult.error}</div>{/if}
                  {#if testResult.runtime_stderr}
                    <details class="mt-2">
                      <summary class="cursor-pointer font-medium text-destructive">Runtime stderr</summary>
                      <pre class="mt-1 overflow-x-auto whitespace-pre-wrap text-xs">{testResult.runtime_stderr}</pre>
                    </details>
                  {/if}
                  {#if testResult.runtime_stdout}
                    <details class="mt-2">
                      <summary class="cursor-pointer font-medium">Runtime stdout</summary>
                      <pre class="mt-1 overflow-x-auto whitespace-pre-wrap text-xs">{testResult.runtime_stdout}</pre>
                    </details>
                  {/if}
                </div>
              {/if}
            </div>

            <div class="border rounded-lg p-6 space-y-3">
              <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <h2 class="text-xl font-semibold">Docker sandbox diagnostics</h2>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onclick={loadHostingDiagnostics}
                  disabled={diagnosticsLoading}>
                  {diagnosticsLoading ? 'Loading...' : 'Refresh diagnostics'}
                </Button>
              </div>
              {#if diagnosticsError}
                <div class="rounded border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                  {diagnosticsError}
                </div>
              {:else if diagnosticsLoading && !diagnosticsLoaded}
                <p class="text-sm text-muted-foreground">Loading Docker and filesystem diagnostics…</p>
              {/if}
              <div class="grid gap-2 text-sm sm:grid-cols-2">
                <p>
                  Docker daemon:
                  <span class="font-medium"
                    >{sandboxStatus.docker_available === null
                      ? 'checking'
                      : sandboxStatus.docker_available
                        ? 'reachable'
                        : 'not reachable'}</span>
                </p>
                {#if sandboxStatus.docker_version}
                  <p>Docker version: <span class="font-mono">{sandboxStatus.docker_version}</span></p>
                {/if}
                {#if sandboxStatus.configured_helixkit_app_url}
                  <p>
                    Configured callback URL: <span class="font-mono">{sandboxStatus.configured_helixkit_app_url}</span>
                  </p>
                {/if}
                {#if sandboxStatus.container_helixkit_app_url}
                  <p>
                    Container callback URL: <span class="font-mono">{sandboxStatus.container_helixkit_app_url}</span>
                  </p>
                {/if}
                <p>
                  Runtime image present: <span class="font-medium"
                    >{sandboxStatus.image_present === null
                      ? 'checking'
                      : sandboxStatus.image_present
                        ? 'yes'
                        : 'no'}</span>
                </p>
                <p>
                  Container exists: <span class="font-medium"
                    >{sandboxStatus.container_exists === null
                      ? 'checking'
                      : sandboxStatus.container_exists
                        ? 'yes'
                        : 'no'}</span>
                </p>
                {#if sandboxStatus.container_exists}
                  <p>
                    Container image current:
                    <span class="font-medium"
                      >{sandboxStatus.container_image_current === null ||
                      sandboxStatus.container_image_current === undefined
                        ? 'checking'
                        : sandboxStatus.container_image_current
                          ? 'yes'
                          : 'no'}</span>
                  </p>
                  <p>
                    Image stale:
                    <span class={sandboxStatus.image_stale ? 'font-medium text-amber-700' : 'font-medium'}>
                      {sandboxStatus.image_stale === null || sandboxStatus.image_stale === undefined
                        ? 'checking'
                        : sandboxStatus.image_stale
                          ? 'yes'
                          : 'no'}
                    </span>
                  </p>
                {/if}
                {#if sandboxStatus.container_state}
                  <p>Container state: <span class="font-mono">{sandboxStatus.container_state}</span></p>
                {/if}
                {#if sandboxStatus.container_exit_code !== undefined && sandboxStatus.container_exit_code !== null}
                  <p>Exit code: <span class="font-mono">{sandboxStatus.container_exit_code}</span></p>
                {/if}
                <p>
                  Identity volume:
                  <span class="font-medium"
                    >{sandboxStatus.identity_volume_exists === null
                      ? 'checking'
                      : sandboxStatus.identity_volume_exists
                        ? 'present'
                        : 'missing'}</span>
                </p>
                <p>
                  Chaos volume: <span class="font-medium"
                    >{sandboxStatus.chaos_volume_exists === null
                      ? 'checking'
                      : sandboxStatus.chaos_volume_exists
                        ? 'present'
                        : 'missing'}</span>
                </p>
                <p>
                  Repo/workspace volume:
                  <span class="font-medium"
                    >{sandboxStatus.repo_volume_exists === null
                      ? 'checking'
                      : sandboxStatus.repo_volume_exists
                        ? 'present'
                        : 'missing'}</span>
                </p>
              </div>
              {#if sandboxStatus.docker_error}
                <div class="rounded border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                  <div class="font-medium">Docker error</div>
                  <div class="mt-1 font-mono text-xs whitespace-pre-wrap">{sandboxStatus.docker_error}</div>
                </div>
              {/if}
              {#if sandboxStatus.configuration_error}
                <div class="rounded border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                  <div class="font-medium">Hosting configuration error</div>
                  <div class="mt-1 font-mono text-xs whitespace-pre-wrap">{sandboxStatus.configuration_error}</div>
                </div>
              {/if}
              {#if sandboxStatus.container_exists && sandboxStatus.container_image_current === false}
                <div class="rounded border border-amber-300/40 bg-amber-50 p-3 text-sm text-amber-900">
                  This container was created from an older runtime image. Restarting promotion will recreate the
                  container while preserving its identity and Chaos volumes.
                </div>
              {/if}
              {#if sandboxStatus.container_error}
                <div class="rounded border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                  <div class="font-medium">Container error</div>
                  <div class="mt-1 font-mono text-xs whitespace-pre-wrap">{sandboxStatus.container_error}</div>
                </div>
              {/if}
              {#if sandboxStatus.log_tail}
                <details class="rounded border bg-muted p-3 text-sm">
                  <summary class="cursor-pointer font-medium">Container log tail</summary>
                  <pre class="mt-2 overflow-x-auto whitespace-pre-wrap text-xs">{sandboxStatus.log_tail}</pre>
                </details>
              {/if}
            </div>

            {#each filesystemSections as section}
              <div class="border rounded-lg p-6 space-y-3">
                <div>
                  <h2 class="text-xl font-semibold">{section.title}</h2>
                  <p class="text-sm text-muted-foreground">
                    {section.description}
                    <span class="font-mono">({section.dump.root || section.fallbackRoot})</span>
                  </p>
                </div>
                {#if section.dump.error}
                  <div class="rounded border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                    {section.dump.error}
                  </div>
                {:else if diagnosticsLoading && !diagnosticsLoaded}
                  <p class="text-sm text-muted-foreground">Loading filesystem dump…</p>
                {:else if !section.dump.entries || section.dump.entries.length === 0}
                  <p class="text-sm text-muted-foreground">No files found.</p>
                {:else}
                  <div class="space-y-2">
                    {#each section.dump.entries as entry}
                      {#if entryVisible(section, entry)}
                        {#if entry.type === 'directory'}
                          <button
                            type="button"
                            class="block w-full rounded px-2 py-1 text-left font-mono text-xs text-muted-foreground hover:bg-muted"
                            style={`padding-left: ${entry.depth * 1.25 + 0.5}rem`}
                            onclick={() => toggleDirectory(section, entry)}
                            aria-expanded={directoryExpanded(section, entry)}>
                            {directoryExpanded(section, entry) ? '▾' : '▸'} 📁 {entry.name}/
                          </button>
                        {:else}
                          <details
                            class="rounded border bg-muted/40 p-2 text-sm"
                            style={`margin-left: ${entry.depth * 1.25}rem`}
                            ontoggle={(event) => loadFilePreview(section, entry, event)}>
                            <summary class="cursor-pointer font-mono text-xs">
                              📄 {entry.name}
                              {#if entry.size_bytes !== null && entry.size_bytes !== undefined}
                                <span class="text-muted-foreground">({entry.size_bytes} bytes)</span>
                              {/if}
                            </summary>
                            {#if !entry.previewable}
                              <p class="mt-2 text-xs text-muted-foreground">Preview unavailable for this file type.</p>
                            {:else if filePreviews[filePreviewKey(section, entry)]?.loading}
                              <p class="mt-2 text-xs text-muted-foreground">Loading preview…</p>
                            {:else if filePreviews[filePreviewKey(section, entry)]?.error}
                              <p class="mt-2 text-xs text-destructive">
                                {filePreviews[filePreviewKey(section, entry)].error}
                              </p>
                            {:else if filePreviews[filePreviewKey(section, entry)]?.loaded}
                              <pre
                                class="mt-2 max-h-96 overflow-auto whitespace-pre-wrap rounded bg-background p-3 text-xs">{filePreviews[
                                  filePreviewKey(section, entry)
                                ].content}</pre>
                              {#if filePreviews[filePreviewKey(section, entry)].truncated}
                                <p class="mt-1 text-xs text-muted-foreground">Preview truncated.</p>
                              {/if}
                            {:else}
                              <p class="mt-2 text-xs text-muted-foreground">Open to load preview.</p>
                            {/if}
                          </details>
                        {/if}
                      {/if}
                    {/each}
                    {#if section.dump.truncated}
                      <p class="text-xs text-muted-foreground">File listing truncated.</p>
                    {/if}
                  </div>
                {/if}
              </div>
            {/each}

            <div class="border rounded-lg p-6 space-y-3">
              <h2 class="text-xl font-semibold">Recent runtime interactions</h2>
              {#if runtimeInteractions.length === 0}
                <p class="text-sm text-muted-foreground">No external runtime interactions have been recorded yet.</p>
              {:else}
                <div class="space-y-3">
                  {#each runtimeInteractions as interaction}
                    <details class="rounded border bg-muted p-3 text-sm">
                      <summary class="cursor-pointer">
                        <span class="font-medium">{interaction.trigger_kind}</span>
                        <span class="text-muted-foreground">
                          {interaction.created_at}
                          · transport {interaction.transport_status ?? 'n/a'}
                          · runtime {interaction.runtime_status ?? 'n/a'}
                          {#if interaction.duration_ms}
                            · {interaction.duration_ms}ms{/if}
                        </span>
                      </summary>
                      <div class="mt-2 grid gap-1 text-xs">
                        {#if interaction.conversation_id}<div>
                            Conversation: <span class="font-mono">{interaction.conversation_id}</span>
                          </div>{/if}
                        {#if interaction.session_id}<div>
                            Session: <span class="font-mono">{interaction.session_id}</span>
                          </div>{/if}
                        {#if interaction.error_message}<div class="text-destructive">
                            {interaction.error_class}: {interaction.error_message}
                          </div>{/if}
                      </div>
                      {#if interaction.stdout}
                        <details class="mt-2">
                          <summary class="cursor-pointer font-medium">stdout</summary>
                          <pre
                            class="mt-1 max-h-80 overflow-auto whitespace-pre-wrap text-xs">{interaction.stdout}</pre>
                        </details>
                      {/if}
                      {#if interaction.stderr}
                        <details class="mt-2">
                          <summary class="cursor-pointer font-medium text-destructive">stderr</summary>
                          <pre
                            class="mt-1 max-h-80 overflow-auto whitespace-pre-wrap text-xs">{interaction.stderr}</pre>
                        </details>
                      {/if}
                    </details>
                  {/each}
                </div>
              {/if}
            </div>
          </div>
        {/if}

        {#if showFormActions}
          <div class="flex justify-end gap-3">
            <a href={accountAgentsPath(account.id)}>
              <Button type="button" variant="outline">Cancel</Button>
            </a>
            <Button type="submit" disabled={$form.processing}>
              {$form.processing ? 'Saving...' : 'Update Agent'}
            </Button>
          </div>
        {/if}
      </div>
    </div>
  </form>
</div>
