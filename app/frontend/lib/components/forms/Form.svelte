<script>
  import { router, page } from '@inertiajs/svelte';
  import Card from '$lib/components/shadcn/card/card.svelte';
  import CardContent from '$lib/components/shadcn/card/card-content.svelte';
  import CardDescription from '$lib/components/shadcn/card/card-description.svelte';
  import CardHeader from '$lib/components/shadcn/card/card-header.svelte';
  import CardTitle from '$lib/components/shadcn/card/card-title.svelte';
  import Button from '$lib/components/shadcn/button/button.svelte';
  import Alert from '$lib/components/Alert.svelte';

  let {
    // Form configuration
    action,
    method = 'post',
    data = {},

    // Card content
    title,
    description = null,

    // Button configuration
    submitLabel = 'Save',
    submitLabelProcessing = 'Saving...',
    showCancel = true,
    cancelLabel = 'Cancel',

    // Callbacks
    onCancel = null,
    onSuccess = null,
    onError = null,
    onFinish = null,

    // Additional options
    preserveState = false,

    // Content slots
    children,
    narrow = false,
    wide = false,
  } = $props();

  let processing = $state(false);
  let success = $state($page.props.flash?.success);
  let errors = $state($page.props.flash?.errors);

  // Watch for flash messages from the server
  $effect(() => {
    if ($page.props.flash?.success) {
      success = $page.props.flash.success;
      setTimeout(() => (success = null), 3000);
    }
    if ($page.props.flash?.errors) {
      errors = $page.props.flash.errors;
    }
  });

  function handleSubmit(e) {
    e.preventDefault();
    processing = true;

    const routerMethod = ['get', 'patch', 'put', 'delete'].includes(method.toLowerCase())
      ? method.toLowerCase()
      : 'post';

    const submitData = typeof data === 'function' ? data() : data;

    router[routerMethod](action, submitData, {
      preserveState,
      onFinish: () => {
        processing = false;
        if (onFinish) onFinish();
      },
      onSuccess: () => {
        if (onSuccess) onSuccess();
      },
      onError: (errors) => {
        if (onError) onError(errors);
      },
    });
  }

  function handleCancel() {
    if (onCancel) {
      onCancel();
    } else {
      router.visit('/');
    }
  }
</script>

<div class="container mx-auto px-4 py-8 {narrow ? 'max-w-lg' : wide ? 'max-w-4xl' : 'max-w-2xl'}">
  <Card>
    <CardHeader>
      <CardTitle>{title}</CardTitle>
      {#if description}
        <CardDescription>{description}</CardDescription>
      {/if}
    </CardHeader>
    <CardContent class="py-2">
      {#if success}
        <Alert type="success" title="Success" description={success} />
      {/if}

      {#if errors && errors.length > 0}
        <Alert type="error" title="Error" description={errors} />
      {/if}

      <form onsubmit={handleSubmit} class="space-y-6 py-2">
        <div class="space-y-4">
          {@render children()}
        </div>

        <div class="flex justify-end space-x-3">
          {#if showCancel}
            <Button type="button" variant="outline" onclick={handleCancel}>
              {cancelLabel}
            </Button>
          {/if}
          <Button type="submit" disabled={processing}>
            {processing ? submitLabelProcessing : submitLabel}
          </Button>
        </div>
      </form>
    </CardContent>
  </Card>
</div>
