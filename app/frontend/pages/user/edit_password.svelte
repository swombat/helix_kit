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
</script>

<ChangePasswordForm onCancel={handleCancel} onSuccess={handleSuccess} />
