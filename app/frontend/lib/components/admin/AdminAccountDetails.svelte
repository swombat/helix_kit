<script>
  import { router } from '@inertiajs/svelte';
  import { Badge } from '$lib/components/shadcn/badge';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '$lib/components/shadcn/table';
  import InfoCard from '$lib/components/InfoCard.svelte';
  import Avatar from '$lib/components/Avatar.svelte';
  import { Trash } from 'phosphor-svelte';

  let { account, formatDate } = $props();
  let teamName = $state(account.name || '');

  $effect(() => {
    teamName = account.name || '';
  });

  const members = $derived(account.memberships || []);

  function toggleDisabled() {
    const action = account.disabled ? 'enable' : 'disable';
    const label = account.disabled ? 'enable' : 'disable';
    if (!confirm(`Are you sure you want to ${label} ${account.name}?`)) return;

    router.patch(`/admin/accounts/${account.id}/${action}`);
  }

  function convertToTeam() {
    router.patch(`/admin/accounts/${account.id}/convert`, {
      account_type: 'team',
      account: { name: teamName },
    });
  }

  function convertToPersonal() {
    if (!confirm(`Convert ${account.name} to a personal account? This requires exactly one member.`)) return;

    router.patch(`/admin/accounts/${account.id}/convert`, { account_type: 'personal' });
  }

  function removeMember(member) {
    if (!confirm(`Remove ${member.email_address || member.user?.email_address} from ${account.name}?`)) return;

    router.delete(`/admin/accounts/${account.id}/memberships/${member.id}`);
  }
</script>

<div class="p-8">
  <div class="mb-8 flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
    <div>
      <h1 class="text-3xl font-bold mb-2">{account.name}</h1>
      <div class="flex gap-2 text-sm text-muted-foreground">
        <Badge variant="outline">
          {account.account_type === 'personal' ? 'Personal Account' : 'Organization'}
        </Badge>
        {#if account.disabled}
          <Badge variant="destructive">Disabled</Badge>
        {:else}
          <Badge variant="secondary">Enabled</Badge>
        {/if}
      </div>
    </div>

    <Button variant={account.disabled ? 'default' : 'destructive'} onclick={toggleDisabled}>
      {account.disabled ? 'Enable Account' : 'Disable Account'}
    </Button>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
    <InfoCard title="Account Information" icon="Info">
      <dl class="space-y-3">
        <div>
          <dt class="text-sm text-muted-foreground">Account ID</dt>
          <dd class="font-mono text-sm">{account.id}</dd>
        </div>
        <div>
          <dt class="text-sm text-muted-foreground">Type</dt>
          <dd>{account.account_type === 'personal' ? 'Personal' : 'Organization'}</dd>
        </div>
        {#if account.owner}
          <div>
            <dt class="text-sm text-muted-foreground">Owner</dt>
            <dd>
              <div class="flex items-center gap-2">
                <Avatar user={account.owner} size="small" />
                <div>
                  {account.owner.name || account.owner.email_address}
                  {#if account.owner.name}
                    <div class="text-sm text-muted-foreground">{account.owner.email_address}</div>
                  {/if}
                </div>
              </div>
            </dd>
          </div>
        {/if}
      </dl>
    </InfoCard>

    <InfoCard title="Statistics" icon="ChartBar">
      <dl class="space-y-3">
        <div>
          <dt class="text-sm text-muted-foreground">Total Users</dt>
          <dd class="text-2xl font-bold">{account.users_count || 0}</dd>
        </div>
        <div>
          <dt class="text-sm text-muted-foreground">Created</dt>
          <dd>{formatDate(account.created_at)}</dd>
        </div>
        <div>
          <dt class="text-sm text-muted-foreground">Last Updated</dt>
          <dd>{formatDate(account.updated_at)}</dd>
        </div>
      </dl>
    </InfoCard>
  </div>

  <Card class="mb-8">
    <CardHeader>
      <CardTitle>Account Type</CardTitle>
      <CardDescription>Convert this account between personal and team modes.</CardDescription>
    </CardHeader>
    <CardContent>
      {#if account.account_type === 'personal'}
        <div class="flex flex-col gap-3 md:flex-row md:items-end">
          <label class="flex-1 text-sm font-medium">
            Team name
            <input
              class="mt-1 flex h-9 w-full rounded-md border border-input bg-background px-3 py-1 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
              bind:value={teamName} />
          </label>
          <Button onclick={convertToTeam}>Convert to Team</Button>
        </div>
      {:else}
        <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <p class="text-sm text-muted-foreground">
            Team accounts can become personal accounts only when exactly one membership remains.
          </p>
          <Button onclick={convertToPersonal} disabled={members.length !== 1}>Convert to Personal</Button>
        </div>
      {/if}
    </CardContent>
  </Card>

  <Card>
    <CardHeader>
      <CardTitle class="mb-2">Users ({members.length})</CardTitle>
    </CardHeader>
    <CardContent>
      {#if members.length > 0}
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Email</TableHead>
              <TableHead>Role</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Joined</TableHead>
              <TableHead>Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {#each members as member (member.id)}
              <TableRow class={member.confirmed ? '' : 'opacity-50'}>
                <TableCell>
                  <div class="flex items-center gap-2">
                    <Avatar user={member.user} size="small" />
                    <span>{member.full_name || member.display_name || '-'}</span>
                  </div>
                </TableCell>
                <TableCell>
                  <div class="font-medium">{member.email_address || member.user?.email_address}</div>
                </TableCell>
                <TableCell>
                  <Badge variant={member.role === 'owner' ? 'default' : 'secondary'}>
                    {member.role}
                  </Badge>
                </TableCell>
                <TableCell class="capitalize">{member.status}</TableCell>
                <TableCell class="text-sm text-muted-foreground">
                  {formatDate(member.created_at)}
                </TableCell>
                <TableCell>
                  <Button
                    variant="ghost"
                    size="sm"
                    onclick={() => removeMember(member)}
                    disabled={member.role === 'owner' &&
                      members.filter((m) => m.role === 'owner' && m.confirmed).length === 1}
                    class="text-destructive hover:text-destructive opacity-60 hover:opacity-100">
                    <Trash class="h-4 w-4" />
                    Remove
                  </Button>
                </TableCell>
              </TableRow>
            {/each}
          </TableBody>
        </Table>
      {:else}
        <p class="text-muted-foreground">No users in this account.</p>
      {/if}
    </CardContent>
  </Card>
</div>
