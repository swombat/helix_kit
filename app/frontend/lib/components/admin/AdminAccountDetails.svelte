<script>
  import { Badge } from '$lib/components/shadcn/badge';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '$lib/components/shadcn/table';
  import InfoCard from '$lib/components/InfoCard.svelte';
  import Avatar from '$lib/components/Avatar.svelte';

  let { account, formatDate } = $props();
</script>

<div class="p-8">
  <div class="mb-8">
    <h1 class="text-3xl font-bold mb-2">{account.name}</h1>
    <div class="flex gap-4 text-sm text-muted-foreground">
      <Badge variant="outline">
        {account.account_type === 'personal' ? 'Personal Account' : 'Organization'}
      </Badge>
    </div>
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

  <Card>
    <CardHeader>
      <CardTitle class="mb-2">Users ({account.users_count || 0})</CardTitle>
    </CardHeader>
    <CardContent>
      {#if account.users && account.users.length > 0}
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Email</TableHead>
              <TableHead>Role</TableHead>
              <TableHead>Joined</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {#each account.users as user (user.id)}
              <TableRow class={user.confirmed ? '' : 'opacity-50'}>
                <TableCell>
                  <div class="flex items-center gap-2">
                    <Avatar {user} size="small" />
                    <span>{user.full_name || '-'}</span>
                  </div>
                </TableCell>
                <TableCell>
                  <div class="font-medium">{user.email_address}</div>
                </TableCell>
                <TableCell>
                  <Badge variant={user.role === 'owner' ? 'default' : 'secondary'}>
                    {user.role}
                  </Badge>
                </TableCell>
                <TableCell class="text-sm text-muted-foreground">
                  {formatDate(user.created_at)}
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
