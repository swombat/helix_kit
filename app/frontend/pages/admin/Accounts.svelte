<script>
  import { page } from '@inertiajs/svelte';
  import { router } from '@inertiajs/svelte';
  import { Badge } from '$lib/components/shadcn/badge';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';

  let { accounts = [], selected_account = null } = $props();
  let search = $state('');

  const filtered = $derived(
    accounts.filter((account) => {
      if (!search) return true;
      const term = search.toLowerCase();
      return account.name?.toLowerCase().includes(term) || account.owner?.email?.toLowerCase().includes(term);
    })
  );

  function selectAccount(accountId) {
    router.visit(`/admin/accounts?account_id=${accountId}`, {
      preserveState: true,
      preserveScroll: true,
      only: ['selected_account'],
    });
  }

  function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }
</script>

<div class="flex h-[calc(100vh-4rem)]">
  <!-- Left side: Account list -->
  <aside class="w-96 border-r border-border bg-card flex flex-col">
    <header class="p-4 border-b border-border bg-muted/30">
      <h2 class="text-lg font-semibold mb-3">Accounts</h2>
      <input
        type="search"
        placeholder="Search accounts..."
        bind:value={search}
        class="flex h-9 w-full rounded-md border border-input bg-background px-3 py-1 text-sm shadow-sm transition-colors placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring" />
    </header>

    <div class="flex-1 overflow-y-auto">
      {#if filtered.length === 0}
        <div class="p-4 text-center text-muted-foreground">
          {search ? 'No accounts match your search' : 'No accounts found'}
        </div>
      {:else}
        <nav>
          {#each filtered as account (account.id)}
            <button
              onclick={() => selectAccount(account.id)}
              class="w-full text-left p-4 hover:bg-muted/50 transition-colors border-b border-border
                     {selected_account?.id === account.id ? 'bg-primary/10 border-l-4 border-l-primary' : ''}">
              <div class="font-medium text-base">{account.name}</div>
              <div class="text-sm text-muted-foreground mt-1">
                {account.account_type === 'personal' ? 'Personal' : 'Organization'} •
                {account.users_count}
                {account.users_count === 1 ? 'user' : 'users'}
              </div>
              {#if account.owner}
                <div class="text-xs text-muted-foreground/80 mt-1">
                  Owner: {account.owner.email}
                </div>
              {/if}
            </button>
          {/each}
        </nav>
      {/if}
    </div>
  </aside>

  <!-- Right side: Account details -->
  <main class="flex-1 overflow-y-auto bg-background">
    {#if selected_account}
      <div class="p-8">
        <!-- Account header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold mb-2">{selected_account.name}</h1>
          <div class="flex gap-4 text-sm text-muted-foreground">
            <Badge variant="outline">
              {selected_account.account_type === 'personal' ? 'Personal Account' : 'Organization'}
            </Badge>
            <span>Created {formatDate(selected_account.created_at)}</span>
            {#if selected_account.updated_at}
              <span>Updated {formatDate(selected_account.updated_at)}</span>
            {/if}
          </div>
        </div>

        <!-- Account details -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          <Card>
            <CardHeader>
              <CardTitle>Account Information</CardTitle>
            </CardHeader>
            <CardContent>
              <dl class="space-y-3">
                <div>
                  <dt class="text-sm text-muted-foreground">Account ID</dt>
                  <dd class="font-mono text-sm">{selected_account.id}</dd>
                </div>
                <div>
                  <dt class="text-sm text-muted-foreground">Type</dt>
                  <dd>{selected_account.account_type === 'personal' ? 'Personal' : 'Organization'}</dd>
                </div>
                {#if selected_account.owner}
                  <div>
                    <dt class="text-sm text-muted-foreground">Owner</dt>
                    <dd>
                      {selected_account.owner.name || selected_account.owner.email}
                      {#if selected_account.owner.name}
                        <div class="text-sm text-muted-foreground">{selected_account.owner.email}</div>
                      {/if}
                    </dd>
                  </div>
                {/if}
              </dl>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Statistics</CardTitle>
            </CardHeader>
            <CardContent>
              <dl class="space-y-3">
                <div>
                  <dt class="text-sm text-muted-foreground">Total Users</dt>
                  <dd class="text-2xl font-bold">{selected_account.users?.length || 0}</dd>
                </div>
                <div>
                  <dt class="text-sm text-muted-foreground">Created</dt>
                  <dd>{formatDate(selected_account.created_at)}</dd>
                </div>
                <div>
                  <dt class="text-sm text-muted-foreground">Last Updated</dt>
                  <dd>{formatDate(selected_account.updated_at)}</dd>
                </div>
              </dl>
            </CardContent>
          </Card>
        </div>

        <!-- Users list -->
        <Card>
          <CardHeader>
            <CardTitle>
              Users ({selected_account.users?.length || 0})
            </CardTitle>
          </CardHeader>
          <CardContent>
            {#if selected_account.users && selected_account.users.length > 0}
              <div class="overflow-x-auto">
                <table class="table">
                  <thead>
                    <tr>
                      <th>Email</th>
                      <th>Name</th>
                      <th>Role</th>
                      <th>Joined</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each selected_account.users as user (user.id)}
                      <tr>
                        <td>
                          <div class="font-medium">{user.email}</div>
                        </td>
                        <td>{user.name || '-'}</td>
                        <td>
                          <Badge variant={user.role === 'owner' ? 'default' : 'secondary'}>
                            {user.role}
                          </Badge>
                        </td>
                        <td class="text-sm text-muted-foreground">
                          {formatDate(user.created_at)}
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {:else}
              <p class="text-muted-foreground">No users in this account.</p>
            {/if}
          </CardContent>
        </Card>
      </div>
    {:else}
      <div class="flex items-center justify-center h-full">
        <div class="text-center">
          <svg
            class="w-24 h-24 mx-auto mb-4 text-muted-foreground/30"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
            ></path>
          </svg>
          <h3 class="text-lg font-medium mb-2">Select an account</h3>
          <p class="text-muted-foreground">Choose an account from the list to view details</p>
        </div>
      </div>
    {/if}
  </main>
</div>
