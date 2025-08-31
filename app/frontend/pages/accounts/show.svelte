<script>
  import { page, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Badge } from '$lib/components/shadcn/badge';
  import { editAccountPath } from '@/routes';
  import { UserCircle, Users, Gear } from 'phosphor-svelte';

  const { account, can_be_personal } = $page.props;

  function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  function goToEdit() {
    router.visit(editAccountPath(account.id));
  }
</script>

<div class="container mx-auto p-8 max-w-4xl">
  <div class="mb-8">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-3xl font-bold mb-2">Account Settings</h1>
        <p class="text-muted-foreground">Manage your account type and settings</p>
      </div>
      <Button onclick={goToEdit} class="gap-2">
        <Gear class="h-4 w-4" />
        Edit Account
      </Button>
    </div>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
    <!-- Account Information -->
    <Card>
      <CardHeader>
        <CardTitle class="flex items-center gap-2">
          <UserCircle class="h-5 w-5" />
          Account Information
        </CardTitle>
      </CardHeader>
      <CardContent>
        <dl class="space-y-4">
          <div>
            <dt class="text-sm font-medium text-muted-foreground">Account Name</dt>
            <dd class="text-lg font-semibold">
              {account.personal ? 'Personal Account' : account.name}
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
      </CardContent>
    </Card>

    <!-- Account Usage -->
    <Card>
      <CardHeader>
        <CardTitle class="flex items-center gap-2">
          <Users class="h-5 w-5" />
          Account Usage
        </CardTitle>
      </CardHeader>
      <CardContent>
        <dl class="space-y-4">
          <div>
            <dt class="text-sm font-medium text-muted-foreground">Total Users</dt>
            <dd class="text-2xl font-bold">
              {account.users?.length || account.users_count || 0}
            </dd>
          </div>
          {#if !account.personal && can_be_personal}
            <div class="p-3 bg-blue-50 dark:bg-blue-950/20 rounded-md border border-blue-200 dark:border-blue-800">
              <p class="text-sm text-blue-800 dark:text-blue-200">
                <strong>Note:</strong> You can convert this team account back to personal since you're the only member.
              </p>
            </div>
          {:else if !account.personal}
            <div class="p-3 bg-amber-50 dark:bg-amber-950/20 rounded-md border border-amber-200 dark:border-amber-800">
              <p class="text-sm text-amber-800 dark:text-amber-200">
                <strong>Note:</strong> Team accounts with multiple users cannot be converted to personal accounts.
              </p>
            </div>
          {/if}
        </dl>
      </CardContent>
    </Card>
  </div>

  <!-- Account Type Switching -->
  <Card class="mt-8">
    <CardHeader>
      <CardTitle>Account Type</CardTitle>
    </CardHeader>
    <CardContent>
      <div class="space-y-4">
        <p class="text-muted-foreground">
          {#if account.personal}
            Your account is currently set up as a personal account. You can convert it to a team account to collaborate
            with others.
          {:else}
            Your account is currently set up as a team account.
            {#if can_be_personal}
              Since you're the only member, you can convert it back to a personal account.
            {:else}
              Team accounts with multiple users cannot be converted to personal accounts.
            {/if}
          {/if}
        </p>

        <div class="flex gap-4">
          {#if account.personal}
            <Button onclick={goToEdit} variant="outline">Convert to Team Account</Button>
          {:else if can_be_personal}
            <Button onclick={goToEdit} variant="outline">Convert to Personal Account</Button>
          {/if}
        </div>
      </div>
    </CardContent>
  </Card>
</div>
