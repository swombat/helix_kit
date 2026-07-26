<script>
  import { page } from '@inertiajs/svelte';
  import Form from '$lib/components/forms/Form.svelte';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import Button from '$lib/components/shadcn/button/button.svelte';
  import { accountPath } from '@/routes';

  const { account } = $page.props;

  let accountName = $state(account.name || '');

  function getFormData() {
    return {
      account: { name: accountName },
    };
  }

  function handleCancel() {
    window.location.href = accountPath(account.id);
  }
</script>

<Form
  title="Edit Account"
  description="Update your account settings"
  action={accountPath(account.id)}
  method="put"
  data={getFormData}
  submitLabel="Save Changes"
  onCancel={handleCancel}>
  <div class="space-y-2">
    <Label for="name">Account Name</Label>
    <Input type="text" id="name" bind:value={accountName} placeholder="Enter account name" required />
    <p class="text-sm text-muted-foreground">This name is shown in the account switcher and account settings.</p>
  </div>
</Form>
