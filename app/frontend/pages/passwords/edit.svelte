<script>
  import { Link } from '@inertiajs/svelte';
  import EditPasswordForm from '$lib/components/forms/edit-password-form.svelte';
  import Logo from '$lib/components/misc/helix-kit-logo.svelte';
  import AuthLayout from '../../layouts/auth-layout.svelte';
</script>

<AuthLayout>
  <div class="flex flex-col h-screen w-full items-center justify-center px-4">
    <Link href="/" class="mb-8">
      <Logo class="h-8 w-48" />
    </Link>
    <EditPasswordForm />
  </div>
</AuthLayout>
