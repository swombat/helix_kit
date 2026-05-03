<script>
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
</script>

<div class="space-y-6">
  <div>
    <h2 class="text-lg font-semibold">Telegram Notifications</h2>
    <p class="text-sm text-muted-foreground">
      Connect a Telegram bot to send notifications when this agent initiates conversations or replies.
    </p>
  </div>

  <div class="space-y-2">
    <Label for="telegram_bot_username">Bot Username</Label>
    <Input
      id="telegram_bot_username"
      type="text"
      bind:value={$form.agent.telegram_bot_username}
      placeholder="e.g., my_agent_bot" />
    <p class="text-xs text-muted-foreground">
      Create a bot via <a href="https://t.me/botfather" target="_blank" rel="noopener noreferrer" class="underline"
        >@BotFather</a> on Telegram, then paste the username here.
    </p>
  </div>

  <div class="space-y-2">
    <Label for="telegram_bot_token">Bot Token</Label>
    <Input
      id="telegram_bot_token"
      type="password"
      bind:value={$form.agent.telegram_bot_token}
      placeholder="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11" />
    <p class="text-xs text-muted-foreground">
      The API token provided by BotFather. Leave blank to keep the current token. Stored encrypted.
    </p>
  </div>

  {#if agent.telegram_configured}
    <div class="p-3 rounded-lg bg-muted/50 space-y-2">
      <p class="text-sm font-medium">Your Registration Link</p>
      <p class="text-xs text-muted-foreground">
        Use this to connect your own Telegram account for testing. Other users will see their own link in the chat UI.
      </p>
      <code class="text-xs block p-2 bg-background rounded border break-all">
        {telegramDeepLink}
      </code>
    </div>

    <div class="p-3 rounded-lg bg-muted/50 space-y-2">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium">Test Notifications</p>
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
          {sendingTestNotification ? 'Sending...' : 'Send Test Notification'}
        </Button>
      </div>
    </div>

    <div class="p-3 rounded-lg bg-muted/50 space-y-2">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium">Webhook</p>
          <p class="text-xs text-muted-foreground">Re-register the webhook if Telegram isn't receiving updates.</p>
        </div>
        <Button type="button" variant="outline" size="sm" disabled={registeringWebhook} onclick={onregisterWebhook}>
          {registeringWebhook ? 'Registering...' : 'Re-register Webhook'}
        </Button>
      </div>
    </div>
  {/if}
</div>
