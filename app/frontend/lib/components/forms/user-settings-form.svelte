<script>
  import { router } from '@inertiajs/svelte';
  import { userPath } from '@/routes';

  import Button from '$lib/components/shadcn/button/button.svelte';
  import Input from '$lib/components/shadcn/input/input.svelte';
  import Label from '$lib/components/shadcn/label/label.svelte';
  import * as Select from '$lib/components/shadcn/select/index.js';

  let { user, timezones, processing = $bindable(false), onCancel, onSuccess } = $props();

  let user_form = $state(user);

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
        onSuccess: () => {
          if (onSuccess) onSuccess();
        },
      }
    );
  }

  function handleCancel() {
    if (onCancel) {
      onCancel();
    } else {
      router.visit('/');
    }
  }
</script>

<form onsubmit={handleSubmit} class="space-y-6">
  <div class="space-y-4">
    <div>
      <Label for="email">Email Address</Label>
      <Input type="email" id="email" value={user_form.email_address} disabled class="bg-gray-50 dark:bg-gray-900" />
      <p class="text-sm text-gray-500 mt-1">Email cannot be changed</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <Label for="first_name">First Name</Label>
        <Input type="text" id="first_name" bind:value={user_form.first_name} placeholder="Enter your first name" />
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
    <Button type="button" variant="outline" onclick={handleCancel}>Cancel</Button>
    <Button type="submit" disabled={processing}>
      {processing ? 'Saving...' : 'Save Changes'}
    </Button>
  </div>
</form>
