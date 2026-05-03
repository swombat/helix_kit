<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import Alert from '$lib/components/Alert.svelte';
  import InfoCard from '$lib/components/InfoCard.svelte';

  let { account, canBePersonal = false, onConvert } = $props();
</script>

<InfoCard title="Account Type" icon="UserSwitch" class="mt-8">
  <div class="space-y-4">
    <p class="text-muted-foreground">
      {#if account.personal}
        Your account is currently set up as a personal account. You can convert it to a team account to collaborate with
        others.
      {:else}
        Your account is currently set up as a team account.
      {/if}
    </p>

    <div class="flex gap-4">
      {#if account.personal}
        <Button onclick={onConvert} variant="outline">Convert to Team Account</Button>
      {:else if canBePersonal}
        <Button onclick={onConvert} variant="outline">Convert to Personal Account</Button>
      {/if}
    </div>

    {#if !account.personal}
      {#if canBePersonal}
        <Alert type="notice" title="Can convert to personal account">
          Since you're the only member, you can convert this team account back to a personal account.
        </Alert>
      {:else}
        <Alert type="warning" title="Cannot convert to personal account">
          Team accounts with multiple users cannot be converted to personal accounts.
        </Alert>
      {/if}
    {/if}
  </div>
</InfoCard>
