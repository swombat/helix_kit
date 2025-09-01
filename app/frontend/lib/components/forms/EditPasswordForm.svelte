<script>
  import Form from './Form.svelte';
  import Input from '$lib/components/shadcn/input/input.svelte';
  import Label from '$lib/components/shadcn/label/label.svelte';
  import { page } from '@inertiajs/svelte';
  import { passwordPath } from '@/routes';

  let { onCancel, onSuccess } = $props();

  let passwordData = $state({
    password: '',
    password_confirmation: '',
  });
</script>

<Form
  action={passwordPath($page.props.token)}
  method="put"
  data={() => passwordData}
  title="Update your password"
  description="Enter a new password for your account"
  submitLabel="Save"
  submitLabelProcessing="Saving..."
  showCancel={false}
  narrow
  {onCancel}
  {onSuccess}>
  <div>
    <Label for="password">New Password</Label>
    <Input
      id="password"
      type="password"
      placeholder="Enter new password"
      autocomplete="new-password"
      required
      bind:value={passwordData.password} />
  </div>

  <div>
    <Label for="password_confirmation">New Password Confirmation</Label>
    <Input
      id="password_confirmation"
      type="password"
      placeholder="Repeat new password"
      autocomplete="new-password"
      required
      bind:value={passwordData.password_confirmation} />
  </div>
</Form>
