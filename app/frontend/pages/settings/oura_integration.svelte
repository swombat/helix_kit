<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Switch } from '$lib/components/shadcn/switch/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import { Heartbeat, Link, LinkBreak, ArrowsClockwise } from 'phosphor-svelte';

  let { integration } = $props();

  let syncing = $state(false);

  function connect() {
    // Use native form submission so the browser follows the external redirect to Oura's OAuth page
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/oura_integration';
    const csrf = document.createElement('input');
    csrf.type = 'hidden';
    csrf.name = 'authenticity_token';
    csrf.value = document.querySelector('meta[name="csrf-token"]')?.content || '';
    form.appendChild(csrf);
    document.body.appendChild(form);
    form.submit();
  }

  function disconnect() {
    if (confirm('Disconnect your Oura Ring? Your health data will no longer be shared with agents.')) {
      router.delete('/oura_integration');
    }
  }

  function toggleEnabled(checked) {
    router.patch('/oura_integration', { oura_integration: { enabled: checked } });
  }

  function syncNow() {
    syncing = true;
    router.post(
      '/oura_integration/sync',
      {},
      {
        onFinish: () => {
          syncing = false;
        },
      }
    );
  }

  function formatSyncTime(isoString) {
    if (!isoString) return 'Never';
    const date = new Date(isoString);
    return date.toLocaleString();
  }
</script>

<svelte:head>
  <title>Oura Ring Integration</title>
</svelte:head>

<div class="container mx-auto p-8 max-w-4xl">
  <div class="mb-8">
    <h1 class="text-3xl font-bold mb-2">Oura Ring Integration</h1>
    <p class="text-muted-foreground">
      Connect your Oura Ring to share sleep, readiness, and activity data with AI agents.
    </p>
  </div>

  <div class="border rounded-lg p-6 mb-6">
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center gap-3">
        <div class="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
          <Heartbeat size={24} class="text-primary" />
        </div>
        <div>
          <h2 class="font-semibold">Connection Status</h2>
          <p class="text-sm text-muted-foreground">
            {#if integration.connected}
              <span class="text-green-600">Connected</span>
              {#if integration.health_data_synced_at}
                - Last synced {formatSyncTime(integration.health_data_synced_at)}
              {/if}
            {:else}
              <span class="text-muted-foreground">Not connected</span>
            {/if}
          </p>
        </div>
      </div>

      <div class="flex gap-2">
        {#if integration.connected}
          <Button variant="outline" onclick={syncNow} disabled={syncing}>
            <ArrowsClockwise size={16} class={syncing ? 'mr-2 animate-spin' : 'mr-2'} />
            Sync Now
          </Button>
          <Button variant="destructive" onclick={disconnect}>
            <LinkBreak size={16} class="mr-2" />
            Disconnect
          </Button>
        {:else}
          <Button onclick={connect}>
            <Link size={16} class="mr-2" />
            Connect Oura Ring
          </Button>
        {/if}
      </div>
    </div>
  </div>

  {#if integration.connected}
    <div class="border rounded-lg p-6">
      <h2 class="font-semibold mb-4">Settings</h2>

      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <Switch id="enabled" checked={integration.enabled} onCheckedChange={toggleEnabled} />
          <Label for="enabled">Share health data with AI agents</Label>
        </div>
      </div>

      <p class="text-sm text-muted-foreground mt-4">
        When enabled, your latest sleep, readiness, and activity data is included in conversations. This helps agents
        understand your physical state and provide more contextual responses.
      </p>
    </div>
  {/if}
</div>
