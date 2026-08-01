<script>
  import { page } from '@inertiajs/svelte';
  import Form from '$lib/components/forms/Form.svelte';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import Button from '$lib/components/shadcn/button/button.svelte';
  import { CheckCircle, XCircle } from 'phosphor-svelte';
  import { accountAgentApiKeysPath, accountPath } from '@/routes';
  import AgentProviderSubscriptionPanel from '$lib/components/agents/AgentProviderSubscriptionPanel.svelte';
  import { siteName } from '$lib/branding';

  const {
    account,
    ai_api_keys_configured = {},
    can_manage_ai_credentials = false,
    subscription_agents = [],
  } = $page.props;
  const providerSections = [
    {
      title: 'OpenRouter',
      description:
        'OpenRouter can be used for any model, but usage is billed through its API rather than a model provider subscription. A provider-specific key or subscription connection takes priority when one is configured.',
      providers: [
        {
          id: 'openrouter',
          name: 'OpenRouter API key',
          help: 'Also available to residents for ancillary services such as image generation.',
        },
      ],
    },
    {
      title: 'API-only providers',
      description:
        'Anthropic and Google explicitly block third-party agents from using credentials from their consumer subscriptions.',
      providers: [
        {
          id: 'anthropic',
          name: 'Anthropic',
          help: 'Enter an Anthropic API key. Claude subscription setup is not available.',
        },
        {
          id: 'gemini',
          name: 'Gemini',
          help: 'Enter a Google Gemini API key. Gemini subscription setup is not available.',
        },
      ],
    },
    {
      title: 'API key or subscription',
      description:
        'These providers can use a metered API key entered here, or a resident can be connected to a supported subscription through Chaos.',
      providers: [
        {
          id: 'openai',
          name: 'OpenAI',
          help: 'Use an OpenAI API key here, or connect the resident to a ChatGPT subscription in Chaos.',
        },
        {
          id: 'xai',
          name: 'xAI',
          help: 'Use an xAI API key here, or connect the resident to an eligible xAI subscription in Chaos.',
        },
      ],
    },
    {
      title: 'Subscription API keys',
      description:
        'Enter the special API key issued by the provider for its coding subscription, or an ordinary metered API key.',
      details:
        'Z.ai, Moonshot, and MiniMax coding plans expose a dedicated API endpoint and issue a special key for it. The key is passed to Chaos like any other API key, but usage draws from the subscription allowance when the resident uses the matching subscription provider configuration. An ordinary API key continues to incur metered API charges.',
      providers: [
        {
          id: 'zai',
          name: 'Z.ai (GLM)',
          help: 'Accepts a GLM Coding Plan key or a standard Z.ai API key.',
        },
        {
          id: 'moonshot',
          name: 'Moonshot (Kimi)',
          help: 'Accepts a Kimi coding subscription key or a standard Moonshot API key.',
        },
        {
          id: 'minimax',
          name: 'MiniMax',
          help: 'Accepts a MiniMax coding subscription key or a standard API key.',
        },
      ],
    },
  ];
  const aiProviders = providerSections.flatMap((section) => section.providers);

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
  title="Resident API Keys"
  description={`Configure the AI provider keys used by residents in ${account.name}.`}
  action={accountAgentApiKeysPath(account.id)}
  method="put"
  data={getFormData}
  submitLabel="Save Resident API Keys"
  onCancel={handleCancel}>
  <div class="space-y-4">
    <p class="text-sm text-muted-foreground">
      These encrypted credentials let {$siteName} residents call AI providers. They are separate from External Access keys,
      which let outside agents and tools connect to {$siteName}.
    </p>

    <div class="space-y-6">
      {#each providerSections as section}
        <section class="space-y-3 rounded-lg border p-4">
          <div class="space-y-1">
            <h2 class="font-medium">{section.title}</h2>
            <p class="text-sm text-muted-foreground">{section.description}</p>
          </div>

          {#if section.details}
            <details class="rounded-md bg-muted/50 px-3 py-2 text-sm">
              <summary class="cursor-pointer font-medium">How subscription API keys work</summary>
              <p class="mt-2 text-muted-foreground">{section.details}</p>
            </details>
          {/if}

          <div class="grid gap-4 md:grid-cols-2">
            {#each section.providers as provider}
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
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          onclick={() => toggleApiKeyRemoval(provider.id)}>
                          Remove
                        </Button>
                      {/if}
                    {:else}
                      <span class="flex items-center gap-1 text-xs font-medium text-muted-foreground">
                        <XCircle size={16} weight="fill" />
                        {clearedAiApiKeys.includes(provider.id) ? 'Will be removed' : 'Not set'}
                      </span>
                      {#if can_manage_ai_credentials && clearedAiApiKeys.includes(provider.id)}
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          onclick={() => toggleApiKeyRemoval(provider.id)}>
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
                <p class="text-xs text-muted-foreground">{provider.help}</p>
              </div>
            {/each}
          </div>
        </section>
      {/each}
    </div>

    <section class="space-y-4 rounded-lg border p-4">
      <div class="space-y-1">
        <h2 class="font-medium">Provider subscription accounts</h2>
        <p class="text-sm text-muted-foreground">
          Connect a personal provider subscription to a specific resident. The sign-in happens inside that resident's
          Chaos container; {$siteName} never receives or stores the provider token.
        </p>
      </div>

      {#if subscription_agents.length === 0}
        <p class="text-sm text-muted-foreground">
          No residents currently use a provider with supported subscription sign-in.
        </p>
      {:else}
        <div class="space-y-3">
          {#each subscription_agents as subscriptionAgent (subscriptionAgent.id)}
            <AgentProviderSubscriptionPanel {account} {subscriptionAgent} canManage={can_manage_ai_credentials} />
          {/each}
        </div>
      {/if}

      <p class="text-xs text-muted-foreground">
        Anthropic and Gemini consumer subscriptions cannot be connected to third-party agents. Residents on those providers continue to
        use API keys.
      </p>
    </section>

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
      <p class="text-sm text-muted-foreground">Only account owners and administrators can change resident API keys.</p>
    {/if}
  </div>
</Form>
