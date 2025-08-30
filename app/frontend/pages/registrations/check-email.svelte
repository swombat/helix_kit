<script>
  import { Link } from '@inertiajs/svelte';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import Logo from '$lib/components/misc/helix-kit-logo.svelte';
  import AuthLayout from '../../layouts/auth-layout.svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { signupPath } from '@/routes';
  import { EnvelopeSimple } from 'phosphor-svelte';
  import ResendConfirmation from '$lib/components/forms/resend-confirmation.svelte';

  let { email } = $props();
</script>

<AuthLayout>
  <div class="flex flex-col h-screen w-full items-center justify-center px-4">
    <Link href="/" class="mb-8">
      <Logo class="h-8 w-48" />
    </Link>

    <Card.Root class="mx-auto max-w-sm w-full">
      <Card.Header class="text-center">
        <div class="flex justify-center mb-4">
          <div class="rounded-full bg-green-100 p-3">
            <EnvelopeSimple size={32} class="text-green-600" />
          </div>
        </div>
        <Card.Title class="text-2xl">Check Your Email</Card.Title>
        <Card.Description class="mt-2">
          We've sent you a confirmation email{#if email}
            to <strong>{email}</strong>{/if}. Please click the link in the email to confirm your account.
        </Card.Description>
      </Card.Header>
      <Card.Content>
        <div class="space-y-4">
          <div class="rounded-lg bg-muted p-4">
            <p class="text-sm text-muted-foreground">
              <strong>Didn't receive the email?</strong>
            </p>
            <ul class="mt-2 space-y-1 text-sm text-muted-foreground">
              <li>• Check your spam or junk folder</li>
              <li>• Make sure you entered the correct email</li>
              <li>• Wait a few minutes and check again</li>
            </ul>
          </div>

          <div class="space-y-2">
            {#if email}
              <ResendConfirmation {email} />
            {/if}

            <div class="text-center">
              <Link href={signupPath()}>
                <Button variant="outline" class="w-full">Try with a different email</Button>
              </Link>
            </div>
          </div>
        </div>
      </Card.Content>
    </Card.Root>
  </div>
</AuthLayout>
