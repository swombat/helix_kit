<script>
  import Form from '$lib/components/forms/Form.svelte';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import { RadioGroup, RadioGroupItem } from '$lib/components/shadcn/radio-group/index.js';
  import { accountsPath } from '@/routes';

  let accountType = $state('team');
  let accountName = $state('');
  let defaultConversationMode = $state('model');

  function getFormData() {
    return {
      account: {
        name: accountName,
        account_type: accountType,
        default_conversation_mode: defaultConversationMode,
      },
    };
  }

  function handleCancel() {
    window.history.back();
  }
</script>

<Form
  title="New Account"
  description="Create a separate workspace for chats, agents, and settings."
  action={accountsPath()}
  method="post"
  data={getFormData}
  submitLabel="Create Account"
  submitLabelProcessing="Creating..."
  onCancel={handleCancel}>
  <div class="space-y-3">
    <Label>Account Type</Label>
    <RadioGroup bind:value={accountType} class="grid gap-3 md:grid-cols-2">
      <label class="flex cursor-pointer items-start gap-3 rounded-md border border-border p-3 hover:bg-muted/50">
        <RadioGroupItem value="personal" id="account-type-personal" />
        <span class="space-y-1">
          <span class="block text-sm font-medium">Personal</span>
          <span class="block text-sm text-muted-foreground">A single-member account for your own work.</span>
        </span>
      </label>

      <label class="flex cursor-pointer items-start gap-3 rounded-md border border-border p-3 hover:bg-muted/50">
        <RadioGroupItem value="team" id="account-type-team" />
        <span class="space-y-1">
          <span class="block text-sm font-medium">Team</span>
          <span class="block text-sm text-muted-foreground">A shared account where you can invite members.</span>
        </span>
      </label>
    </RadioGroup>
  </div>

  <div class="space-y-2">
    <Label for="name">Account Name</Label>
    <Input type="text" id="name" bind:value={accountName} placeholder="Research Lab" required />
    <p class="text-sm text-muted-foreground">Use a name that will make sense in the account switcher.</p>
  </div>

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
