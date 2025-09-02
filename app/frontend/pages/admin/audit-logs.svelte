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

  let localFilters = $state({ ...current_filters });
  let drawerOpen = $state(!!selected_log);

  // Date picker setup
  const df = new DateFormatter('en-US', { dateStyle: 'medium' });
  let dateFrom = $state(current_filters.date_from ? parseDate(current_filters.date_from) : undefined);
  let dateTo = $state(current_filters.date_to ? parseDate(current_filters.date_to) : undefined);

  // Derived values for display
  let dateFromDisplay = $derived(
    dateFrom && dateFrom.toDate ? df.format(dateFrom.toDate(getLocalTimeZone())) : 'From date'
  );
  let dateToDisplay = $derived(dateTo && dateTo.toDate ? df.format(dateTo.toDate(getLocalTimeZone())) : 'To date');

  console.log('Pagination', pagination);

  // Update localFilters when dates change
  $effect(() => {
    if (dateFrom) {
      localFilters.date_from = dateFrom.toString();
    } else {
      delete localFilters.date_from;
    }
  });

  $effect(() => {
    if (dateTo) {
      localFilters.date_to = dateTo.toString();
    } else {
      delete localFilters.date_to;
    }
  });

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
    updateUrl({ ...localFilters, page: 1 });
  }

  function clearFilters() {
    localFilters = {};
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
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
      <Select.Root bind:value={localFilters.user_id}>
        <Select.Trigger class="w-full">
          {localFilters.user_id
            ? filters.users?.find((u) => u.id.toString() === localFilters.user_id)?.email_address
            : 'All users'}
        </Select.Trigger>
        <Select.Content>
          <Select.Item value="">All users</Select.Item>
          {#each filters.users || [] as user}
            <Select.Item value={user.id.toString()}>{user.email_address}</Select.Item>
          {/each}
        </Select.Content>
      </Select.Root>

      <Select.Root bind:value={localFilters.account_id}>
        <Select.Trigger class="w-full">
          {localFilters.account_id
            ? filters.accounts?.find((a) => a.id.toString() === localFilters.account_id)?.name
            : 'All accounts'}
        </Select.Trigger>
        <Select.Content>
          <Select.Item value="">All accounts</Select.Item>
          {#each filters.accounts || [] as account}
            <Select.Item value={account.id.toString()}>{account.name}</Select.Item>
          {/each}
        </Select.Content>
      </Select.Root>

      <Select.Root bind:value={localFilters.audit_action}>
        <Select.Trigger class="w-full">
          {localFilters.audit_action || 'All actions'}
        </Select.Trigger>
        <Select.Content>
          <Select.Item value="">All actions</Select.Item>
          {#each filters.actions || [] as action}
            <Select.Item value={action}>{action}</Select.Item>
          {/each}
        </Select.Content>
      </Select.Root>

      <Select.Root bind:value={localFilters.auditable_type}>
        <Select.Trigger class="w-full">
          {localFilters.auditable_type || 'All types'}
        </Select.Trigger>
        <Select.Content>
          <Select.Item value="">All types</Select.Item>
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
          <TableHead>Summary</TableHead>
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
              <TableCell class="font-mono text-sm">{formatTime(log.created_at)}</TableCell>
              <TableCell>
                <Badge class="badge-{getActionColor(log.action)}">
                  {log.display_action}
                </Badge>
              </TableCell>
              <TableCell>{log.actor_name}</TableCell>
              <TableCell>{log.target_name}</TableCell>
              <TableCell>{log.summary}</TableCell>
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
        <span class="text-sm text-base-content/60">
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
    <DrawerContent class="h-[80vh]">
      {#if selected_log}
        <DrawerHeader>
          <DrawerTitle>Audit Log Details</DrawerTitle>
        </DrawerHeader>

        <div class="overflow-y-auto flex-1 p-6">
          <dl class="grid grid-cols-1 gap-4">
            <div>
              <dt class="font-medium text-sm text-base-content/60">ID</dt>
              <dd class="mt-1 font-mono">#{selected_log.id}</dd>
            </div>

            <div>
              <dt class="font-medium text-sm text-base-content/60">Action</dt>
              <dd class="mt-1">
                <Badge class="badge-{getActionColor(selected_log.action)}">
                  {selected_log.display_action}
                </Badge>
              </dd>
            </div>

            <div>
              <dt class="font-medium text-sm text-base-content/60">Timestamp</dt>
              <dd class="mt-1">{new Date(selected_log.created_at).toLocaleString()}</dd>
            </div>

            {#if selected_log.user}
              <div>
                <dt class="font-medium text-sm text-base-content/60">User</dt>
                <dd class="mt-1">
                  {selected_log.user.email_address}
                  {#if selected_log.user.id}
                    <span class="text-sm text-base-content/60">(ID: {selected_log.user.id})</span>
                  {/if}
                </dd>
              </div>
            {/if}

            {#if selected_log.account}
              <div>
                <dt class="font-medium text-sm text-base-content/60">Account</dt>
                <dd class="mt-1">
                  {selected_log.account.name}
                  {#if selected_log.account.id}
                    <span class="text-sm text-base-content/60">(ID: {selected_log.account.id})</span>
                  {/if}
                </dd>
              </div>
            {/if}

            {#if selected_log.auditable_type || selected_log.auditable}
              <div>
                <dt class="font-medium text-sm text-base-content/60">Affected Object</dt>
                <dd class="mt-1">
                  <div>{selected_log.auditable_type} #{selected_log.auditable_id}</div>
                  {#if selected_log.auditable}
                    <pre class="mt-2 p-3 rounded text-xs overflow-x-auto">
{JSON.stringify(selected_log.auditable, null, 2)}
                    </pre>
                  {/if}
                </dd>
              </div>
            {/if}

            {#if selected_log.data && Object.keys(selected_log.data).length > 0}
              <div>
                <dt class="font-medium text-sm text-base-content/60">Additional Data</dt>
                <dd class="mt-1">
                  <pre class="p-3 rounded text-xs overflow-x-auto">
{JSON.stringify(selected_log.data, null, 2)}
                  </pre>
                </dd>
              </div>
            {/if}

            {#if selected_log.ip_address}
              <div>
                <dt class="font-medium text-sm text-base-content/60">IP Address</dt>
                <dd class="mt-1 font-mono">{selected_log.ip_address}</dd>
              </div>
            {/if}

            {#if selected_log.user_agent}
              <div>
                <dt class="font-medium text-sm text-base-content/60">User Agent</dt>
                <dd class="mt-1 text-sm break-words">{selected_log.user_agent}</dd>
              </div>
            {/if}
          </dl>
        </div>

        <div class="p-4 border-t">
          <DrawerClose asChild>
            <Button variant="outline">Close</Button>
          </DrawerClose>
        </div>
      {/if}
    </DrawerContent>
  </Drawer>
</div>
