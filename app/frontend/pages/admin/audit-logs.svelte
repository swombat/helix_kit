<script>
  import { router } from '@inertiajs/svelte';
  import { createDynamicSync } from '$lib/use-sync';
  import AuditLogFilterToolbar from '$lib/components/admin/AuditLogFilterToolbar.svelte';
  import AuditLogTable from '$lib/components/admin/AuditLogTable.svelte';
  import AuditLogDrawer from '$lib/components/admin/AuditLogDrawer.svelte';
  import { parseDate } from '@internationalized/date';
  import {
    auditLogFilterParams,
    compactAuditLogParams,
    initialAuditLogFilters,
    withoutSelectedAuditLog,
  } from '$lib/admin-audit-log-filters';

  let { audit_logs = [], selected_log = null, pagination = {}, filters = {}, current_filters = {} } = $props();

  let drawerOpen = $state(!!selected_log);

  // Create a reactive page state that syncs with pagination
  let currentPage = $state(pagination.page || 1);

  const initialFilters = initialAuditLogFilters(current_filters);
  let userFilter = $state(initialFilters.userFilter);
  let accountFilter = $state(initialFilters.accountFilter);
  let actionFilter = $state(initialFilters.actionFilter);
  let typeFilter = $state(initialFilters.typeFilter);

  let dateFrom = $state(current_filters.date_from ? parseDate(current_filters.date_from) : undefined);
  let dateTo = $state(current_filters.date_to ? parseDate(current_filters.date_to) : undefined);

  const userFilterItems = $derived(
    (filters.users || []).map((user) => ({
      value: user.id.toString(),
      label: `${user.full_name} <${user.email_address}>`,
      selectedLabel: user.full_name || user.email_address,
    }))
  );
  const accountFilterItems = $derived(
    (filters.accounts || []).map((account) => ({
      value: account.id.toString(),
      label: account.name,
    }))
  );
  const actionFilterItems = $derived((filters.actions || []).map((action) => ({ value: action, label: action })));
  const typeFilterItems = $derived((filters.types || []).map((type) => ({ value: type, label: type })));

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
    const searchParams = compactAuditLogParams(params);

    router.visit(`/admin/audit_logs?${searchParams}`, {
      preserveState: false,
      preserveScroll: false,
    });
  }

  function applyFilters() {
    updateUrl(auditLogFilterParams({ userFilter, accountFilter, actionFilter, typeFilter, dateFrom, dateTo }));
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
    updateUrl(withoutSelectedAuditLog(current_filters));
  }

  function goToPage(page) {
    router.visit(`/admin/audit_logs?${compactAuditLogParams({ ...current_filters, page })}`, {
      preserveState: false,
      preserveScroll: true, // Preserve scroll position
    });
  }
</script>

<div class="container mx-auto px-4 py-6">
  <h1 class="text-2xl font-bold mb-6">Audit Logs</h1>

  <AuditLogFilterToolbar
    bind:userFilter
    bind:accountFilter
    bind:actionFilter
    bind:typeFilter
    bind:dateFrom
    bind:dateTo
    userItems={userFilterItems}
    accountItems={accountFilterItems}
    actionItems={actionFilterItems}
    typeItems={typeFilterItems}
    onApply={applyFilters}
    onClear={clearFilters} />

  <AuditLogTable auditLogs={audit_logs} {pagination} bind:currentPage onSelectLog={selectLog} onPageChange={goToPage} />

  <AuditLogDrawer bind:open={drawerOpen} selectedLog={selected_log} onClose={closeDrawer} />
</div>
