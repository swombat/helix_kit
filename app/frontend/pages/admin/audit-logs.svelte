<script>
  import { router } from '@inertiajs/svelte';
  import { createDynamicSync } from '$lib/use-sync';
  import {
    Drawer,
    DrawerContent,
    DrawerHeader,
    DrawerTitle,
    DrawerClose,
  } from '$lib/components/shadcn/drawer/index.js';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '$lib/components/shadcn/table/index.js';
  import PaginationNav from '$lib/components/navigation/PaginationNav.svelte';
  import InfoCard from '$lib/components/InfoCard.svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Badge } from '$lib/components/shadcn/badge/index.js';
  import { formatDistanceToNow } from 'date-fns';
  import { Calendar as CalendarIcon } from 'phosphor-svelte';
  import { DateFormatter, getLocalTimeZone, parseDate, CalendarDate } from '@internationalized/date';
  import { Calendar } from '$lib/components/shadcn/calendar/index.js';
  import * as Popover from '$lib/components/shadcn/popover/index.js';
  import Highlight from 'svelte-highlight';
  import json from 'svelte-highlight/languages/json';
  import 'svelte-highlight/styles/atom-one-dark.css';
  import Avatar from '$lib/components/Avatar.svelte';

  let { audit_logs = [], selected_log = null, pagination = {}, filters = {}, current_filters = {} } = $props();

  let drawerOpen = $state(!!selected_log);

  // Create a reactive page state that syncs with pagination
  let currentPage = $state(pagination.page || 1);

  // Initialize filter arrays from current_filters
  let userFilter = $state(typeof current_filters.user_id === 'string' ? current_filters.user_id.split(',') : undefined);
  let accountFilter = $state(
    typeof current_filters.filter_account_id === 'string' ? current_filters.filter_account_id.split(',') : undefined
  );
  let actionFilter = $state(
    typeof current_filters.audit_action === 'string' ? current_filters.audit_action.split(',') : undefined
  );
  let typeFilter = $state(
    typeof current_filters.auditable_type === 'string' ? current_filters.auditable_type.split(',') : undefined
  );

  console.log('pagination', pagination, !pagination.prev);

  // Date picker setup
  const df = new DateFormatter('en-US', { dateStyle: 'medium' });
  let dateFrom = $state(current_filters.date_from ? parseDate(current_filters.date_from) : undefined);
  let dateTo = $state(current_filters.date_to ? parseDate(current_filters.date_to) : undefined);

  // Derived values for display
  let dateFromDisplay = $derived(
    dateFrom && dateFrom.toDate ? df.format(dateFrom.toDate(getLocalTimeZone())) : 'From date'
  );
  let dateToDisplay = $derived(dateTo && dateTo.toDate ? df.format(dateTo.toDate(getLocalTimeZone())) : 'To date');

  // No longer needed - we'll pass dates directly in applyFilters

  // Set up real-time synchronization
  const updateSync = createDynamicSync();

  $effect(() => {
    const subs = {
      'AuditLog:all': 'audit_logs', // Reload list when any audit log is added
    };

    // If we have a selected log, sync it too
    if (selected_log) {
      subs[`AuditLog:${selected_log.id}`] = 'selected_log';
    }

    updateSync(subs);
  });

  // Update drawer when selection changes
  $effect(() => {
    drawerOpen = !!selected_log;
  });

  function updateUrl(params) {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value) searchParams.set(key, value);
    });

    router.visit(`/admin/audit_logs?${searchParams}`, {
      preserveState: false,
      preserveScroll: false,
    });
  }

  function applyFilters() {
    const params = {
      user_id: userFilter ? userFilter.join(',') : undefined,
      filter_account_id: accountFilter ? accountFilter.join(',') : undefined,
      audit_action: actionFilter ? actionFilter.join(',') : undefined,
      auditable_type: typeFilter ? typeFilter.join(',') : undefined,
      date_from: dateFrom ? dateFrom.toString() : undefined,
      date_to: dateTo ? dateTo.toString() : undefined,
      page: 1,
    };
    updateUrl(params);
  }

  function clearFilters() {
    userFilter = undefined;
    accountFilter = undefined;
    actionFilter = undefined;
    typeFilter = undefined;
    dateFrom = undefined;
    dateTo = undefined;
    updateUrl({ page: 1 });
  }

  function selectLog(logId) {
    updateUrl({ ...current_filters, log_id: logId });
  }

  function closeDrawer() {
    const params = { ...current_filters };
    delete params.log_id;
    updateUrl(params);
  }

  function goToPage(page) {
    router.visit(`/admin/audit_logs?${new URLSearchParams({ ...current_filters, page })}`, {
      preserveState: false,
      preserveScroll: true, // Preserve scroll position
    });
  }

  function formatTime(dateString) {
    return formatDistanceToNow(new Date(dateString), { addSuffix: true });
  }
