<script>
  import { page } from '@inertiajs/svelte';
  import AccountEditPage from '../app/frontend/pages/accounts/edit.svelte';

  let { account, ai_api_keys_configured = {}, can_manage_ai_credentials = false } = $props();

  page.set({
    props: {
      account,
      ai_api_keys_configured,
      can_manage_ai_credentials,
      flash: {},
    },
    component: 'accounts/edit',
    url: `/accounts/${account.id}/edit`,
    version: 'test',
  });
</script>

<AccountEditPage />
