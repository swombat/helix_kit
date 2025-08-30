<script>
  import Form from './Form.svelte';
  import Input from '$lib/components/shadcn/input/input.svelte';
  import Label from '$lib/components/shadcn/label/label.svelte';
  import { Link } from '@inertiajs/svelte';
  import { signupPath, loginPath } from '@/routes';
  import { Info } from 'phosphor-svelte';

  let { onCancel, onSuccess } = $props();

  let signupData = $state({
    email_address: '',
  });
</script>

<Form
  action={signupPath()}
  method="post"
  data={() => signupData}
  title="Sign up"
  description="Enter your email to create an account. We'll send you a confirmation link."
  submitLabel="Create Account"
  submitLabelProcessing="Creating account..."
  showCancel={false}
  narrow
  {onCancel}
  {onSuccess}>
  <div>
    <Label for="email_address">Email</Label>
    <Input id="email_address" type="email" placeholder="m@example.com" required bind:value={signupData.email_address} />
  </div>

  <!-- Subtle account creation notice -->
  <div class="rounded-lg bg-muted/50 p-3 text-xs text-muted-foreground">
    <div class="flex gap-2">
      <Info size={14} class="mt-0.5 flex-shrink-0" />
      <span>We'll create a personal workspace for you to get started.</span>
    </div>
  </div>

  <div class="text-center text-sm">
    Already have an account?
    <Link href={loginPath()} class="underline">Log in</Link>
  </div>
</Form>
