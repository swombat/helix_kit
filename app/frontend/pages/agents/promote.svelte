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

  let { account, agent, local_dev_endpoint_mode: localDevEndpointMode = false } = $props();

  let promoting = $state(false);
  let sendingTestRequest = $state(false);
  let testResult = $state(null);
  let pollTimer = null;

  let editPath = $derived(editAccountAgentPath(account.id, agent.id));
  let beginPath = $derived(beginPromoteAccountAgentPath(account.id, agent.id));
  let cancelPath = $derived(cancelPromoteAccountAgentPath(account.id, agent.id));
  let testRequestPath = $derived(sendTestRequestAccountAgentPath(account.id, agent.id));
  let shouldPoll = $derived(agent.runtime === 'migrating');

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
        {#if testResult.error}<div class="text-destructive">{testResult.error}</div>{/if}
      </div>
    {/if}
  </section>
</div>
