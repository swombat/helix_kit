<script>
  import { Badge } from '$lib/components/shadcn/badge';
  import InfoCard from '$lib/components/InfoCard.svelte';

  let { account, activeMemberCount = 0, formatDate } = $props();
</script>

<div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
  <InfoCard title="Account Information" icon="UserCircle">
    <dl class="space-y-4">
      <div>
        <dt class="text-sm font-medium text-muted-foreground">Account Name</dt>
        <dd class="text-lg font-semibold">
          {account.name}
        </dd>
      </div>
      <div>
        <dt class="text-sm font-medium text-muted-foreground">Account Type</dt>
        <dd>
          <Badge variant={account.personal ? 'default' : 'secondary'}>
            {account.personal ? 'Personal' : 'Team'}
          </Badge>
        </dd>
      </div>
      <div>
        <dt class="text-sm font-medium text-muted-foreground">Account ID</dt>
        <dd class="font-mono text-sm text-muted-foreground">
          {account.id}
        </dd>
      </div>
      <div>
        <dt class="text-sm font-medium text-muted-foreground">Created</dt>
        <dd class="text-sm">
          {formatDate(account.created_at)}
        </dd>
      </div>
    </dl>
  </InfoCard>

  <InfoCard title="Account Usage" icon="Users">
    <dl class="space-y-4">
      <div>
        <dt class="text-sm font-medium text-muted-foreground">Total Users</dt>
        <dd class="text-2xl font-bold">
          {activeMemberCount}
        </dd>
      </div>
    </dl>
  </InfoCard>
</div>
