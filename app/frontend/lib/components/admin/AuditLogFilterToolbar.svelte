<script>
  import { DateFormatter, getLocalTimeZone } from '@internationalized/date';
  import { Calendar as CalendarIcon } from 'phosphor-svelte';
  import AuditLogMultiSelectFilter from '$lib/components/admin/AuditLogMultiSelectFilter.svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Calendar } from '$lib/components/shadcn/calendar/index.js';
  import * as Popover from '$lib/components/shadcn/popover/index.js';

  let {
    userFilter = $bindable(undefined),
    accountFilter = $bindable(undefined),
    actionFilter = $bindable(undefined),
    typeFilter = $bindable(undefined),
    dateFrom = $bindable(undefined),
    dateTo = $bindable(undefined),
    userItems = [],
    accountItems = [],
    actionItems = [],
    typeItems = [],
    onApply,
    onClear,
  } = $props();

  const dateFormatter = new DateFormatter('en-US', { dateStyle: 'medium' });

  let dateFromDisplay = $derived(
    dateFrom && dateFrom.toDate ? dateFormatter.format(dateFrom.toDate(getLocalTimeZone())) : 'From date'
  );
  let dateToDisplay = $derived(
    dateTo && dateTo.toDate ? dateFormatter.format(dateTo.toDate(getLocalTimeZone())) : 'To date'
  );
</script>

<div class="rounded-lg p-4 mb-6">
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-6 gap-4">
    <AuditLogMultiSelectFilter bind:value={userFilter} items={userItems} placeholder="All Users" />
    <AuditLogMultiSelectFilter bind:value={accountFilter} items={accountItems} placeholder="All Accounts" />
    <AuditLogMultiSelectFilter bind:value={actionFilter} items={actionItems} placeholder="All Actions" />
    <AuditLogMultiSelectFilter bind:value={typeFilter} items={typeItems} placeholder="All Types" />

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
    <Button onclick={onApply}>Apply Filters</Button>
    <Button variant="outline" onclick={onClear}>Clear All</Button>
  </div>
</div>
