<script>
  import { Link } from "@inertiajs/svelte";
	import NewPasswordForm from "$lib/components/new-password-form.svelte";
  import Logo from "$lib/components/logo.svelte";
  import AuthLayout from "../../layouts/auth-layout.svelte";
</script>

<AuthLayout>
  <div class="flex flex-col h-screen w-full items-center justify-center px-4">
    <Link href="/" class="mb-8">
      <Logo class="h-8 w-48" />
    </Link>
    <NewPasswordForm />
  </div>
</AuthLayout>