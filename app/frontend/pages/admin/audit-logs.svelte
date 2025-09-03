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
  import {
    Pagination,
    PaginationContent,
    PaginationItem,
    PaginationLink,
    PaginationPrevButton,
    PaginationNextButton,
    PaginationEllipsis,
  } from '$lib/components/shadcn/pagination/index.js';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Badge } from '$lib/components/shadcn/badge/index.js';
  import { formatDistanceToNow } from 'date-fns';
  import { Calendar as CalendarIcon } from 'phosphor-svelte';
  import { DateFormatter, getLocalTimeZone, parseDate, CalendarDate } from '@internationalized/date';
  import { Calendar } from '$lib/components/shadcn/calendar/index.js';
  import * as Popover from '$lib/components/shadcn/popover/index.js';

  let { audit_logs = [], selected_log = null, pagination = {}, filters = {}, current_filters = {} } = $props();

  let drawerOpen = $state(!!selected_log);

  // Initialize filter arrays from current_filters
  let userFilter = $state(typeof current_filters.user_id === 'string' ? current_filters.user_id.split(',') : undefined);
  let accountFilter = $state(
    typeof current_filters.account_id === 'string' ? current_filters.account_id.split(',') : undefined
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
      account_id: accountFilter ? accountFilter.join(',') : undefined,
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
    updateUrl({ ...current_filters, page });
  }

  function formatTime(dateString) {
    return formatDistanceToNow(new Date(dateString), { addSuffix: true });
  }

  function getActionColor(action) {
    const colorMap = {
      create: 'success',
      update: 'warning',
      delete: 'error',
      destroy: 'error',
      login: 'info',
      logout: 'info',
      register: 'primary',
    };
    return colorMap[action.toLowerCase()] || 'default';
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
              All users
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
          <span class="truncate">
            {accountFilter && accountFilter.length > 0
              ? accountFilter
                  .map((id) => filters.accounts?.find((a) => a.id.toString() === id)?.name)
                  .filter(Boolean)
                  .join(', ')
              : 'All accounts'}
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
          <span class="truncate">
            {actionFilter && actionFilter.length > 0 ? actionFilter.join(', ') : 'All actions'}
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
          <span class="truncate">
            {typeFilter && typeFilter.length > 0 ? typeFilter.join(', ') : 'All types'}
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
                <Badge class="badge-{getActionColor(log.action)}">
                  {log.display_action}
                </Badge>
              </TableCell>
              <TableCell>{log.actor_name}</TableCell>
              <TableCell>{log.target_name}</TableCell>
              <TableCell>
                <Button size="sm" variant="ghost">View</Button>
              </TableCell>
            </TableRow>
          {/each}
        {/if}
      </TableBody>
    </Table>

    {#if pagination.last > 1}
      <div class="flex justify-between items-center p-4 border-t">
        <span class="text-sm text-base-content/60 whitespace-nowrap">
          Showing {pagination.from || 0} to {pagination.to || 0} of {pagination.count} entries
        </span>
        <Pagination>
          <PaginationContent>
            <PaginationItem>
              <PaginationPrevButton
                disabled={!pagination.prev}
                onclick={() => pagination.prev && goToPage(pagination.prev)} />
            </PaginationItem>

            {#each pagination.series || [] as item}
              {#if item === 'gap'}
                <PaginationItem>
                  <PaginationEllipsis />
                </PaginationItem>
              {:else}
                <PaginationItem>
                  <PaginationLink page={item} isActive={item == pagination.page} onclick={() => goToPage(item)}>
                    {item}
                  </PaginationLink>
                </PaginationItem>
              {/if}
            {/each}

            <PaginationItem>
              <PaginationNextButton
                disabled={!pagination.next}
                onclick={() => pagination.next && goToPage(pagination.next)} />
            </PaginationItem>
          </PaginationContent>
        </Pagination>
      </div>
    {/if}
  </div>

  <!-- Detail Drawer -->
  <Drawer open={drawerOpen} onOpenChange={(open) => !open && closeDrawer()}>
    <DrawerContent class="h-[85vh] max-w-3xl mx-auto">
      {#if selected_log}
        <DrawerHeader class="border-b pb-4">
          <DrawerTitle class="text-xl font-semibold flex items-center gap-3">
            <span>Audit Log Details</span>
            <Badge class="badge-{getActionColor(selected_log.action)}">
              {selected_log.display_action}
            </Badge>
          </DrawerTitle>
          <p class="text-sm text-muted-foreground mt-2">
            {formatTime(selected_log.created_at)} • Event #{selected_log.id}
          </p>
        </DrawerHeader>

        <div class="overflow-y-auto flex-1 p-6">
          <div class="space-y-6">
            <!-- Primary Information Section -->
            <div class="bg-card rounded-lg border p-4 space-y-4">
              <h3 class="font-semibold text-base mb-3">Event Information</h3>

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
            </div>

            <!-- Actor Information -->
            {#if selected_log.user || selected_log.account}
              <div class="bg-card rounded-lg border p-4 space-y-4">
                <h3 class="font-semibold text-base mb-3">Actor Information</h3>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {#if selected_log.user}
                    <div>
                      <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">User</dt>
                      <dd class="mt-1 text-sm">
                        <div class="font-medium">{selected_log.user.email_address}</div>
                        {#if selected_log.user.id}
                          <div class="text-xs text-muted-foreground">ID: {selected_log.user.id}</div>
                        {/if}
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
              </div>
            {/if}

            <!-- Affected Object -->
            {#if selected_log.auditable_type || selected_log.auditable}
              <div class="bg-card rounded-lg border p-4 space-y-4">
                <h3 class="font-semibold text-base mb-3">Affected Object</h3>

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
                    <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">Object Data</dt>
                    <dd>
                      <pre class="bg-muted p-3 rounded-lg text-xs overflow-x-auto font-mono">
{JSON.stringify(selected_log.auditable, null, 2)}
                      </pre>
                    </dd>
                  </div>
                {/if}
              </div>
            {/if}

            <!-- Additional Data -->
            {#if selected_log.data && Object.keys(selected_log.data).length > 0}
              <div class="bg-card rounded-lg border p-4 space-y-4">
                <h3 class="font-semibold text-base mb-3">Additional Data</h3>

                <pre class="bg-muted p-3 rounded-lg text-xs overflow-x-auto font-mono">
{JSON.stringify(selected_log.data, null, 2)}
                </pre>
              </div>
            {/if}

            <!-- Technical Details -->
            {#if selected_log.ip_address || selected_log.user_agent}
              <div class="bg-card rounded-lg border p-4 space-y-4">
                <h3 class="font-semibold text-base mb-3">Technical Details</h3>

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
              </div>
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
