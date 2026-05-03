<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Heartbeat, Link, LinkBreak, ArrowsClockwise } from 'phosphor-svelte';
  import { submitNativePost } from '$lib/integration-forms';
  import IntegrationPageHeader from '$lib/components/settings/IntegrationPageHeader.svelte';
  import IntegrationSettingsCard from '$lib/components/settings/IntegrationSettingsCard.svelte';
  import IntegrationStatusCard from '$lib/components/settings/IntegrationStatusCard.svelte';

  let { integration } = $props();

  let syncing = $state(false);

  function connect() {
    submitNativePost('/oura_integration');
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
  <IntegrationPageHeader
    title="Oura Ring Integration"
    description="Connect your Oura Ring to share sleep, readiness, and activity data with AI agents." />

  <IntegrationStatusCard icon={Heartbeat}>
    {#snippet status()}
      {#if integration.connected}
        <span class="text-green-600">Connected</span>
        {#if integration.health_data_synced_at}
          - Last synced {formatSyncTime(integration.health_data_synced_at)}
        {/if}
      {:else}
        <span class="text-muted-foreground">Not connected</span>
      {/if}
    {/snippet}

    {#snippet actions()}
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
    {/snippet}
  </IntegrationStatusCard>

  {#if integration.connected}
    <IntegrationSettingsCard
      enabled={integration.enabled}
      label="Share health data with AI agents"
      description="When enabled, your latest sleep, readiness, and activity data is included in conversations. This helps agents understand your physical state and provide more contextual responses."
      onToggle={toggleEnabled} />
  {/if}
</div>
