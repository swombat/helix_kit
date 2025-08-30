<script>
  import { Link } from '@inertiajs/svelte';
  import SignupForm from '$lib/components/forms/SignupForm.svelte';
  import Logo from '$lib/components/misc/HelixKitLogo.svelte';
  import AuthLayout from '../../layouts/AuthLayout.svelte';
</script>

<AuthLayout>
  <div class="flex flex-col h-screen w-full items-center justify-center px-4">
    <Link href="/" class="mb-8">
      <Logo class="h-8 w-48" />
    </Link>
    <SignupForm />
  </div>
</AuthLayout>
