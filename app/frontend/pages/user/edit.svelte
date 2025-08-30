<script>
  import UserSettingsForm from '$lib/components/forms/UserSettingsForm.svelte';

  let { user = $bindable(), timezones } = $props();
</script>

<UserSettingsForm {user} {timezones} />
