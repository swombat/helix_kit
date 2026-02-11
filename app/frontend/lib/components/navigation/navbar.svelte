<script>
  // grab page props from inertia
  import { page, Link, router } from '@inertiajs/svelte';
  import Logo from '$lib/components/misc/HelixKitLogo.svelte';
  import {
    UserCircle,
    List,
    SignOut,
    Password,
    Moon,
    Sun,
    ShieldWarning,
    Buildings,
    Monitor,
    Palette,
    Gear,
    ClockClockwise,
    CaretRight,
    Check,
    Heartbeat,
    GithubLogo,
    Plugs,
  } from 'phosphor-svelte';
  import * as DropdownMenu from '$lib/components/shadcn/dropdown-menu/index.js';
  import { Button, buttonVariants } from '$lib/components/shadcn/button/index.js';
  import { cn } from '$lib/utils.js';
  import {
    rootPath,
    loginPath,
    signupPath,
    logoutPath,
    editUserPath,
    editUserPasswordPath,
    accountPath,
  } from '@/routes';
  import { toggleMode, setMode, resetMode } from 'mode-watcher';
  import { ModeWatcher } from 'mode-watcher';
  import Avatar from '$lib/components/Avatar.svelte';
  import * as logging from '$lib/logging';

  function handleLogout(event) {
    event.preventDefault();
    router.delete(logoutPath());
  }

  const currentUser = $derived($page.props?.user);
  const currentAccount = $derived($page.props?.account);
  const accounts = $derived($page.props?.accounts || []);
  const siteSettings = $derived($page.props?.site_settings);

  const links = $derived([
    { href: '/documentation', label: 'Documentation', show: true },
    {
      href: currentAccount?.id ? `/accounts/${currentAccount.id}/chats` : '#',
      label: 'Chats',
      show: !!currentUser && siteSettings?.allow_chats,
    },
    { href: '#', label: 'About', show: true },
  ]);

  const showAgentsDropdown = $derived(!!currentUser && siteSettings?.allow_agents && currentAccount?.id);

  // Theme management
  const currentTheme = $derived(currentUser?.preferences?.theme || $page.props?.theme_preference || 'system');

  async function updateTheme(theme) {
    // Update UI immediately
    if (theme === 'system') {
      resetMode();
    } else {
      setMode(theme);
    }

    // Save to server for logged-in users using a regular fetch request
    // to avoid Inertia navigation
    if (currentUser) {
      try {
        const response = await fetch('/user', {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
          },
          body: JSON.stringify({
            user: {
              preferences: { theme },
            },
          }),
        });

        if (!response.ok) {
          logging.error('Failed to save theme preference');
        }
      } catch (error) {
        logging.error('Error saving theme preference:', error);
      }
    }

    // currentTheme will update automatically via derived
  }
</script>