</script>

<div class="container mx-auto px-4 py-6">
  <h1 class="text-2xl font-bold mb-6">Audit Logs</h1>

  <!-- Filters -->
  <div class="rounded-lg p-4 mb-6">
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-6 gap-4">
      <Select.Root
        type="multiple"
        value={userFilter}
        onValueChange={(v) => {
          console.log('User filter changed to:', v);
          userFilter = v;
        }}>
        <Select.Trigger class="w-full">
          <span class="truncate text-clip">
            {#if userFilter && userFilter.length > 0}
              {#each userFilter as id}
                <span class="text-xs mx-1 border-1 px-1 py-0.5 rounded-md bg-accent">
                  {filters.users?.find((u) => u.id.toString() === id)?.full_name ||
                    filters.users?.find((u) => u.id.toString() === id)?.email_address}
                </span>
              {/each}
            {:else}
              All Users
            {/if}
          </span>
        </Select.Trigger>
        <Select.Content>
          {#each filters.users || [] as user}
            <Select.Item value={user.id.toString()}>{user.full_name} &lt;{user.email_address}&gt;</Select.Item>
          {/each}
        </Select.Content>
      </Select.Root>

      <Select.Root
        type="multiple"
        value={accountFilter}
        onValueChange={(v) => {
          console.log('Account filter changed to:', v);
          accountFilter = v;
        }}>
        <Select.Trigger class="w-full">
          <span class="truncate text-clip">
            {#if accountFilter && accountFilter.length > 0}
              {#each accountFilter as id}
                <span class="text-xs mx-1 border-1 px-1 py-0.5 rounded-md bg-accent">
                  {filters.accounts?.find((u) => u.id.toString() === id)?.name}
                </span>
              {/each}
            {:else}
              All Accounts
            {/if}
          </span>
        </Select.Trigger>
        <Select.Content>
          {#each filters.accounts || [] as account}
            <Select.Item value={account.id.toString()}>{account.name}</Select.Item>
          {/each}
        </Select.Content>
      </Select.Root>

      <Select.Root
        type="multiple"
        value={actionFilter}
        onValueChange={(v) => {
          console.log('Action changed to:', v);
          actionFilter = v;
        }}>
        <Select.Trigger class="w-full">
          <span class="truncate text-clip">
            {#if actionFilter && actionFilter.length > 0}
              {#each actionFilter as id}
                <span class="text-xs mx-1 border-1 px-1 py-0.5 rounded-md bg-accent">
                  {filters.actions?.find((u) => u.toString() === id)}
                </span>
              {/each}
            {:else}
              All Actions
            {/if}
          </span>
        </Select.Trigger>
        <Select.Content>
          {#each filters.actions || [] as action}
            <Select.Item value={action}>{action}</Select.Item>
          {/each}
        </Select.Content>
      </Select.Root>

      <Select.Root
        type="multiple"
        value={typeFilter}
        onValueChange={(v) => {
          console.log('Type filter changed to:', v);
          typeFilter = v;
        }}>
        <Select.Trigger class="w-full">
          <span class="truncate text-clip">
            {#if typeFilter && typeFilter.length > 0}
              {#each typeFilter as id}
                <span class="text-xs mx-1 border-1 px-1 py-0.5 rounded-md bg-accent">
                  {filters.types?.find((u) => u.toString() === id)}
                </span>
              {/each}
            {:else}
              All Types
            {/if}
          </span>
        </Select.Trigger>
        <Select.Content>
          {#each filters.types || [] as type}
            <Select.Item value={type}>{type}</Select.Item>
          {/each}
        </Select.Content>
      </Select.Root>

      <Popover.Root>
        <Popover.Trigger class="w-full">
          <Button variant="outline" class="w-full justify-start text-left font-normal">
            <CalendarIcon class="mr-2 h-4 w-4" />
            {dateFromDisplay}
          </Button>
        </Popover.Trigger>
        <Popover.Content class="w-auto p-0">
          <Calendar type="single" bind:value={dateFrom} />
        </Popover.Content>
      </Popover.Root>

      <Popover.Root>
        <Popover.Trigger class="w-full">
          <Button variant="outline" class="w-full justify-start text-left font-normal">
            <CalendarIcon class="mr-2 h-4 w-4" />
            {dateToDisplay}
          </Button>
        </Popover.Trigger>
        <Popover.Content class="w-auto p-0">
          <Calendar type="single" bind:value={dateTo} />
        </Popover.Content>
      </Popover.Root>
    </div>

    <div class="flex gap-2 mt-4">
      <Button onclick={applyFilters}>Apply Filters</Button>
      <Button variant="outline" onclick={clearFilters}>Clear All</Button>
    </div>
  </div>

  <!-- List -->
  <div class="rounded-lg overflow-hidden shadow">
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Time</TableHead>
          <TableHead>Action</TableHead>
          <TableHead>User</TableHead>
          <TableHead>Account</TableHead>
          <TableHead class="w-20"></TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {#if audit_logs.length === 0}
          <TableRow>
            <TableCell colspan="6" class="text-center py-8 text-base-content/60">
              No audit logs found matching your filters
            </TableCell>
          </TableRow>
        {:else}
          {#each audit_logs as log}
            <TableRow class="hover cursor-pointer" onclick={() => selectLog(log.id)}>
              <TableCell class="font-mono text-xs">{formatTime(log.created_at)}</TableCell>
              <TableCell>
                <Badge>
                  {log.display_action}
                </Badge>
              </TableCell>
              <TableCell>
                <div class="flex items-center gap-2">
                  {#if log.user}
                    <Avatar user={log.user} size="small" />
                  {/if}
                  <span>{log.actor_name}</span>
                </div>
              </TableCell>
              <TableCell>{log.target_name}</TableCell>
              <TableCell>
                <Button size="sm" variant="ghost">View</Button>
              </TableCell>
            </TableRow>
          {/each}
        {/if}
      </TableBody>
    </Table>

    <PaginationNav {pagination} bind:currentPage onPageChange={goToPage} />
  </div>

  <!-- Detail Drawer -->
  <Drawer open={drawerOpen} onOpenChange={(open) => !open && closeDrawer()}>
    <DrawerContent class="h-[85vh] max-w-3xl mx-auto">
      {#if selected_log}
        <DrawerHeader class="border-b pb-4">
          <DrawerTitle class="text-xl font-semibold flex items-center gap-3">
            <span>Audit Log Details - {selected_log.display_action}</span>
          </DrawerTitle>
        </DrawerHeader>

        <div class="overflow-y-auto flex-1 p-6">
          <div class="space-y-6">
            <!-- Primary Information Section -->
            <InfoCard title="Event Information" icon="Info">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">Timestamp</dt>
                  <dd class="mt-1 text-sm font-medium">
                    {new Date(selected_log.created_at).toLocaleString('en-US', {
                      dateStyle: 'medium',
                      timeStyle: 'medium',
                    })}
                  </dd>
                </div>

                <div>
                  <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">Event ID</dt>
                  <dd class="mt-1 text-sm font-mono bg-muted px-2 py-1 rounded inline-block">
                    #{selected_log.id}
                  </dd>
                </div>
              </div>
            </InfoCard>

            <!-- Actor Information -->
            {#if selected_log.user || selected_log.account}
              <InfoCard title="Actor Information" icon="User">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {#if selected_log.user}
                    <div>
                      <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">User</dt>
                      <dd class="mt-1 text-sm">
                        <div class="flex items-center gap-2">
                          <Avatar user={selected_log.user} size="small" />
                          <div>
                            <div class="font-medium">{selected_log.user.email_address}</div>
                            {#if selected_log.user.id}
                              <div class="text-xs text-muted-foreground">ID: {selected_log.user.id}</div>
                            {/if}
                          </div>
                        </div>
                      </dd>
                    </div>
                  {/if}

                  {#if selected_log.account}
                    <div>
                      <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">Account</dt>
                      <dd class="mt-1 text-sm">
                        <div class="font-medium">{selected_log.account.name}</div>
                        {#if selected_log.account.id}
                          <div class="text-xs text-muted-foreground">ID: {selected_log.account.id}</div>
                        {/if}
                      </dd>
                    </div>
                  {/if}
                </div>
              </InfoCard>
            {/if}

            <!-- Affected Object -->
            {#if selected_log.auditable_type || selected_log.auditable}
              <InfoCard title="Affected Object" icon="Target">
                <div class="space-y-4">
                  <div>
                    <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">Object Type</dt>
                    <dd class="mt-1 text-sm font-medium">
                      <span class="bg-primary/10 text-primary px-2 py-1 rounded">
                        {selected_log.auditable_type} #{selected_log.auditable_id}
                      </span>
                    </dd>
                  </div>

                  {#if selected_log.auditable}
                    <div>
                      <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">
                        Object Data
                      </dt>
                      <dd>
                        <div class="rounded-lg overflow-x-auto text-xs">
                          <Highlight language={json} code={JSON.stringify(selected_log.auditable, null, 2)} />
                        </div>
                      </dd>
                    </div>
                  {/if}
                </div>
              </InfoCard>
            {/if}

            <!-- Additional Data -->
            {#if selected_log.data && Object.keys(selected_log.data).length > 0}
              <InfoCard title="Additional Data" icon="Database">
                <div class="rounded-lg overflow-x-auto text-xs">
                  <Highlight language={json} code={JSON.stringify(selected_log.data, null, 2)} />
                </div>
              </InfoCard>
            {/if}

            <!-- Technical Details -->
            {#if selected_log.ip_address || selected_log.user_agent}
              <InfoCard title="Technical Details" icon="GearSix">
                <div class="space-y-3">
                  {#if selected_log.ip_address}
                    <div>
                      <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">IP Address</dt>
                      <dd class="mt-1 text-sm font-mono bg-muted px-2 py-1 rounded inline-block">
                        {selected_log.ip_address}
                      </dd>
                    </div>
                  {/if}

                  {#if selected_log.user_agent}
                    <div>
                      <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">User Agent</dt>
                      <dd class="mt-1 text-xs bg-muted p-2 rounded break-words font-mono">
                        {selected_log.user_agent}
                      </dd>
                    </div>
                  {/if}
                </div>
              </InfoCard>
            {/if}
          </div>
        </div>

        <div class="p-4 border-t bg-background">
          <DrawerClose asChild>
            <Button variant="outline" class="w-full sm:w-auto">Close</Button>
          </DrawerClose>
        </div>
      {/if}
    </DrawerContent>
  </Drawer>
</div>
