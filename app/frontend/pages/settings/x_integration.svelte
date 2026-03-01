<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Switch } from '$lib/components/shadcn/switch/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import { XLogo, Link, LinkBreak } from 'phosphor-svelte';

  let { integration } = $props();

  function connect() {
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/x_integration';
    const csrf = document.createElement('input');
    csrf.type = 'hidden';
    csrf.name = 'authenticity_token';
    csrf.value = document.querySelector('meta[name="csrf-token"]')?.content || '';
    form.appendChild(csrf);
    document.body.appendChild(form);
    form.submit();
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
  <div class="mb-8">
    <h1 class="text-3xl font-bold mb-2">X/Twitter Integration</h1>
    <p class="text-muted-foreground">Connect your X/Twitter account to allow AI agents to post tweets.</p>
  </div>

  <div class="border rounded-lg p-6 mb-6">
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center gap-3">
        <div class="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
          <XLogo size={24} class="text-primary" />
        </div>
        <div>
          <h2 class="font-semibold">Connection Status</h2>
          <p class="text-sm text-muted-foreground">
            {#if integration.connected}
              <span class="text-green-600">Connected</span>
              {#if integration.x_username}
                as <span class="font-medium">@{integration.x_username}</span>
              {/if}
            {:else}
              <span class="text-muted-foreground">Not connected</span>
            {/if}
          </p>
        </div>
      </div>

      <div class="flex gap-2">
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
      </div>
    </div>
  </div>

  {#if integration.connected}
    <div class="border rounded-lg p-6">
      <h2 class="font-semibold mb-4">Settings</h2>

      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <Switch id="enabled" checked={integration.enabled} onCheckedChange={toggleEnabled} />
          <Label for="enabled">Allow agents to post tweets</Label>
        </div>
      </div>

      <p class="text-sm text-muted-foreground mt-4">
        When enabled, agents with the Twitter tool can post tweets to your connected X account. Disable this to
        temporarily prevent all tweet posting without disconnecting.
      </p>
    </div>
  {/if}
</div>
