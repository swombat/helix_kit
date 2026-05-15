<script>
  import { page } from '@inertiajs/svelte';
  import Form from '$lib/components/forms/Form.svelte';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import { RadioGroup, RadioGroupItem } from '$lib/components/shadcn/radio-group/index.js';
  import { accountPath } from '@/routes';

  const { account } = $page.props;

  let accountName = $state(account.personal ? '' : account.name || '');
  let defaultConversationMode = $state(account.default_conversation_mode || 'model');

  function getFormData() {
    const accountData = {
      default_conversation_mode: defaultConversationMode,
    };

    if (!account.personal) accountData.name = accountName;

    return {
      account: accountData,
    };
  }

  function handleCancel() {
    window.location.href = accountPath(account.id);
  }
</script>

<Form
  title="Edit Account"
  description={account.personal ? "Personal accounts don't have custom names" : 'Update your account name'}
  action={accountPath(account.id)}
  method="put"
  data={getFormData}
  submitLabel="Save Changes"
  onCancel={handleCancel}>
  {#if !account.personal}
    <div class="space-y-2">
      <Label for="name">Account Name</Label>
      <Input type="text" id="name" bind:value={accountName} placeholder="Enter account name" required />
      <p class="text-sm text-muted-foreground">This name will be displayed across your account and to team members.</p>
    </div>
  {:else}
    <div class="p-4 bg-muted rounded-lg">
      <p class="text-sm">
        Personal accounts use your name and cannot be renamed. To use a custom account name, convert to a team account
        from the account settings page.
      </p>
    </div>
  {/if}

  <div class="space-y-3">
    <Label>New Conversation Default</Label>
    <RadioGroup bind:value={defaultConversationMode} class="grid gap-3 md:grid-cols-2">
      <label class="flex cursor-pointer items-start gap-3 rounded-md border border-border p-3 hover:bg-muted/50">
        <RadioGroupItem value="model" id="default-conversation-model" />
        <span class="space-y-1">
          <span class="block text-sm font-medium">Model</span>
          <span class="block text-sm text-muted-foreground">Start with one selected model.</span>
        </span>
      </label>

      <label class="flex cursor-pointer items-start gap-3 rounded-md border border-border p-3 hover:bg-muted/50">
        <RadioGroupItem value="agents" id="default-conversation-agents" />
        <span class="space-y-1">
          <span class="block text-sm font-medium">Agents</span>
          <span class="block text-sm text-muted-foreground">Start with every active account agent selected.</span>
        </span>
      </label>
    </RadioGroup>
  </div>
</Form>
