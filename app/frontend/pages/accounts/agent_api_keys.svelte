<script>
  import { page } from '@inertiajs/svelte';
  import Form from '$lib/components/forms/Form.svelte';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import Button from '$lib/components/shadcn/button/button.svelte';
  import { CheckCircle, XCircle } from 'phosphor-svelte';
  import { accountAgentApiKeysPath, accountPath } from '@/routes';

  const { account, ai_api_keys_configured = {}, can_manage_ai_credentials = false } = $page.props;
  const aiProviders = [
    { id: 'openrouter', name: 'OpenRouter' },
    { id: 'anthropic', name: 'Anthropic' },
    { id: 'openai', name: 'OpenAI' },
    { id: 'gemini', name: 'Gemini' },
    { id: 'xai', name: 'xAI' },
    { id: 'moonshot', name: 'Moonshot' },
  ];

  let aiApiKeys = $state(Object.fromEntries(aiProviders.map((provider) => [provider.id, ''])));
  let clearedAiApiKeys = $state([]);

  function getFormData() {
    const accountData = {
      clear_ai_api_keys: clearedAiApiKeys,
    };

    for (const provider of aiProviders) {
      const value = aiApiKeys[provider.id]?.trim();
      if (value) accountData[`${provider.id}_api_key`] = value;
    }

    return { account: accountData };
  }

  function handleCancel() {
    window.location.href = accountPath(account.id);
  }

  function toggleApiKeyRemoval(providerId) {
    clearedAiApiKeys = clearedAiApiKeys.includes(providerId)
      ? clearedAiApiKeys.filter((id) => id !== providerId)
      : [...clearedAiApiKeys, providerId];
    aiApiKeys[providerId] = '';
  }
</script>

<Form
  title="Agent API Keys"
  description={`Configure the AI provider keys used by agents in ${account.name}.`}
  action={accountAgentApiKeysPath(account.id)}
  method="put"
  data={getFormData}
  submitLabel="Save Agent API Keys"
  onCancel={handleCancel}>
  <div class="space-y-4">
    <p class="text-sm text-muted-foreground">
      These encrypted credentials let HelixKit agents call AI providers. They are separate from External Access keys,
      which let outside agents and tools connect to HelixKit.
    </p>

    <div class="grid gap-4 md:grid-cols-2">
      {#each aiProviders as provider}
        <div class="space-y-2">
          <div class="flex items-center justify-between gap-2">
            <Label for={`${provider.id}_api_key`}>{provider.name}</Label>
            <div class="flex items-center gap-2">
              {#if ai_api_keys_configured[provider.id] && !clearedAiApiKeys.includes(provider.id)}
                <span class="flex items-center gap-1 text-xs font-medium text-emerald-600 dark:text-emerald-400">
                  <CheckCircle size={16} weight="fill" />
                  Set
                </span>
                {#if can_manage_ai_credentials}
                  <Button type="button" variant="ghost" size="sm" onclick={() => toggleApiKeyRemoval(provider.id)}>
                    Remove
                  </Button>
                {/if}
              {:else}
                <span class="flex items-center gap-1 text-xs font-medium text-muted-foreground">
                  <XCircle size={16} weight="fill" />
                  {clearedAiApiKeys.includes(provider.id) ? 'Will be removed' : 'Not set'}
                </span>
                {#if can_manage_ai_credentials && clearedAiApiKeys.includes(provider.id)}
                  <Button type="button" variant="ghost" size="sm" onclick={() => toggleApiKeyRemoval(provider.id)}>
                    Undo
                  </Button>
                {/if}
              {/if}
            </div>
          </div>
          <Input
            id={`${provider.id}_api_key`}
            type="password"
            autocomplete="off"
            bind:value={aiApiKeys[provider.id]}
            disabled={!can_manage_ai_credentials || clearedAiApiKeys.includes(provider.id)}
            placeholder={ai_api_keys_configured[provider.id] ? 'Enter a replacement key' : 'Enter API key'} />
        </div>
      {/each}
    </div>

    {#if account.use_system_ai_credentials}
      <div class="rounded-md border border-blue-500/30 bg-blue-500/10 p-4">
        <div class="space-y-1">
          <p class="text-sm font-medium">Shared AI keys are available as a fallback</p>
          <p class="text-sm text-muted-foreground">
            A site administrator has enabled shared application keys for providers where this account has no key of its
            own. Only a site administrator can change this setting.
          </p>
        </div>
      </div>
    {/if}

    {#if !can_manage_ai_credentials}
      <p class="text-sm text-muted-foreground">Only account owners and administrators can change agent API keys.</p>
    {/if}
  </div>
</Form>
