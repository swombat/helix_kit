<script>
  import { router } from '@inertiajs/svelte';
  import ApiKeyCreateForm from '$lib/components/api_keys/ApiKeyCreateForm.svelte';
  import ApiKeyHeader from '$lib/components/api_keys/ApiKeyHeader.svelte';
  import ApiKeyList from '$lib/components/api_keys/ApiKeyList.svelte';
  import ApiUsageCard from '$lib/components/api_keys/ApiUsageCard.svelte';
  import { accountApiKeyPath, accountApiKeysPath } from '@/routes';

  let { account, api_keys = [] } = $props();
  let newKeyName = $state('');
  let showForm = $state(false);

  function createKey() {
    if (newKeyName.trim()) {
      router.post(accountApiKeysPath(account.id), { name: newKeyName });
    }
  }

  function deleteKey(id) {
    if (confirm('Revoke this API key? Applications using it will stop working.')) {
      router.delete(accountApiKeyPath(account.id, id));
    }
  }
</script>

<div class="container mx-auto p-8 max-w-4xl">
  <ApiKeyHeader {account} onCreate={() => (showForm = !showForm)} />

  {#if showForm}
    <ApiKeyCreateForm bind:name={newKeyName} onSubmit={createKey} />
  {/if}

  <ApiKeyList apiKeys={api_keys} onDelete={deleteKey} />
  <ApiUsageCard />
</div>
