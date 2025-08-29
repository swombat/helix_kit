<script>
  import { page, Link } from '@inertiajs/svelte';
  import * as Card from '$lib/components/ui/card/index.js';
  import Logo from '$lib/components/logo.svelte';
  import AuthLayout from '../../layouts/auth-layout.svelte';
  import { Spinner, CheckCircle, XCircle } from 'phosphor-svelte';
  import { onMount } from 'svelte';
  import { router } from '@inertiajs/svelte';

  let { token } = $props();
  let status = $state('confirming'); // 'confirming', 'success', 'error'
  let message = $state('Confirming your email...');

  onMount(() => {
    // Auto-confirm on mount
    confirmEmail();
  });

  async function confirmEmail() {
    try {
      // The actual confirmation happens via the controller
      // This component just displays the status
      if ($page.props.confirmation_status === 'success') {
        status = 'success';
        message = 'Email confirmed successfully!';
        // Redirect handled by controller
      } else if ($page.props.confirmation_status === 'error') {
        status = 'error';
        message = $page.props.error_message || 'Invalid or expired confirmation link.';
      }
    } catch (error) {
      status = 'error';
      message = 'An error occurred. Please try again.';
    }
  }
</script>

<AuthLayout>
  <div class="flex flex-col h-screen w-full items-center justify-center px-4">
    <Link href="/" class="mb-8">
      <Logo class="h-8 w-48" />
    </Link>

    <Card.Root class="mx-auto max-w-sm w-full">
      <Card.Header class="text-center">
        <div class="flex justify-center mb-4">
          {#if status === 'confirming'}
            <div class="rounded-full bg-blue-100 p-3">
              <Spinner size={32} class="text-blue-600 animate-spin" />
            </div>
          {:else if status === 'success'}
            <div class="rounded-full bg-green-100 p-3">
              <CheckCircle size={32} class="text-green-600" />
            </div>
          {:else}
            <div class="rounded-full bg-red-100 p-3">
              <XCircle size={32} class="text-red-600" />
            </div>
          {/if}
        </div>
        <Card.Title class="text-2xl">
          {#if status === 'confirming'}
            Confirming Email
          {:else if status === 'success'}
            Email Confirmed!
          {:else}
            Confirmation Failed
          {/if}
        </Card.Title>
        <Card.Description class="mt-2">
          {message}
        </Card.Description>
      </Card.Header>
    </Card.Root>
  </div>
</AuthLayout>
