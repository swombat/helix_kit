<script>
  import { page } from '@inertiajs/svelte';
  import Form from '$lib/components/forms/Form.svelte';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import { accountPath } from '@/routes';

  const { account } = $page.props;

  let accountName = $state(account.personal ? '' : account.name || '');

  function getFormData() {
    return {
      account: {
        name: accountName,
      },
    };
  }

  function handleCancel() {
    window.location.href = accountPath(account.id);
  }
</script>

<Form
  title="Edit Account"
  description={account.personal ? "Personal accounts don't have custom names" : 'Update your account name'}
  action={accountPath(account.id)}
  method="put"
  data={getFormData}
  submitLabel="Save Changes"
  onCancel={handleCancel}>
  {#if !account.personal}
    <div class="space-y-2">
      <Label for="name">Account Name</Label>
      <Input type="text" id="name" bind:value={accountName} placeholder="Enter account name" required />
      <p class="text-sm text-muted-foreground">This name will be displayed across your account and to team members.</p>
    </div>
  {:else}
    <div class="p-4 bg-muted rounded-lg">
      <p class="text-sm">
        Personal accounts use your name and cannot be renamed. To use a custom account name, convert to a team account
        from the account settings page.
      </p>
    </div>
  {/if}
</Form>
