<script>
  import { router } from '@inertiajs/svelte';
  import ChangePasswordForm from '$lib/components/forms/ChangePasswordForm.svelte';
  import { rootPath } from '@/routes';

  function handleCancel() {
    router.visit(rootPath());
  }

  function handleSuccess() {
    router.visit(rootPath());
  }

  let { user } = $props();
</script>

<ChangePasswordForm {user} onCancel={handleCancel} onSuccess={handleSuccess} />
