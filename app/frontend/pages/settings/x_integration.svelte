<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { XLogo, Link, LinkBreak } from 'phosphor-svelte';
  import { submitNativePost } from '$lib/integration-forms';
  import IntegrationPageHeader from '$lib/components/settings/IntegrationPageHeader.svelte';
  import IntegrationSettingsCard from '$lib/components/settings/IntegrationSettingsCard.svelte';
  import IntegrationStatusCard from '$lib/components/settings/IntegrationStatusCard.svelte';

  let { integration } = $props();

  function connect() {
    submitNativePost('/x_integration');
  }

  function disconnect() {
    if (confirm('Disconnect X/Twitter? Agents will no longer be able to post tweets.')) {
      router.delete('/x_integration');
    }
  }

  function toggleEnabled(checked) {
    router.patch('/x_integration', { x_integration: { enabled: checked } });
  }
</script>

<svelte:head>
  <title>X/Twitter Integration</title>
</svelte:head>

<div class="container mx-auto p-8 max-w-4xl">
  <IntegrationPageHeader
    title="X/Twitter Integration"
    description="Connect your X/Twitter account to allow AI agents to post tweets." />

  <IntegrationStatusCard icon={XLogo}>
    {#snippet status()}
      {#if integration.connected}
        <span class="text-green-600">Connected</span>
        {#if integration.x_username}
          as <span class="font-medium">@{integration.x_username}</span>
        {/if}
      {:else}
        <span class="text-muted-foreground">Not connected</span>
      {/if}
    {/snippet}

    {#snippet actions()}
      {#if integration.connected}
        <Button variant="destructive" onclick={disconnect}>
          <LinkBreak size={16} class="mr-2" />
          Disconnect
        </Button>
      {:else}
        <Button onclick={connect}>
          <Link size={16} class="mr-2" />
          Connect with X
        </Button>
      {/if}
    {/snippet}
  </IntegrationStatusCard>

  {#if integration.connected}
    <IntegrationSettingsCard
      enabled={integration.enabled}
      label="Allow agents to post tweets"
      description="When enabled, agents with the Twitter tool can post tweets to your connected X account. Disable this to temporarily prevent all tweet posting without disconnecting."
      onToggle={toggleEnabled} />
  {/if}
</div>
