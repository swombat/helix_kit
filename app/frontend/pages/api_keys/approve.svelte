<script>
  import { router } from '@inertiajs/svelte';
  import { ShieldCheck, X } from 'phosphor-svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import { apiKeyApprovalPath } from '@/routes';

  let { client_name, token, expires_at } = $props();
  let keyName = $state(`${client_name} Key`);

  function approve() {
    router.post(apiKeyApprovalPath(token), { key_name: keyName });
  }

  function deny() {
    router.delete(apiKeyApprovalPath(token));
  }

  const expiresDate = new Date(expires_at);
  const timeRemaining = Math.max(0, Math.floor((expiresDate - new Date()) / 1000 / 60));
</script>

<div class="container mx-auto p-8 max-w-md">
  <div class="border rounded-lg p-6">
    <div class="flex items-center gap-3 mb-4">
      <div class="p-2 bg-blue-100 rounded-full dark:bg-blue-900">
        <ShieldCheck size={24} class="text-blue-600 dark:text-blue-400" />
      </div>
      <div>
        <h1 class="text-xl font-bold">Authorize Application</h1>
        <p class="text-sm text-muted-foreground">Expires in {timeRemaining} minutes</p>
      </div>
    </div>

    <div class="p-4 bg-muted rounded-lg mb-6">
      <p class="text-sm text-muted-foreground mb-1">Application requesting access:</p>
      <p class="font-semibold text-lg">{client_name}</p>
    </div>

    <div class="mb-6">
      <Label for="key-name">Key Name</Label>
      <Input id="key-name" bind:value={keyName} placeholder="Name for this API key" class="mt-1" />
      <p class="text-xs text-muted-foreground mt-1">You can use this name to identify and revoke the key later.</p>
    </div>

    <div class="flex gap-2">
      <Button onclick={approve} class="flex-1">
        <ShieldCheck class="mr-2" size={16} />
        Approve
      </Button>
      <Button variant="outline" onclick={deny} class="flex-1">
        <X class="mr-2" size={16} />
        Deny
      </Button>
    </div>
  </div>
</div>
