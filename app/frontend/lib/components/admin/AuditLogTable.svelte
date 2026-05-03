<script>
  import { formatDistanceToNow } from 'date-fns';
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '$lib/components/shadcn/table/index.js';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Badge } from '$lib/components/shadcn/badge/index.js';
  import PaginationNav from '$lib/components/navigation/PaginationNav.svelte';
  import Avatar from '$lib/components/Avatar.svelte';

  let {
    auditLogs = [],
    pagination = {},
    currentPage = $bindable(1),
    onSelectLog = () => {},
    onPageChange = () => {},
  } = $props();

  function formatTime(dateString) {
    return formatDistanceToNow(new Date(dateString), { addSuffix: true });
  }
</script>

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
      {#if auditLogs.length === 0}
        <TableRow>
          <TableCell colspan="6" class="text-center py-8 text-base-content/60">
            No audit logs found matching your filters
          </TableCell>
        </TableRow>
      {:else}
        {#each auditLogs as log}
          <TableRow class="hover cursor-pointer" onclick={() => onSelectLog(log.id)}>
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

  <PaginationNav {pagination} bind:currentPage {onPageChange} />
</div>
