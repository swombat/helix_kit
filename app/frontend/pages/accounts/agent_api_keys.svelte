<script>
  import { page } from '@inertiajs/svelte';
  import Form from '$lib/components/forms/Form.svelte';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import Button from '$lib/components/shadcn/button/button.svelte';
  import * as Dialog from '$lib/components/shadcn/dialog/index.js';
  import { CheckCircle, Copy, XCircle } from 'phosphor-svelte';
  import {
    accountAgentApiKeysPath,
    accountAgentProviderSubscriptionPath,
    accountPath,
    cancelAccountAgentProviderSubscriptionPath,
  } from '@/routes';

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
          help: 'Also available to agents for ancillary services such as image generation.',
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
        'These providers can use a metered API key entered here, or an agent can be connected to a supported subscription through Chaos.',
      providers: [
        {
          id: 'openai',
          name: 'OpenAI',
          help: 'Use an OpenAI API key here, or connect the agent to a ChatGPT subscription in Chaos.',
        },
        {
          id: 'xai',
          name: 'xAI',
          help: 'Use an xAI API key here, or connect the agent to an eligible xAI subscription in Chaos.',
        },
      ],
    },
    {
      title: 'Subscription API keys',
      description:
        'Enter the special API key issued by the provider for its coding subscription, or an ordinary metered API key.',
      details:
        'Z.ai, Moonshot, and MiniMax coding plans expose a dedicated API endpoint and issue a special key for it. The key is passed to Chaos like any other API key, but usage draws from the subscription allowance when the agent uses the matching subscription provider configuration. An ordinary API key continues to incur metered API charges.',
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
  let subscriptionAgents = $state(subscription_agents);
  let connectOpen = $state(false);
  let connectingAgent = $state(null);
  let ceremony = $state(null);
  let ceremonyError = $state(null);
  let startingConnection = $state(false);
  let secondsRemaining = $state(0);
  let pollTimer = null;

  $effect(() => {
    if (!connectOpen || !ceremony?.expires_at) return;

    const updateCountdown = () => {
      secondsRemaining = Math.max(0, Math.ceil((new Date(ceremony.expires_at).getTime() - Date.now()) / 1000));
    };
    updateCountdown();
    const timer = setInterval(updateCountdown, 1000);
    return () => clearInterval(timer);
  });

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

  function csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || '';
  }

  function subscriptionPath(agent, suffix = '') {
    return suffix === '/cancel'
      ? cancelAccountAgentProviderSubscriptionPath(account.id, agent.id)
      : accountAgentProviderSubscriptionPath(account.id, agent.id);
  }

  async function jsonRequest(url, options = {}) {
    const response = await fetch(url, {
      ...options,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken(),
        ...(options.headers || {}),
      },
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error || 'Provider connection request failed');
    return body;
  }

  function updateSubscriptionAgent(agentId, changes) {
    subscriptionAgents = subscriptionAgents.map((agent) => (agent.id === agentId ? { ...agent, ...changes } : agent));
  }

  async function setAuthMode(agent, authMode) {
    ceremonyError = null;
    try {
      await jsonRequest(subscriptionPath(agent), {
        method: 'PATCH',
        body: JSON.stringify({ provider: agent.provider, auth_mode: authMode }),
      });
      updateSubscriptionAgent(agent.id, { auth_mode: authMode });
    } catch (error) {
      ceremonyError = error.message;
    }
  }

  async function beginConnection(agent) {
    connectingAgent = agent;
    ceremony = null;
    ceremonyError = null;
    connectOpen = true;
    startingConnection = true;
    stopPolling();
    try {
      ceremony = await jsonRequest(subscriptionPath(agent), {
        method: 'POST',
        body: JSON.stringify({ provider: agent.provider }),
      });
      startPolling();
    } catch (error) {
      ceremonyError = error.message;
    } finally {
      startingConnection = false;
    }
  }

  function startPolling() {
    stopPolling();
    pollTimer = setInterval(checkConnectionStatus, 2000);
  }

  function stopPolling() {
    if (pollTimer) clearInterval(pollTimer);
    pollTimer = null;
  }

  async function checkConnectionStatus() {
    if (!connectingAgent) return;
    try {
      const status = await jsonRequest(
        `${subscriptionPath(connectingAgent)}?provider=${encodeURIComponent(connectingAgent.provider)}`
      );
      if (status.status === 'connected') {
        stopPolling();
        ceremony = status;
        updateSubscriptionAgent(connectingAgent.id, {
          auth_mode: 'oauth_account',
          connection: {
            status: 'connected',
            email: status.email || null,
            plan: status.plan || null,
            connected_at: new Date().toISOString(),
          },
        });
      } else if (status.status === 'failed' || status.status === 'expired') {
        stopPolling();
        ceremony = status;
      }
    } catch (error) {
      stopPolling();
      ceremonyError = error.message;
    }
  }

  async function cancelConnection() {
    stopPolling();
    if (connectingAgent && ceremony?.status === 'pending') {
      try {
        await jsonRequest(subscriptionPath(connectingAgent, '/cancel'), {
          method: 'POST',
          body: JSON.stringify({ provider: connectingAgent.provider }),
        });
      } catch {
        // Closing the modal should not be blocked by a best-effort cancellation.
      }
    }
    connectOpen = false;
  }

  async function disconnectSubscription(agent) {
    if (!confirm(`Disconnect ${agent.name} from ${agent.provider_name}?`)) return;
    ceremonyError = null;
    try {
      await jsonRequest(subscriptionPath(agent), {
        method: 'DELETE',
        body: JSON.stringify({ provider: agent.provider }),
      });
      updateSubscriptionAgent(agent.id, { auth_mode: 'api_key', connection: {} });
    } catch (error) {
      ceremonyError = error.message;
    }
  }

  async function copyCode() {
    if (ceremony?.user_code) await navigator.clipboard.writeText(ceremony.user_code);
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
          Connect a personal provider subscription to a specific hosted agent. The sign-in happens inside that agent's
          Chaos container; HelixKit never receives or stores the provider token.
        </p>
      </div>

      {#if subscriptionAgents.length === 0}
        <p class="text-sm text-muted-foreground">
          No agents currently use a provider with supported subscription sign-in.
        </p>
      {:else}
        <div class="space-y-3">
          {#each subscriptionAgents as subscriptionAgent (subscriptionAgent.id)}
            <div class="rounded-md border bg-muted/20 p-4">
              <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div class="space-y-1">
                  <div class="font-medium">{subscriptionAgent.name}</div>
                  <p class="text-sm text-muted-foreground">
                    {subscriptionAgent.provider_name} ·
                    {subscriptionAgent.available ? 'Hosted runtime ready' : `Runtime ${subscriptionAgent.runtime}`}
                  </p>
                  {#if subscriptionAgent.connection?.status === 'connected'}
                    <p class="text-sm">
                      Connected{subscriptionAgent.connection.email ? ` as ${subscriptionAgent.connection.email}` : ''}
                      {subscriptionAgent.connection.plan ? ` · ${subscriptionAgent.connection.plan}` : ''}
                    </p>
                    <p class="text-xs text-muted-foreground">
                      Agent usage draws on this account's personal plan quota.
                    </p>
                  {:else}
                    <p class="text-xs text-muted-foreground">No subscription account connected.</p>
                  {/if}
                </div>

                <div class="flex flex-wrap gap-2">
                  <Button
                    type="button"
                    size="sm"
                    variant={subscriptionAgent.auth_mode === 'api_key' ? 'default' : 'outline'}
                    disabled={!can_manage_ai_credentials}
                    onclick={() => setAuthMode(subscriptionAgent, 'api_key')}>
                    API key
                  </Button>
                  {#if subscriptionAgent.connection?.status === 'connected'}
                    <Button
                      type="button"
                      size="sm"
                      variant={subscriptionAgent.auth_mode === 'oauth_account' ? 'default' : 'outline'}
                      disabled={!can_manage_ai_credentials}
                      onclick={() => setAuthMode(subscriptionAgent, 'oauth_account')}>
                      Subscription account
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="outline"
                      disabled={!can_manage_ai_credentials || !subscriptionAgent.available}
                      onclick={() => beginConnection(subscriptionAgent)}>
                      Reconnect
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      disabled={!can_manage_ai_credentials || !subscriptionAgent.available}
                      onclick={() => disconnectSubscription(subscriptionAgent)}>
                      Disconnect
                    </Button>
                  {:else}
                    <Button
                      type="button"
                      size="sm"
                      disabled={!can_manage_ai_credentials || !subscriptionAgent.available}
                      onclick={() => beginConnection(subscriptionAgent)}>
                      Connect subscription
                    </Button>
                  {/if}
                </div>
              </div>
            </div>
          {/each}
        </div>
      {/if}

      <p class="text-xs text-muted-foreground">
        Anthropic and Gemini consumer subscriptions cannot be connected to third-party agents. Their agents continue to
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
      <p class="text-sm text-muted-foreground">Only account owners and administrators can change agent API keys.</p>
    {/if}
  </div>
</Form>

<Dialog.Root bind:open={connectOpen}>
  <Dialog.Content
    onInteractOutside={(event) => {
      event.preventDefault();
      cancelConnection();
    }}>
    <Dialog.Header>
      <Dialog.Title>Connect {connectingAgent?.provider_name || 'provider'} subscription</Dialog.Title>
      <Dialog.Description>
        This connection belongs only to {connectingAgent?.name || 'this agent'} and is stored in its private Chaos volume.
      </Dialog.Description>
    </Dialog.Header>

    <div class="space-y-4 py-2">
      {#if startingConnection}
        <p class="text-sm text-muted-foreground">Getting a one-time device code…</p>
      {:else if ceremonyError}
        <div class="rounded-md border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
          {ceremonyError}
        </div>
      {:else if ceremony?.status === 'pending'}
        <div class="space-y-3">
          <a
            class="font-medium text-primary underline underline-offset-4"
            href={ceremony.verification_url}
            target="_blank"
            rel="noreferrer">
            Open provider sign-in
          </a>
          <div class="flex items-center gap-2">
            <code class="rounded-md bg-muted px-4 py-2 text-xl font-semibold tracking-widest"
              >{ceremony.user_code}</code>
            <Button type="button" variant="outline" size="icon" aria-label="Copy one-time code" onclick={copyCode}>
              <Copy size={18} />
            </Button>
          </div>
          <p class="text-sm text-muted-foreground">
            {secondsRemaining > 0
              ? `Code expires in ${Math.floor(secondsRemaining / 60)}:${String(secondsRemaining % 60).padStart(2, '0')}.`
              : 'Code expired.'}
          </p>
          <div class="rounded-md border border-amber-400/40 bg-amber-50 p-3 text-sm text-amber-950">
            Device codes are a common phishing target. Never share this code.
          </div>
          <p class="text-sm text-muted-foreground">Waiting for sign-in to finish…</p>
        </div>
      {:else if ceremony?.status === 'connected'}
        <div class="rounded-md border border-emerald-500/30 bg-emerald-500/10 p-4 text-sm">
          Connected successfully{ceremony.email ? ` as ${ceremony.email}` : ''}. Agent usage now draws on this account's
          personal plan quota.
        </div>
      {:else if ceremony?.status === 'expired' || ceremony?.status === 'failed'}
        <div class="space-y-3">
          <p class="text-sm text-destructive">{ceremony.message || 'The provider connection was not completed.'}</p>
          <Button type="button" onclick={() => beginConnection(connectingAgent)}>Get a new code</Button>
        </div>
      {/if}
    </div>

    <Dialog.Footer>
      <Button type="button" variant="outline" onclick={cancelConnection}>
        {ceremony?.status === 'connected' ? 'Done' : 'Cancel'}
      </Button>
    </Dialog.Footer>
  </Dialog.Content>
</Dialog.Root>
