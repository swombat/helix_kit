export function filterArrayFromParam(value) {
  if (typeof value !== 'string' || value.length === 0) return undefined;
  const values = value.split(',').filter(Boolean);
  return values.length > 0 ? values : undefined;
}

export function initialAuditLogFilters(currentFilters = {}) {
  return {
    userFilter: filterArrayFromParam(currentFilters.user_id),
    accountFilter: filterArrayFromParam(currentFilters.filter_account_id),
    actionFilter: filterArrayFromParam(currentFilters.audit_action),
    typeFilter: filterArrayFromParam(currentFilters.auditable_type),
  };
}

export function auditLogFilterParams({
  userFilter,
  accountFilter,
  actionFilter,
  typeFilter,
  dateFrom,
  dateTo,
  page = 1,
}) {
  return {
    user_id: userFilter ? userFilter.join(',') : undefined,
    filter_account_id: accountFilter ? accountFilter.join(',') : undefined,
    audit_action: actionFilter ? actionFilter.join(',') : undefined,
    auditable_type: typeFilter ? typeFilter.join(',') : undefined,
    date_from: dateFrom ? dateFrom.toString() : undefined,
    date_to: dateTo ? dateTo.toString() : undefined,
    page,
  };
}

export function compactAuditLogParams(params = {}) {
  const searchParams = new URLSearchParams();

  Object.entries(params).forEach(([key, value]) => {
    if (value) searchParams.set(key, value);
  });

  return searchParams;
}

export function withoutSelectedAuditLog(currentFilters = {}) {
  const params = { ...currentFilters };
  delete params.log_id;
  return params;
}
