<script>
  import { onDestroy, onMount } from 'svelte';
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import {
    beginPromoteAccountAgentPath,
    cancelPromoteAccountAgentPath,
    editAccountAgentPath,
    sendTestRequestAccountAgentPath,
  } from '@/routes';

  let {
    account,
    agent,
    local_dev_endpoint_mode: localDevEndpointMode = false,
    sandbox_status: sandboxStatus = {},
    runtime_interactions: runtimeInteractions = [],
  } = $props();

  let promoting = $state(false);
  let sendingTestRequest = $state(false);
  let testResult = $state(null);
  let pollTimer = null;

  let editPath = $derived(editAccountAgentPath(account.id, agent.id));
  let beginPath = $derived(beginPromoteAccountAgentPath(account.id, agent.id));
  let cancelPath = $derived(cancelPromoteAccountAgentPath(account.id, agent.id));
  let testRequestPath = $derived(sendTestRequestAccountAgentPath(account.id, agent.id));
  let shouldPoll = $derived(agent.runtime === 'migrating' || agent.health_state === 'unknown');

  function beginPromotion() {
    promoting = true;
    router.post(
      beginPath,
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
    router.post(cancelPath);
  }

  function sendTestRequest() {
    sendingTestRequest = true;
    testResult = null;

    fetch(testRequestPath, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
      },
    })
      .then((response) => response.json().then((body) => ({ ok: response.ok, body })))
      .then(({ ok, body }) => {
        testResult = ok ? body : { status: 'transport_failed', error: body.error || 'Test request failed' };
      })
      .catch((error) => {
        testResult = { status: 'transport_failed', error: error.message };
      })
      .finally(() => {
        sendingTestRequest = false;
      });
  }

  onMount(() => {
    if (shouldPoll) {
      pollTimer = setInterval(() => {
        router.reload({ only: ['agent'], preserveScroll: true });
      }, 3000);
    }
  });

  onDestroy(() => {
    if (pollTimer) clearInterval(pollTimer);
  });
</script>

<svelte:head>
  <title>Promote {agent.name}</title>
</svelte:head>

