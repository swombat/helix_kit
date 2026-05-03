<script>
  import Alert from '$lib/components/Alert.svelte';

  let { flash = {} } = $props();
</script>

{#if flash?.success}
  <Alert type="success" title="Success" description={flash.success} class="mb-6" />
{/if}

{#if flash?.notice}
  <Alert type="notice" title="Notice" description={flash.notice} class="mb-6" />
{/if}

{#if flash?.alert}
  <Alert type="error" title="Alert" description={flash.alert} class="mb-6" />
{/if}
