<script>
  import Button from '$lib/components/shadcn/button/button.svelte';
  import * as Dialog from '$lib/components/shadcn/dialog/index.js';
  import { Copy } from 'phosphor-svelte';
  import { accountAgentProviderSubscriptionPath, cancelAccountAgentProviderSubscriptionPath } from '@/routes';

  let { account, subscriptionAgent, canManage = false, showAgentName = true } = $props();

  let agent = $state({ ...subscriptionAgent });
  let connectOpen = $state(false);
  let ceremony = $state(null);
  let actionError = $state(null);
  let startingConnection = $state(false);
  let secondsRemaining = $state(0);
  let pollTimer = null;
  let capabilityChecked = $state(false);
  let subscriptionSupported = $state(true);
  let browserCode = $state('');
  let submittingCode = $state(false);

  $effect(() => {
    if (!connectOpen || !ceremony?.expires_at) return;

    const updateCountdown = () => {
      secondsRemaining = Math.max(0, Math.ceil((new Date(ceremony.expires_at).getTime() - Date.now()) / 1000));
    };
    updateCountdown();
    const timer = setInterval(updateCountdown, 1000);
    return () => clearInterval(timer);
  });

  $effect(() => () => stopPolling());

  $effect(() => {
    if (!agent.available) return;
    checkCapabilities();
  });

  function csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || '';
  }

  function subscriptionPath(cancel = false) {
    return cancel
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

  async function setAuthMode(authMode) {
    actionError = null;
    try {
      await jsonRequest(subscriptionPath(), {
        method: 'PATCH',
        body: JSON.stringify({ provider: agent.provider, auth_mode: authMode }),
      });
      agent = { ...agent, auth_mode: authMode };
    } catch (error) {
      actionError = error.message;
    }
  }

  async function checkCapabilities() {
    try {
      const capabilities = await jsonRequest(`${subscriptionPath()}?capabilities=1`);
      subscriptionSupported = capabilities.providers?.[agent.provider]?.oauth_account === true;
    } catch {
      // A temporarily unreachable runtime is already represented by the
      // hosting-health state. Keep the server-side provider fallback rather
      // than making an existing connection disappear.
    } finally {
      capabilityChecked = true;
    }
  }

  async function beginConnection() {
    ceremony = null;
    browserCode = '';
    actionError = null;
    connectOpen = true;
    startingConnection = true;
    stopPolling();
    try {
      ceremony = await jsonRequest(subscriptionPath(), {
        method: 'POST',
        body: JSON.stringify({ provider: agent.provider }),
      });
      startPolling();
    } catch (error) {
      actionError = error.message;
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
    try {
      const status = await jsonRequest(`${subscriptionPath()}?provider=${encodeURIComponent(agent.provider)}`);
      if (status.status === 'connected') {
        stopPolling();
        ceremony = status;
        agent = {
          ...agent,
          auth_mode: 'oauth_account',
          connection: {
            status: 'connected',
            email: status.email || null,
            plan: status.plan || null,
            connected_at: new Date().toISOString(),
          },
        };
      } else if (status.status === 'failed' || status.status === 'expired') {
        stopPolling();
        ceremony = status;
      }
    } catch (error) {
      stopPolling();
      actionError = error.message;
    }
  }

  async function cancelConnection() {
    stopPolling();
    if (['starting', 'awaiting_code', 'pending', 'finalizing'].includes(ceremony?.status)) {
      try {
        await jsonRequest(subscriptionPath(true), {
          method: 'POST',
          body: JSON.stringify({ provider: agent.provider }),
        });
      } catch {
        // Closing the modal should not be blocked by a best-effort cancellation.
      }
    }
    connectOpen = false;
  }

  async function disconnectSubscription() {
    if (!confirm(`Disconnect ${agent.name} from ${agent.provider_name}?`)) return;

    actionError = null;
    try {
      await jsonRequest(subscriptionPath(), {
        method: 'DELETE',
        body: JSON.stringify({ provider: agent.provider }),
      });
      agent = { ...agent, auth_mode: 'api_key', connection: {} };
    } catch (error) {
      actionError = error.message;
    }
  }

  async function copyCode() {
    if (ceremony?.user_code) await navigator.clipboard.writeText(ceremony.user_code);
  }

  async function submitBrowserCode() {
    actionError = null;
    submittingCode = true;
    try {
      ceremony = await jsonRequest(`${subscriptionPath()}/code`, {
        method: 'POST',
        body: JSON.stringify({ provider: agent.provider, code: browserCode }),
      });
      browserCode = '';
      startPolling();
    } catch (error) {
      actionError = error.message;
    } finally {
      submittingCode = false;
    }
  }
</script>

<div class="rounded-md border bg-muted/20 p-4">
  <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
    <div class="space-y-1">
      {#if showAgentName}
        <div class="font-medium">{agent.name}</div>
      {/if}
      <p class="text-sm text-muted-foreground">
        {agent.provider_name} · {agent.available ? 'Hosted runtime ready' : `Runtime ${agent.runtime}`}
      </p>
      {#if capabilityChecked && !subscriptionSupported}
        <p class="text-xs text-muted-foreground">This hosted runtime does not support subscription account access.</p>
      {/if}
      {#if subscriptionSupported && agent.connection?.status === 'connected'}
        <p class="text-sm">
          Connected{agent.connection.email ? ` as ${agent.connection.email}` : ''}
          {agent.connection.plan ? ` · ${agent.connection.plan}` : ''}
        </p>
        <p class="text-xs text-muted-foreground">Resident usage draws on this account's personal plan quota.</p>
      {:else}
        <p class="text-xs text-muted-foreground">No subscription account connected.</p>
      {/if}
    </div>

    <div class="flex flex-wrap gap-2">
      <Button
        type="button"
        size="sm"
        variant={agent.auth_mode === 'api_key' ? 'default' : 'outline'}
        disabled={!canManage}
        onclick={() => setAuthMode('api_key')}>
        API key
      </Button>
      {#if agent.connection?.status === 'connected'}
        <Button
          type="button"
          size="sm"
          variant={agent.auth_mode === 'oauth_account' ? 'default' : 'outline'}
          disabled={!canManage}
          onclick={() => setAuthMode('oauth_account')}>
          Subscription account
        </Button>
        <Button
          type="button"
          size="sm"
          variant="outline"
          disabled={!canManage || !agent.available}
          onclick={beginConnection}>
          Reconnect
        </Button>
        <Button
          type="button"
          size="sm"
          variant="ghost"
          disabled={!canManage || !agent.available}
          onclick={disconnectSubscription}>
          Disconnect
        </Button>
      {:else if subscriptionSupported}
        <Button type="button" size="sm" disabled={!canManage || !agent.available} onclick={beginConnection}>
          Connect subscription
        </Button>
      {/if}
    </div>
  </div>

  {#if actionError && !connectOpen}
    <div class="mt-3 rounded-md border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
      {actionError}
    </div>
  {/if}
</div>

<Dialog.Root
  open={connectOpen}
  onOpenChange={(open) => {
    if (!open && connectOpen) cancelConnection();
  }}>
  <Dialog.Content
    onInteractOutside={(event) => {
      event.preventDefault();
      cancelConnection();
    }}>
    <Dialog.Header>
      <Dialog.Title>Connect {agent.provider_name} subscription</Dialog.Title>
      <Dialog.Description>
        This connection belongs only to {agent.name} and is stored in its private runtime state volume.
      </Dialog.Description>
    </Dialog.Header>

    <div class="space-y-4 py-2">
      {#if startingConnection}
        <p class="text-sm text-muted-foreground">Getting a one-time device code…</p>
      {:else if actionError}
        <div class="rounded-md border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
          {actionError}
        </div>
      {:else if ceremony?.status === 'awaiting_code'}
        <div class="space-y-3">
          <a
            class="font-medium text-primary underline underline-offset-4"
            href={ceremony.verification_url}
            target="_blank"
            rel="noreferrer">
            Open Claude sign-in
          </a>
          <p class="text-sm text-muted-foreground">
            Complete sign-in in the browser. If the final localhost page does not load, copy its full URL from the
            address bar and paste it below.
          </p>
          <input
            class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
            type="text"
            autocomplete="one-time-code"
            bind:value={browserCode}
            placeholder="Paste the localhost callback URL or code" />
          <Button type="button" disabled={!browserCode.trim() || submittingCode} onclick={submitBrowserCode}>
            {submittingCode ? 'Submitting…' : 'Submit code'}
          </Button>
          <p class="text-sm text-muted-foreground">
            {secondsRemaining > 0
              ? `Sign-in expires in ${Math.floor(secondsRemaining / 60)}:${String(secondsRemaining % 60).padStart(2, '0')}.`
              : 'Sign-in expired.'}
          </p>
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
      {:else if ceremony?.status === 'finalizing' || ceremony?.status === 'starting'}
        <p class="text-sm text-muted-foreground">Finishing provider sign-in…</p>
      {:else if ceremony?.status === 'connected'}
        <div class="rounded-md border border-emerald-500/30 bg-emerald-500/10 p-4 text-sm">
          Connected successfully{ceremony.email ? ` as ${ceremony.email}` : ''}. Resident usage now draws on this
          account's personal plan quota.
        </div>
      {:else if ceremony?.status === 'expired' || ceremony?.status === 'failed'}
        <div class="space-y-3">
          <p class="text-sm text-destructive">{ceremony.message || 'The provider connection was not completed.'}</p>
          <Button type="button" onclick={beginConnection}>Get a new code</Button>
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
