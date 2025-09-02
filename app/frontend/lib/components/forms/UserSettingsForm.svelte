<script>
  import { userPath } from '@/routes';
  import Form from './Form.svelte';
  import Input from '$lib/components/shadcn/input/input.svelte';
  import Label from '$lib/components/shadcn/label/label.svelte';
  import * as Select from '$lib/components/shadcn/select/index.js';

  let { user, timezones, onCancel, onSuccess } = $props();

  let user_form = $state({ ...user });
</script>

<Form
  action={userPath()}
  method="patch"
  data={() => ({ user: user_form })}
  title="Personal Information"
  submitLabel="Save Changes"
  submitLabelProcessing="Saving..."
  wide={true}
  {onCancel}
  {onSuccess}>
  <div>
    <Label for="email">Email Address</Label>
    <Input type="email" id="email" value={user_form.email_address} disabled class="bg-gray-50 dark:bg-gray-900" />
    <p class="text-sm text-gray-500 mt-1">Email cannot be changed</p>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <div>
      <Label for="first_name">First Name</Label>
      <Input
        type="text"
        id="first_name"
        bind:value={user_form.first_name}
        placeholder="Enter your first name"
        required />
    </div>

    <div>
      <Label for="last_name">Last Name</Label>
      <Input type="text" id="last_name" bind:value={user_form.last_name} placeholder="Enter your last name" required />
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
            <span class="min-w-48">{tz.label.substring(tz.label.indexOf(' ') + 1)}</span>
            {tz.label.split(' ')[0]}
          </Select.Item>
        {/each}
      </Select.Content>
    </Select.Root>
    <p class="text-sm text-gray-500 mt-1">Type to search for your timezone (e.g., "London")</p>
  </div>
</Form>
