<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { InputError } from '$lib/components/shadcn/input-error/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import { Link, useForm } from '@inertiajs/svelte';
  import { signupPath, loginPath } from '@/routes';
  import { Info } from 'phosphor-svelte';

  const form = useForm({
    email_address: null,
  });

  function submit(e) {
    e.preventDefault();
    $form.post(signupPath());
  }
</script>

<Card.Root class="mx-auto max-w-sm w-full">
  <Card.Header>
    <Card.Title class="text-2xl">Sign up</Card.Title>
    <Card.Description>Enter your email to create an account. We'll send you a confirmation link.</Card.Description>
  </Card.Header>
  <Card.Content>
    <form onsubmit={submit}>
      <div class="grid gap-4">
        <div class="grid gap-2">
          <Label for="email_address">Email</Label>
          <Input
            id="email_address"
            type="email"
            placeholder="m@example.com"
            required
            bind:value={$form.email_address}
            disabled={$form.processing} />
          <InputError errors={$form.errors.email_address} />
        </div>

        <!-- Subtle account creation notice -->
        <div class="rounded-lg bg-muted/50 p-3 text-xs text-muted-foreground">
          <div class="flex gap-2">
            <Info size={14} class="mt-0.5 flex-shrink-0" />
            <span>We'll create a personal workspace for you to get started.</span>
          </div>
        </div>

        <Button type="submit" class="w-full" disabled={$form.processing}>
          {$form.processing ? 'Creating account...' : 'Create Account'}
        </Button>
      </div>
      <div class="mt-4 text-center text-sm">
        Already have an account?
        <Link href={loginPath()} class="underline">Log in</Link>
      </div>
    </form>
  </Card.Content>
</Card.Root>
