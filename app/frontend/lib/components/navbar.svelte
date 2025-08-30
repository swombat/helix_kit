<script>
  // grab page props from inertia
  import { page, Link, router } from '@inertiajs/svelte';
  import Logo from '$lib/components/logo.svelte';
  import { UserCircle, List, SignOut } from 'phosphor-svelte';
  import * as DropdownMenu from '$lib/components/ui/dropdown-menu/index.js';
  import { Button, buttonVariants } from '$lib/components/ui/button/index.js';
  import { cn } from '$lib/utils.js';
  import { rootPath, loginPath, signupPath, logoutPath, editUserPath } from '@/routes';
  import { toggleMode, setMode, resetMode } from 'mode-watcher';
  import { ModeWatcher } from 'mode-watcher';
  import { Moon, Sun } from 'phosphor-svelte';

  function handleLogout(event) {
    event.preventDefault();
    router.delete(logoutPath());
  }

  const links = [{ href: '#', label: 'About' }];

  const currentUser = $derived($page.props?.user);
  const currentAccount = $derived($page.props?.account);
</script>

<nav>
  <div class="flex items-center justify-between p-4 px-10 border-b">
    <div class="flex items-center gap-8">
      <Link href="/" class="flex items-center gap-2">
        <Logo class="h-10 w-10 text-primary" />
        HelixKit
      </Link>
      <div class="hidden md:flex items-center">
        {#each links as link}
          <Link href={link.href} class={cn(buttonVariants({ variant: 'ghost' }), 'rounded-full text-muted-foreground')}
            >{link.label}</Link>
        {/each}
      </div>
    </div>
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

    {#if currentUser}
      <DropdownMenu.Root>
        <DropdownMenu.Trigger class={cn(buttonVariants({ variant: 'outline' }), 'rounded-full px-2.5 gap-1')}>
          <UserCircle />
          {#if currentAccount?.name}
            <span class="text-xs font-normal text-muted-foreground">
              {currentAccount?.name}
            </span>
          {:else}
            <span class="text-xs font-normal text-muted-foreground"> Account </span>
          {/if}
        </DropdownMenu.Trigger>
        <DropdownMenu.Content class="w-56" align="end">
          <DropdownMenu.Group>
            <DropdownMenu.GroupHeading>
              <div class="text-xs font-normal text-muted-foreground">Account</div>
              <div class="text-sm font-semibold truncate">
                {currentAccount?.name || 'Personal'}
              </div>
            </DropdownMenu.GroupHeading>
            <DropdownMenu.Separator />
            <DropdownMenu.GroupHeading>
              <div class="text-xs font-normal text-muted-foreground">Logged in as</div>
              <div class="text-sm font-semibold truncate">
                {currentUser.email_address}
              </div>
            </DropdownMenu.GroupHeading>
            <DropdownMenu.Separator />
            <DropdownMenu.Item onclick={() => router.visit(editUserPath())}>
              <UserCircle class="mr-2 size-4" />
              <span>Settings</span>
            </DropdownMenu.Item>
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
            <DropdownMenu.Item class="font-medium" onclick={() => router.visit(signupPath())}
              >Sign up</DropdownMenu.Item>
            <DropdownMenu.Item onclick={() => router.visit(loginPath())}>Log in</DropdownMenu.Item>
          </DropdownMenu.Group>
          <div class="md:hidden">
            <DropdownMenu.Separator />
            <DropdownMenu.Group>
              {#each links as link}
                <DropdownMenu.Item onclick={() => router.visit(link.href)}>{link.label}</DropdownMenu.Item>
              {/each}
            </DropdownMenu.Group>
          </div>
        </DropdownMenu.Content>
      </DropdownMenu.Root>
    {/if}
  </div>
</nav>
