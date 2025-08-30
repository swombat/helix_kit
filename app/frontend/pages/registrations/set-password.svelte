<script>
  import { page } from '@inertiajs/svelte';
  import { Link } from '@inertiajs/svelte';

  import AuthLayout from '../../layouts/AuthLayout.svelte';

  import Logo from '$lib/components/misc/HelixKitLogo.svelte';

  import * as Card from '$lib/components/shadcn/card/index.js';
  import Alert from '$lib/components/Alert.svelte';
  import SetPasswordForm from '$lib/components/forms/SetPasswordForm.svelte';

  import { CheckCircle } from 'phosphor-svelte';

  let { user = $bindable(), email } = $props();

  console.log('User:', user);

  let processing = $state(false);
  let success = $state($page.props.flash.success);
  let errors = $state($page.props.flash.errors);

  $effect(() => {
    if ($page.props.flash.success) {
      success = $page.props.flash.success;
      setTimeout(() => (success = null), 3000);
    }
    if ($page.props.flash.errors) {
      errors = $page.props.flash.errors;
    }
  });
</script>

<AuthLayout>
  <div class="flex flex-col h-screen w-full items-center justify-center px-4">
    <Link href="/" class="mb-8">
      <Logo class="h-8 w-48" />
    </Link>

    <Card.Root class="mx-auto max-w-sm w-full">
      <Card.Header>
        <div class="flex justify-center mb-4">
          <div class="rounded-full bg-green-100 dark:bg-green-900 p-3">
            <CheckCircle size={24} class="text-green-600 dark:text-green-400" />
          </div>
        </div>
        <Card.Title class="text-2xl text-center">Email Confirmed!</Card.Title>
        <Card.Description class="text-center">Now let's secure your account with a password.</Card.Description>
      </Card.Header>
      <Card.Content>
        {#if success}
          <Alert type="success" title="Success" description={success} />
        {/if}

        {#if errors && errors.length > 0}
          <Alert type="error" title="Error" description={errors} />
        {/if}

        <SetPasswordForm {user} bind:processing />
      </Card.Content>
    </Card.Root>
  </div>
</AuthLayout>
