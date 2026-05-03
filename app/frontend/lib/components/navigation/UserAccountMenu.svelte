<script>
  import { router } from '@inertiajs/svelte';
  import {
    UserCircle,
    SignOut,
    Password,
    Moon,
    Sun,
    Monitor,
    Palette,
    Gear,
    Check,
    Heartbeat,
    GithubLogo,
    XLogo,
    Plugs,
    Key,
  } from 'phosphor-svelte';
  import * as DropdownMenu from '$lib/components/shadcn/dropdown-menu/index.js';
  import { buttonVariants } from '$lib/components/shadcn/button/index.js';
  import { cn } from '$lib/utils.js';
  import { editUserPath, editUserPasswordPath, accountPath, apiKeysPath } from '@/routes';
  import Avatar from '$lib/components/Avatar.svelte';

  let {
    currentUser,
    currentAccount = null,
    accounts = [],
    currentTheme = 'system',
    onThemeChange = () => {},
    onLogout = () => {},
  } = $props();
</script>

<DropdownMenu.Root>
  <DropdownMenu.Trigger
    class={cn(buttonVariants({ variant: 'outline' }), 'rounded-full pl-0.5 pr-0.5 md:pr-2.5 gap-1 h-9')}>
    <Avatar user={currentUser} size="small" class="!size-8" />
    {#if currentUser?.full_name}
      <span class="text-xs font-normal text-muted-foreground hidden md:inline">
        {currentUser?.full_name}
      </span>
    {:else}
      <span class="text-xs font-normal text-muted-foreground hidden md:inline"> Account </span>
    {/if}
  </DropdownMenu.Trigger>
  <DropdownMenu.Content class="w-56" align="end">
    <DropdownMenu.Group>
      {#if accounts.length > 1}
        <DropdownMenu.Sub>
          <DropdownMenu.SubTrigger>
            <div class="flex flex-col items-start">
              <div class="text-xs font-normal text-muted-foreground">Account</div>
              <div class="text-sm font-semibold truncate">
                {currentAccount?.personal ? 'Personal' : currentAccount?.name}
              </div>
            </div>
          </DropdownMenu.SubTrigger>
          <DropdownMenu.SubContent>
            {#each accounts as account}
              <DropdownMenu.Item
                onclick={() => router.visit(`/accounts/${account.id}/chats`)}
                class={account.id === currentAccount?.id ? 'bg-accent' : ''}>
                <Check class="mr-2 size-4 {account.id === currentAccount?.id ? 'opacity-100' : 'opacity-0'}" />
                <span class="truncate">{account.personal ? 'Personal' : account.name}</span>
              </DropdownMenu.Item>
            {/each}
          </DropdownMenu.SubContent>
        </DropdownMenu.Sub>
      {:else}
        <DropdownMenu.GroupHeading>
          <div class="text-xs font-normal text-muted-foreground">Account</div>
          <div class="text-sm font-semibold truncate">
            {currentAccount?.personal ? 'Personal' : currentAccount?.name}
          </div>
        </DropdownMenu.GroupHeading>
      {/if}
      <DropdownMenu.Separator />
      <DropdownMenu.GroupHeading>
        <div class="text-xs font-normal text-muted-foreground">Logged in as</div>
        <div class="text-sm font-semibold truncate">
          {currentUser.email_address}
        </div>
        <div class="text-sm font-semibold truncate text-red-500">
          {currentUser?.site_admin ? '(Site Admin)' : ''}
        </div>
      </DropdownMenu.GroupHeading>
      <DropdownMenu.Separator />
      <DropdownMenu.Item onclick={() => router.visit(editUserPath())}>
        <UserCircle class="mr-2 size-4" />
        <span>User Settings</span>
      </DropdownMenu.Item>
      <DropdownMenu.Sub>
        <DropdownMenu.SubTrigger>
          <Plugs class="mr-2 size-4" />
          <span>Integrations</span>
        </DropdownMenu.SubTrigger>
        <DropdownMenu.SubContent>
          <DropdownMenu.Item onclick={() => router.visit('/oura_integration')}>
            <Heartbeat class="mr-2 size-4" />
            Oura Ring
          </DropdownMenu.Item>
          <DropdownMenu.Item onclick={() => router.visit('/github_integration')}>
            <GithubLogo class="mr-2 size-4" />
            GitHub
          </DropdownMenu.Item>
          <DropdownMenu.Item onclick={() => router.visit('/x_integration')}>
            <XLogo class="mr-2 size-4" />
            X / Twitter
          </DropdownMenu.Item>
        </DropdownMenu.SubContent>
      </DropdownMenu.Sub>
      {#if currentAccount?.id}
        <DropdownMenu.Item onclick={() => router.visit(accountPath(currentAccount.id))}>
          <Gear class="mr-2 size-4" />
          <span>Account Settings</span>
        </DropdownMenu.Item>
      {/if}
      <DropdownMenu.Item onclick={() => router.visit(apiKeysPath())}>
        <Key class="mr-2 size-4" />
        <span>API Keys</span>
      </DropdownMenu.Item>
      <DropdownMenu.Item onclick={() => router.visit(editUserPasswordPath())}>
        <Password class="mr-2 size-4" />
        <span>Change Password</span>
      </DropdownMenu.Item>
      <DropdownMenu.Sub>
        <DropdownMenu.SubTrigger>
          <Palette class="mr-2 size-4" />
          <span>Theme</span>
        </DropdownMenu.SubTrigger>
        <DropdownMenu.SubContent>
          <DropdownMenu.Item onclick={() => onThemeChange('light')} class={currentTheme === 'light' ? 'bg-accent' : ''}>
            <Sun class="mr-2 size-4" />
            Light
          </DropdownMenu.Item>
          <DropdownMenu.Item onclick={() => onThemeChange('dark')} class={currentTheme === 'dark' ? 'bg-accent' : ''}>
            <Moon class="mr-2 size-4" />
            Dark
          </DropdownMenu.Item>
          <DropdownMenu.Item
            onclick={() => onThemeChange('system')}
            class={currentTheme === 'system' ? 'bg-accent' : ''}>
            <Monitor class="mr-2 size-4" />
            System
          </DropdownMenu.Item>
        </DropdownMenu.SubContent>
      </DropdownMenu.Sub>
      <DropdownMenu.Separator />
      <DropdownMenu.Item onclick={onLogout}>
        <SignOut class="mr-2 size-4" />
        <span>Log out</span>
      </DropdownMenu.Item>
    </DropdownMenu.Group>
  </DropdownMenu.Content>
</DropdownMenu.Root>
