<script>
  import { router } from '@inertiajs/svelte';
  import { ShieldWarning, Buildings, Gear, ClockClockwise, Play } from 'phosphor-svelte';
  import * as DropdownMenu from '$lib/components/shadcn/dropdown-menu/index.js';
  import { buttonVariants } from '$lib/components/shadcn/button/index.js';
  import { cn } from '$lib/utils.js';
</script>

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
    <DropdownMenu.Item onclick={() => router.visit('/admin/jobs')}>
      <Play class="mr-2 size-4" />
      <span>Background Jobs</span>
    </DropdownMenu.Item>
  </DropdownMenu.Content>
</DropdownMenu.Root>