<div class="mx-auto max-w-4xl space-y-6 p-8">
  <div class="space-y-2">
    <a class="text-sm text-muted-foreground hover:text-foreground" href={editPath}>Back to agent settings</a>
    <h1 class="text-3xl font-semibold">Promote {agent.name}</h1>
    <p class="text-muted-foreground">
      Move this agent into a HelixKit-hosted sandbox container. HelixKit creates the volume, starts the runtime, checks
      health, and keeps the agent reachable without a GitHub repo, master key, DNS, or SSH deploy step.
    </p>
  </div>

  <section class="space-y-3 rounded-lg border p-5">
    <h2 class="text-lg font-medium">Status</h2>
    <p class="text-sm">Current runtime: <span class="font-medium">{agent.runtime || 'inline'}</span></p>
    {#if agent.container_name}
      <p class="text-sm">Container: <span class="font-mono">{agent.container_name}</span></p>
    {/if}
    {#if agent.container_image}
      <p class="text-sm">Image: <span class="font-mono">{agent.container_image}</span></p>
    {/if}
    {#if agent.sandbox_host}
      <p class="text-sm">Sandbox host: <span class="font-mono">{agent.sandbox_host}</span></p>
    {/if}
    {#if agent.endpoint_url}
      <p class="text-sm">Dev endpoint: <span class="font-mono">{agent.endpoint_url}</span></p>
    {/if}
    <p class="text-sm">Health: <span class="font-medium">{agent.health_state || 'unknown'}</span></p>
    {#if agent.sandbox_last_error}
      <div class="rounded border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
        <div class="font-medium">Last promotion error</div>
        <div class="mt-1 font-mono text-xs whitespace-pre-wrap">{agent.sandbox_last_error}</div>
        {#if agent.sandbox_last_error_at}
          <div class="mt-1 text-xs opacity-80">At {agent.sandbox_last_error_at}</div>
        {/if}
      </div>
    {/if}
  </section>

  <section class="space-y-3 rounded-lg border p-5">
    <h2 class="text-lg font-medium">Docker sandbox diagnostics</h2>
    <div class="grid gap-2 text-sm sm:grid-cols-2">
      <p>
        Docker daemon: <span class="font-medium">{sandboxStatus.docker_available ? 'reachable' : 'not reachable'}</span>
      </p>
      {#if sandboxStatus.docker_version}
        <p>Docker version: <span class="font-mono">{sandboxStatus.docker_version}</span></p>
      {/if}
      {#if sandboxStatus.configured_helixkit_app_url}
        <p>Configured callback URL: <span class="font-mono">{sandboxStatus.configured_helixkit_app_url}</span></p>
      {/if}
      {#if sandboxStatus.container_helixkit_app_url}
        <p>Container callback URL: <span class="font-mono">{sandboxStatus.container_helixkit_app_url}</span></p>
      {/if}
      <p>Runtime image present: <span class="font-medium">{sandboxStatus.image_present ? 'yes' : 'no'}</span></p>
      <p>Container exists: <span class="font-medium">{sandboxStatus.container_exists ? 'yes' : 'no'}</span></p>
      {#if sandboxStatus.container_state}
        <p>Container state: <span class="font-mono">{sandboxStatus.container_state}</span></p>
      {/if}
      {#if sandboxStatus.container_exit_code !== undefined && sandboxStatus.container_exit_code !== null}
        <p>Exit code: <span class="font-mono">{sandboxStatus.container_exit_code}</span></p>
      {/if}
      <p>
        Identity volume: <span class="font-medium">{sandboxStatus.identity_volume_exists ? 'present' : 'missing'}</span>
      </p>
      <p>Chaos volume: <span class="font-medium">{sandboxStatus.chaos_volume_exists ? 'present' : 'missing'}</span></p>
    </div>
    {#if sandboxStatus.docker_error}
      <div class="rounded border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
        <div class="font-medium">Docker error</div>
        <div class="mt-1 font-mono text-xs whitespace-pre-wrap">{sandboxStatus.docker_error}</div>
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
  </section>

  <section class="space-y-4 rounded-lg border p-5">
    <h2 class="text-lg font-medium">Hosted sandbox promotion</h2>
    <p class="text-sm text-muted-foreground">
      HelixKit will generate agent-scoped credentials, create a Docker identity volume, seed the current identity, start <span
        class="font-mono">helix-kit-agents</span
      >, and verify the shim health endpoint.
      {#if localDevEndpointMode}
        In local development, the shim port is published to <span class="font-mono">127.0.0.1</span> automatically so this
        can be tested on your Mac.
      {/if}
    </p>

    {#if agent.runtime === 'inline'}
      <Button onclick={beginPromotion} disabled={promoting}>{promoting ? 'Promoting...' : 'Promote to sandbox'}</Button>
    {:else if agent.runtime === 'migrating'}
      <div class="flex flex-wrap gap-3">
        <Button disabled>Promotion in progress...</Button>
        <Button variant="outline" onclick={cancelPromotion}>Cancel</Button>
      </div>
    {:else}
      <div class="flex flex-wrap gap-3">
        <Button onclick={sendTestRequest} disabled={sendingTestRequest}>
          {sendingTestRequest ? 'Sending...' : 'Send test trigger'}
        </Button>
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
  </section>

  <section class="space-y-3 rounded-lg border p-5">
    <h2 class="text-lg font-medium">Recent runtime interactions</h2>
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
                <pre class="mt-1 max-h-80 overflow-auto whitespace-pre-wrap text-xs">{interaction.stdout}</pre>
              </details>
            {/if}
            {#if interaction.stderr}
              <details class="mt-2">
                <summary class="cursor-pointer font-medium text-destructive">stderr</summary>
                <pre class="mt-1 max-h-80 overflow-auto whitespace-pre-wrap text-xs">{interaction.stderr}</pre>
              </details>
            {/if}
          </details>
        {/each}
      </div>
    {/if}
  </section>
</div>