<nav>
  <div class="flex items-center justify-between p-4 px-4 md:px-10 border-b gap-2 md:gap-4">
    <div class="flex items-center gap-4 md:gap-8">
      <Link href="/" class="flex items-center gap-2">
        <Logo class="h-8 w-8 md:h-10 md:w-10" />
        <span class="hidden sm:inline">{siteSettings?.site_name || 'HelixKit'}</span>
      </Link>
      <div class="hidden md:flex items-center">
        {#each links as link}
          {#if link.show}
            <Link
              href={link.href}
              class={cn(buttonVariants({ variant: 'ghost' }), 'rounded-full text-muted-foreground')}>{link.label}</Link>
          {/if}
        {/each}
        {#if showAgentsDropdown}
          <DropdownMenu.Root>
            <DropdownMenu.Trigger
              class={cn(buttonVariants({ variant: 'ghost' }), 'rounded-full text-muted-foreground')}>
              Agents
            </DropdownMenu.Trigger>
            <DropdownMenu.Content align="start">
              <DropdownMenu.Item onclick={() => router.visit(`/accounts/${currentAccount.id}/agents`)}>
                Identities
              </DropdownMenu.Item>
              <DropdownMenu.Item onclick={() => router.visit(`/accounts/${currentAccount.id}/whiteboards`)}>
                Whiteboards
              </DropdownMenu.Item>
            </DropdownMenu.Content>
          </DropdownMenu.Root>
        {/if}
      </div>
    </div>

    <div class="flex-grow"></div>

    <!-- Theme toggle for guest users only -->
    {#if !currentUser}
      <DropdownMenu.Root>
        <DropdownMenu.Trigger class={buttonVariants({ variant: 'outline', size: 'icon' })}>
          <Sun class="h-[1.2rem] w-[1.2rem] rotate-0 scale-100 !transition-all dark:-rotate-90 dark:scale-0" />
          <Moon
            class="absolute h-[1.2rem] w-[1.2rem] rotate-90 scale-0 !transition-all dark:rotate-0 dark:scale-100 text-slate-100" />
          <span class="sr-only">Toggle theme</span>
        </DropdownMenu.Trigger>
        <DropdownMenu.Content align="end">
          <DropdownMenu.Item onclick={() => setMode('light')}>Light</DropdownMenu.Item>
          <DropdownMenu.Item onclick={() => setMode('dark')}>Dark</DropdownMenu.Item>
          <DropdownMenu.Item onclick={() => resetMode()}>System</DropdownMenu.Item>
        </DropdownMenu.Content>
      </DropdownMenu.Root>
    {/if}

    {#if currentUser}
      <!-- Mobile hamburger menu -->
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
        </DropdownMenu.Content>
      </DropdownMenu.Root>

      {#if currentUser?.site_admin}
        <DropdownMenu.Root>
          <DropdownMenu.Trigger class={cn(buttonVariants({ variant: 'outline' }), 'rounded-full px-2.5 gap-1')}>
            <ShieldWarning class="text-red-500" />
            <span class="text-xs font-normal text-muted-foreground text-red-500 hidden md:inline"> Site Admin </span>
          </DropdownMenu.Trigger>
          <DropdownMenu.Content align="end">
            <DropdownMenu.Item onclick={() => router.visit('/admin/settings')}>
              <Gear class="mr-2 size-4" />
              <span>Site Settings</span>
            </DropdownMenu.Item>
            <DropdownMenu.Item onclick={() => router.visit('/admin/accounts')}>
              <Buildings class="mr-2 size-4" />
              <span>Manage Accounts</span>
            </DropdownMenu.Item>
            <DropdownMenu.Item onclick={() => router.visit('/admin/audit_logs')}>
              <ClockClockwise class="mr-2 size-4" />
              <span>Audit Logs</span>
            </DropdownMenu.Item>
          </DropdownMenu.Content>
        </DropdownMenu.Root>
      {/if}
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
              </DropdownMenu.SubContent>
            </DropdownMenu.Sub>
            {#if currentAccount?.id}
              <DropdownMenu.Item onclick={() => router.visit(accountPath(currentAccount.id))}>
                <Gear class="mr-2 size-4" />
                <span>Account Settings</span>
              </DropdownMenu.Item>
            {/if}
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
                <DropdownMenu.Item
                  onclick={() => updateTheme('light')}
                  class={currentTheme === 'light' ? 'bg-accent' : ''}>
                  <Sun class="mr-2 size-4" />
                  Light
                </DropdownMenu.Item>
                <DropdownMenu.Item
                  onclick={() => updateTheme('dark')}
                  class={currentTheme === 'dark' ? 'bg-accent' : ''}>
                  <Moon class="mr-2 size-4" />
                  Dark
                </DropdownMenu.Item>
                <DropdownMenu.Item
                  onclick={() => updateTheme('system')}
                  class={currentTheme === 'system' ? 'bg-accent' : ''}>
                  <Monitor class="mr-2 size-4" />
                  System
                </DropdownMenu.Item>
              </DropdownMenu.SubContent>
            </DropdownMenu.Sub>
            <DropdownMenu.Separator />
            <DropdownMenu.Item onclick={handleLogout}>
              <SignOut class="mr-2 size-4" />
              <span>Log out</span>
            </DropdownMenu.Item>
          </DropdownMenu.Group>
        </DropdownMenu.Content>
      </DropdownMenu.Root>
    {:else}
      <!-- Mobile -->
      <DropdownMenu.Root>
        <DropdownMenu.Trigger class={cn(buttonVariants({ variant: 'outline' }), 'rounded-full px-2.5 gap-1')}>
          <UserCircle />
          <span class="text-xs font-normal text-muted-foreground"> Not Logged In </span>
        </DropdownMenu.Trigger>
        <DropdownMenu.Content class="w-56" align="end">
          <DropdownMenu.Group>
            {#if siteSettings?.allow_signups}
              <DropdownMenu.Item class="font-medium" onclick={() => router.visit(signupPath())}
                >Sign up</DropdownMenu.Item>
            {/if}
            <DropdownMenu.Item onclick={() => router.visit(loginPath())}>Log in</DropdownMenu.Item>
          </DropdownMenu.Group>
          <div class="md:hidden">
            <DropdownMenu.Separator />
            <DropdownMenu.Group>
              {#each links as link}
                {#if link.show}
                  <DropdownMenu.Item onclick={() => router.visit(link.href)}>{link.label}</DropdownMenu.Item>
                {/if}
              {/each}
            </DropdownMenu.Group>
          </div>
        </DropdownMenu.Content>
      </DropdownMenu.Root>
    {/if}
  </div>
</nav>
