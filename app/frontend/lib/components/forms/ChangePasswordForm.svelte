<script>
  import { userPasswordPath } from '@/routes';
  import Form from './Form.svelte';
  import Input from '$lib/components/shadcn/input/input.svelte';
  import Label from '$lib/components/shadcn/label/label.svelte';

  let { user, onCancel, onSuccess } = $props();

  let passwordData = $state({
    current_password: '',
    password: '',
    password_confirmation: '',
  });
</script>

<Form
  action={userPasswordPath()}
  method="patch"
  data={() => passwordData}
  title="Change Password"
  description="Update your account password"
  submitLabel="Update Password"
  submitLabelProcessing="Updating..."
  narrow
  {onCancel}
  {onSuccess}>
  <div class="grid gap-2">
    <Label for="email">Email</Label>
    <Input id="email" type="email" autocomplete="email" disabled value={user.email_address} />
  </div>

  <div>
    <Label for="current_password">Current Password</Label>
    <Input
      id="current_password"
      type="password"
      placeholder="Enter current password"
      autocomplete="current-password"
      required
      bind:value={passwordData.current_password} />
  </div>

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
    <Label for="password_confirmation">Confirm New Password</Label>
    <Input
      id="password_confirmation"
      type="password"
      placeholder="Repeat new password"
      autocomplete="new-password"
      required
      bind:value={passwordData.password_confirmation} />
  </div>
</Form>
