<script>
  import { updatePasswordUserPath } from '@/routes';
  import Form from './Form.svelte';
  import Input from '$lib/components/shadcn/input/input.svelte';
  import Label from '$lib/components/shadcn/label/label.svelte';

  let { onCancel, onSuccess } = $props();

  let passwordData = $state({
    current_password: '',
    password: '',
    password_confirmation: '',
  });
</script>

<Form
  action={updatePasswordUserPath()}
  method="patch"
  data={() => passwordData}
  title="Change Password"
  description="Update your account password"
  submitLabel="Update Password"
  submitLabelProcessing="Updating..."
  {onCancel}
  {onSuccess}>
  <div>
    <Label for="current_password">Current Password</Label>
    <Input
      id="current_password"
      type="password"
      placeholder="Enter current password"
      required
      bind:value={passwordData.current_password} />
  </div>

  <div>
    <Label for="password">New Password</Label>
    <Input id="password" type="password" placeholder="Enter new password" required bind:value={passwordData.password} />
  </div>

  <div>
    <Label for="password_confirmation">Confirm New Password</Label>
    <Input
      id="password_confirmation"
      type="password"
      placeholder="Repeat new password"
      required
      bind:value={passwordData.password_confirmation} />
  </div>
</Form>
