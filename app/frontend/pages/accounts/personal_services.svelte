<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { DropboxLogo, Heartbeat, ArrowLeft } from 'phosphor-svelte';
  import { submitNativePost } from '$lib/integration-forms';

  let { account, services = [], connections = [] } = $props();
  let selectedProfiles = $state({});

  function profileFor(service) {
    return selectedProfiles[service.key] || service.access_profiles.find((profile) => profile.default)?.key;
  }

  function connect(service) {
    submitNativePost(`/accounts/${account.id}/service_authorizations`, {
      provider: service.key,
      management_scope: 'personal',
      access_profile: profileFor(service),
    });
  }

  function updateConnection(connection, attributes) {
    router.patch(`/accounts/${account.id}/service_connections/${connection.id}`, {
      service_connection: attributes,
    });
  }

  function removeConnection(connection) {
    if (confirm(`Disconnect ${connection.label}?`)) {
      router.delete(`/accounts/${account.id}/service_connections/${connection.id}`);
    }
  }
</script>

<svelte:head><title>Personal Services</title></svelte:head>

<div class="container mx-auto max-w-5xl space-y-8 p-8">
  <a href="/user/edit" class="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground">
    <ArrowLeft size={16} /> User settings
  </a>
  <div>
    <h1 class="text-3xl font-bold">Personal Services</h1>
    <p class="mt-2 text-muted-foreground">
      Connect your own external identities to {account.name}, then choose which residents you trust with each
      credential.
    </p>
  </div>

  <section class="grid gap-4 md:grid-cols-2">
    {#each services as service}
      <div class="space-y-4 rounded-lg border p-5">
        <div class="flex gap-4">
          <div
            class={service.key === 'dropbox'
              ? 'flex size-11 items-center justify-center rounded-xl bg-blue-600 text-white'
              : 'flex size-11 items-center justify-center rounded-xl bg-red-500 text-white'}>
            {#if service.key === 'dropbox'}<DropboxLogo size={24} weight="fill" />{:else}<Heartbeat
                size={24}
                weight="fill" />{/if}
          </div>
          <div>
            <h3 class="font-semibold">{service.name}</h3>
            <p class="text-sm text-muted-foreground">
              {service.key === 'dropbox'
                ? 'Files and folders, with provider-enforced scope choices.'
                : 'Sleep, readiness, activity, and direct Oura API access.'}
            </p>
          </div>
        </div>
        {#if service.access_profiles.length > 1}
          <select
            class="w-full rounded-md border bg-background px-3 py-2 text-sm"
            value={profileFor(service)}
            onchange={(event) =>
              (selectedProfiles = { ...selectedProfiles, [service.key]: event.currentTarget.value })}>
            {#each service.access_profiles as profile}
              <option value={profile.key}>{profile.name}{profile.default ? ' — safest default' : ''}</option>
            {/each}
          </select>
        {/if}
        <Button type="button" onclick={() => connect(service)}>Connect {service.name}</Button>
      </div>
    {/each}
  </section>

  <section class="space-y-4">
    <h2 class="text-xl font-semibold">Your connected identities</h2>
    {#if connections.length === 0}
      <p class="rounded-lg border p-5 text-sm text-muted-foreground">
        No personal identities have been attached to this account yet.
      </p>
    {/if}
    {#each connections as connection}
      <div class="space-y-4 rounded-lg border p-5">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h3 class="font-semibold">{connection.label}</h3>
            <p class="text-sm text-muted-foreground">{connection.provider_name} · {connection.identity}</p>
            <p class="mt-2 text-xs">Granted scopes: {connection.granted_scopes.join(', ')}</p>
          </div>
          <Button type="button" variant="destructive" onclick={() => removeConnection(connection)}>Disconnect</Button>
        </div>
        <label class="flex items-center gap-3 text-sm">
          <input
            type="checkbox"
            checked={connection.enabled_for_new_agents}
            onchange={(event) =>
              updateConnection(connection, { enabled_for_new_agents: event.currentTarget.checked })} />
          Provision to newly created residents by default
        </label>
        <label class="flex items-center gap-3 text-sm">
          <input
            type="checkbox"
            checked={connection.freely_provisionable}
            onchange={(event) => updateConnection(connection, { freely_provisionable: event.currentTarget.checked })} />
          Allow account administrators to provision this identity to residents
        </label>
      </div>
    {/each}
  </section>
</div>
