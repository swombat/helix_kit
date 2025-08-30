<script>
  import { page, router } from '@inertiajs/svelte';
  import { userPath } from '@/routes';

  // shadcn components
  import Button from '$lib/components/shadcn/button/button.svelte';
  import Card from '$lib/components/shadcn/card/card.svelte';
  import CardContent from '$lib/components/shadcn/card/card-content.svelte';
  import CardDescription from '$lib/components/shadcn/card/card-description.svelte';
  import CardHeader from '$lib/components/shadcn/card/card-header.svelte';
  import CardTitle from '$lib/components/shadcn/card/card-title.svelte';
  import Input from '$lib/components/shadcn/input/input.svelte';
  import Label from '$lib/components/shadcn/label/label.svelte';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import Alert from '$lib/components/alert.svelte';

  let { user = $bindable(), timezones } = $props();

  console.log('Timezones:', timezones);

  let user_form = $state(user);

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

  function handleSubmit(e) {
    e.preventDefault();
    processing = true;

    router.patch(
      userPath(),
      { user: user_form },
      {
        preserveState: false,
        onFinish: () => {
          processing = false;
        },
      }
    );
  }
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

      <form onsubmit={handleSubmit} class="space-y-6">
        <div class="space-y-4">
          <div>
            <Label for="email">Email Address</Label>
            <Input
              type="email"
              id="email"
              value={user_form.email_address}
              disabled
              class="bg-gray-50 dark:bg-gray-900" />
            <p class="text-sm text-gray-500 mt-1">Email cannot be changed</p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label for="first_name">First Name</Label>
              <Input
                type="text"
                id="first_name"
                bind:value={user_form.first_name}
                placeholder="Enter your first name" />
            </div>

            <div>
              <Label for="last_name">Last Name</Label>
              <Input type="text" id="last_name" bind:value={user_form.last_name} placeholder="Enter your last name" />
            </div>
          </div>

          <div>
            <Label for="timezone">Timezone</Label>
            <Select.Root type="single" name="timezone" bind:value={user_form.timezone}>
              <Select.Trigger class="w-full">
                {#if user_form.timezone}
                  {timezones.find((tz) => tz.value === user_form.timezone)?.label || user_form.timezone}
                {:else}
                  <span class="text-muted-foreground">Select your timezone</span>
                {/if}
              </Select.Trigger>
              <Select.Content>
                {#each timezones as tz}
                  <Select.Item value={tz.value}>
                    {tz.label}
                  </Select.Item>
                {/each}
              </Select.Content>
            </Select.Root>
          </div>
        </div>

        <div class="flex justify-end space-x-3">
          <Button type="button" variant="outline" onclick={() => router.visit('/')}>Cancel</Button>
          <Button type="submit" disabled={processing}>
            {processing ? 'Saving...' : 'Save Changes'}
          </Button>
        </div>
      </form>
    </CardContent>
  </Card>
</div>
