<script>
  import { router } from '@inertiajs/svelte';
  import { List } from 'phosphor-svelte';
  import * as DropdownMenu from '$lib/components/shadcn/dropdown-menu/index.js';
  import { buttonVariants } from '$lib/components/shadcn/button/index.js';
  import { cn } from '$lib/utils.js';
  import { searchAccountChatsPath } from '@/routes';

  let { links = [], siteSettings = {}, currentAccount = null } = $props();
</script>

<DropdownMenu.Root>
  <DropdownMenu.Trigger class={cn(buttonVariants({ variant: 'outline', size: 'icon' }), 'md:hidden')}>
    <List size={20} />
    <span class="sr-only">Menu</span>
  </DropdownMenu.Trigger>
  <DropdownMenu.Content align="end">
    {#each links as link}
      {#if link.show}
        <DropdownMenu.Item onclick={() => router.visit(link.href)}>{link.label}</DropdownMenu.Item>
      {/if}
    {/each}
    {#if siteSettings?.allow_agents && currentAccount?.id}
      <DropdownMenu.Item onclick={() => router.visit(`/accounts/${currentAccount.id}/agents`)}>
        Identities
      </DropdownMenu.Item>
      <DropdownMenu.Item onclick={() => router.visit(`/accounts/${currentAccount.id}/whiteboards`)}>
        Whiteboards
      </DropdownMenu.Item>
    {/if}
    {#if siteSettings?.allow_chats && currentAccount?.id}
      <DropdownMenu.Item onclick={() => router.visit(searchAccountChatsPath(currentAccount.id))}>
        Search Messages
      </DropdownMenu.Item>
    {/if}
  </DropdownMenu.Content>
</DropdownMenu.Root>
