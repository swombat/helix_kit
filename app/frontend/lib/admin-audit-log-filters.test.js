import { describe, expect, test } from 'vitest';
import {
  auditLogFilterParams,
  compactAuditLogParams,
  filterArrayFromParam,
  initialAuditLogFilters,
  withoutSelectedAuditLog,
} from './admin-audit-log-filters';

describe('admin audit log filters', () => {
  test('parses comma-separated query params into filter arrays', () => {
    expect(filterArrayFromParam('1,2,3')).toEqual(['1', '2', '3']);
    expect(filterArrayFromParam('')).toBeUndefined();
    expect(filterArrayFromParam(undefined)).toBeUndefined();
  });

  test('initializes the page filter state from Rails query params', () => {
    expect(
      initialAuditLogFilters({
        user_id: '1,2',
        filter_account_id: '3',
        audit_action: 'create,update',
        auditable_type: 'User',
      })
    ).toEqual({
      userFilter: ['1', '2'],
      accountFilter: ['3'],
      actionFilter: ['create', 'update'],
      typeFilter: ['User'],
    });
  });

  test('serializes active filters for navigation', () => {
    expect(
      auditLogFilterParams({
        userFilter: ['1', '2'],
        accountFilter: undefined,
        actionFilter: ['update'],
        typeFilter: ['Account'],
        dateFrom: { toString: () => '2026-05-01' },
        dateTo: undefined,
      })
    ).toEqual({
      user_id: '1,2',
      filter_account_id: undefined,
      audit_action: 'update',
      auditable_type: 'Account',
      date_from: '2026-05-01',
      date_to: undefined,
      page: 1,
    });
  });

  test('compacts params for URLSearchParams and removes the selected log', () => {
    expect(compactAuditLogParams({ user_id: '1', audit_action: undefined, page: 1 }).toString()).toBe(
      'user_id=1&page=1'
    );
    expect(withoutSelectedAuditLog({ user_id: '1', log_id: '99' })).toEqual({ user_id: '1' });
  });
});
