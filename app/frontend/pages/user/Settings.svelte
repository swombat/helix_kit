<script>
  import { page } from '@inertiajs/svelte';

  // shadcn components
  import Card from '$lib/components/shadcn/card/card.svelte';
  import CardContent from '$lib/components/shadcn/card/card-content.svelte';
  import CardDescription from '$lib/components/shadcn/card/card-description.svelte';
  import CardHeader from '$lib/components/shadcn/card/card-header.svelte';
  import CardTitle from '$lib/components/shadcn/card/card-title.svelte';
  import Alert from '$lib/components/Alert.svelte';
  import UserSettingsForm from '$lib/components/forms/UserSettingsForm.svelte';

  let { user = $bindable(), timezones } = $props();

  console.log('Timezones:', timezones);

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

<div class="container mx-auto px-4 py-8 max-w-2xl">
  <Card>
    <CardHeader>
      <CardTitle>{user.first_name} {user.last_name} Settings</CardTitle>
      <CardDescription>Update your personal information and preferences</CardDescription>
    </CardHeader>
    <CardContent>
      {#if success}
        <Alert type="success" title="Success" description={success} />
      {/if}

      {#if errors && errors.length > 0}
        <Alert type="error" title="Error" description={errors} />
      {/if}

      <UserSettingsForm {user} {timezones} bind:processing />
    </CardContent>
  </Card>
</div>
