<script>
  import Form from './Form.svelte';
  import Input from '$lib/components/shadcn/input/input.svelte';
  import Label from '$lib/components/shadcn/label/label.svelte';
  import { Link } from '@inertiajs/svelte';
  import { passwordsPath, loginPath } from '@/routes';

  let { onCancel, onSuccess } = $props();

  let resetData = $state({
    email_address: '',
  });
</script>

<Form
  action={passwordsPath()}
  method="post"
  data={() => resetData}
  title="Forgot password?"
  description="Enter your email below to receive a password reset link"
  submitLabel="Send password reset link"
  submitLabelProcessing="Sending..."
  showCancel={false}
  narrow
  {onCancel}
  {onSuccess}>
  <div>
    <Label for="email_address">Email</Label>
    <Input id="email_address" type="email" placeholder="m@example.com" required bind:value={resetData.email_address} />
  </div>

  <div class="text-center text-sm">
    Back to
    <Link href={loginPath()} class="underline">Log in</Link>
  </div>
</Form>
