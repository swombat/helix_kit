<script>
  import { ArrowLeft, CheckCircle, TelegramLogo } from 'phosphor-svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';

  let {
    form,
    agent,
    telegramDeepLink = null,
    telegramSubscriberCount = 0,
    sendingTestNotification = false,
    registeringWebhook = false,
    onsendTestNotification,
    onregisterWebhook,
  } = $props();
  let selectedIntegration = $state(null);

  function openTelegram() {
    selectedIntegration = 'telegram';
  }

  function showIntegrationList() {
    selectedIntegration = null;
  }
</script>

{#if selectedIntegration === 'telegram'}
  <div class="space-y-6">
    <button
      type="button"
      class="inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
      onclick={showIntegrationList}>
      <ArrowLeft size={16} />
      All integrations
    </button>

    <div class="flex items-start gap-4">
      <div class="flex size-12 shrink-0 items-center justify-center rounded-xl bg-sky-500 text-white">
        <TelegramLogo size={26} weight="fill" />
      </div>
      <div>
        <h2 class="text-xl font-semibold">Telegram</h2>
        <p class="text-sm text-muted-foreground">
          Let people connect with {agent.name} through a Telegram bot and receive conversation notifications.
        </p>
      </div>
    </div>

    {#if !agent.telegram_configured}
      <div class="rounded-lg border bg-muted/20 p-5">
        <h3 class="font-semibold">Create a Telegram bot</h3>
        <ol class="mt-4 space-y-4 text-sm">
          <li class="flex gap-3">
            <span
              class="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs font-semibold text-primary-foreground"
              >1</span>
            <div>
              Open
              <a
                href="https://t.me/botfather"
                target="_blank"
                rel="noopener noreferrer"
                class="font-medium text-primary underline underline-offset-4">@BotFather in Telegram</a>
              and start a chat.
            </div>
          </li>
          <li class="flex gap-3">
            <span
              class="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs font-semibold text-primary-foreground"
              >2</span>
            <div>
              Send <code class="rounded bg-muted px-1.5 py-0.5 text-xs">/newbot</code>, then choose the bot's display
              name and a unique username ending in <code class="rounded bg-muted px-1.5 py-0.5 text-xs">bot</code>.
            </div>
          </li>
          <li class="flex gap-3">
            <span
              class="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs font-semibold text-primary-foreground"
              >3</span>
            <div>
              BotFather will reply with an API token. Keep it private: anyone with this token can control the bot.
            </div>
          </li>
          <li class="flex gap-3">
            <span
              class="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs font-semibold text-primary-foreground"
              >4</span>
            <div>Paste the username and token below, then save the Telegram settings.</div>
          </li>
        </ol>
      </div>
    {:else}
      <div class="flex items-center gap-2 rounded-lg border border-emerald-500/30 bg-emerald-500/10 p-3 text-sm">
        <CheckCircle class="text-emerald-600" size={20} weight="fill" />
        Telegram is connected as <span class="font-medium">@{agent.telegram_bot_username}</span>
      </div>
    {/if}

    <div class="space-y-5 rounded-lg border p-5">
      <div class="space-y-2">
        <Label for="telegram_bot_username">Bot username</Label>
        <Input
          id="telegram_bot_username"
          type="text"
          bind:value={$form.agent.telegram_bot_username}
          placeholder="e.g. my_agent_bot"
          required={!agent.telegram_configured} />
        <p class="text-xs text-muted-foreground">Enter the username without the leading @.</p>
      </div>

      <div class="space-y-2">
        <Label for="telegram_bot_token">Bot token</Label>
        <Input
          id="telegram_bot_token"
          type="password"
          bind:value={$form.agent.telegram_bot_token}
          placeholder={agent.telegram_configured
            ? 'Leave blank to keep the current token'
            : 'Paste the token from BotFather'}
          required={!agent.telegram_configured} />
        <p class="text-xs text-muted-foreground">
          {agent.telegram_configured
            ? 'Leave this blank unless you want to replace the current token.'
            : 'The token is encrypted when stored and is never shown again.'}
        </p>
      </div>
    </div>

    {#if agent.telegram_configured}
      <div class="rounded-lg bg-muted/50 p-4 space-y-2">
        <p class="text-sm font-medium">Your registration link</p>
        <p class="text-xs text-muted-foreground">
          Open this link to connect your own Telegram account for testing. Other users see their own link in the chat
          UI.
        </p>
        <code class="block rounded border bg-background p-2 text-xs break-all">
          {telegramDeepLink}
        </code>
      </div>

      <div class="rounded-lg bg-muted/50 p-4">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-sm font-medium">Test notifications</p>
            <p class="text-xs text-muted-foreground">
              {telegramSubscriberCount} subscriber{telegramSubscriberCount === 1 ? '' : 's'} connected
            </p>
          </div>
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={sendingTestNotification || telegramSubscriberCount === 0}
            onclick={onsendTestNotification}>
            {sendingTestNotification ? 'Sending...' : 'Send test notification'}
          </Button>
        </div>
      </div>

      <div class="rounded-lg bg-muted/50 p-4">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-sm font-medium">Webhook</p>
            <p class="text-xs text-muted-foreground">Re-register it if Telegram stops sending updates to HelixKit.</p>
          </div>
          <Button type="button" variant="outline" size="sm" disabled={registeringWebhook} onclick={onregisterWebhook}>
            {registeringWebhook ? 'Registering...' : 'Re-register webhook'}
          </Button>
        </div>
      </div>
    {/if}

    <div class="flex justify-end gap-3">
      <Button type="button" variant="outline" onclick={showIntegrationList}>Cancel</Button>
      <Button type="submit" disabled={$form.processing}>
        {$form.processing ? 'Saving...' : 'Save Telegram settings'}
      </Button>
    </div>
  </div>
{:else}
  <div class="space-y-6">
    <div>
      <h2 class="text-xl font-semibold">Integrations</h2>
      <p class="text-sm text-muted-foreground">Connect {agent.name} to the services you use.</p>
    </div>

    <div class="divide-y rounded-lg border">
      <div class="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-4">
          <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-sky-500 text-white">
            <TelegramLogo size={24} weight="fill" />
          </div>
          <div>
            <div class="flex flex-wrap items-center gap-2">
              <h3 class="font-semibold">Telegram</h3>
              {#if agent.telegram_configured}
                <span
                  class="inline-flex items-center gap-1 rounded-full bg-emerald-500/10 px-2 py-0.5 text-xs font-medium text-emerald-700">
                  <CheckCircle size={13} weight="fill" />
                  Connected
                </span>
              {/if}
            </div>
            <p class="text-sm text-muted-foreground">
              Chat with the agent and receive notifications through a Telegram bot.
            </p>
          </div>
        </div>

        <button
          type="button"
          class={[
            'inline-flex h-9 items-center justify-center rounded-md px-4 py-2 text-sm font-medium transition-colors',
            agent.telegram_configured
              ? 'border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground'
              : 'bg-primary text-primary-foreground shadow hover:bg-primary/90',
          ]}
          onclick={openTelegram}>
          {agent.telegram_configured ? 'Settings' : 'Set up'}
        </button>
      </div>
    </div>
  </div>
{/if}
