<script>
  import { page, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Badge } from '$lib/components/shadcn/badge';
  import Alert from '$lib/components/alert.svelte';
  import { editAccountPath } from '@/routes';
  import { UserCircle, Users, Gear, UserPlus, Trash, Envelope } from 'phosphor-svelte';
  import InviteMemberForm from '$lib/components/forms/InviteMemberForm.svelte';
  import InfoCard from '$lib/components/InfoCard.svelte';

  const { account, can_be_personal, members = [], can_manage = false, current_user_id } = $page.props;

  let showInviteForm = $state(false);

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

  function removeMember(member) {
    if (confirm(`Remove ${member.display_name} from ${account.name}?`)) {
      router.delete(`/accounts/${account.id}/members/${member.id}`);
    }
  }

  function resendInvitation(member) {
    router.post(`/accounts/${account.id}/invitations/${member.id}/resend`);
  }

  function handleInvite(event) {
    const { email, role } = event.detail;
    router.post(`/accounts/${account.id}/invitations`, { email, role });
    showInviteForm = false;
  }

  // Reactive derived values
  $effect(() => {
    // Close invite form on successful submission or error
    if ($page.props.flash?.success || $page.props.flash?.errors) {
      showInviteForm = false;
    }
  });

  const pendingInvitations = $derived(members.filter((m) => m.invitation_pending));
  const activeMembers = $derived(members.filter((m) => !m.invitation_pending));
</script>

<div class="container mx-auto p-8 max-w-6xl">
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

  <!-- Flash Messages -->
  {#if $page.props.flash?.success}
    <Alert type="success" title="Success" description={$page.props.flash.success} class="mb-6" />
  {/if}

  {#if $page.props.flash?.notice}
    <Alert type="notice" title="Notice" description={$page.props.flash.notice} class="mb-6" />
  {/if}

  {#if $page.props.flash?.alert}
    <Alert type="error" title="Alert" description={$page.props.flash.alert} class="mb-6" />
  {/if}

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
    <!-- Account Information -->
    <InfoCard title="Account Information" icon="UserCircle">
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
    </InfoCard>

    <!-- Account Usage -->
    <InfoCard title="Account Usage" icon="Users">
      <dl class="space-y-4">
        <div>
          <dt class="text-sm font-medium text-muted-foreground">Total Users</dt>
          <dd class="text-2xl font-bold">
            {activeMembers.length || 0}
          </dd>
        </div>
      </dl>
    </InfoCard>
  </div>

  <!-- Team Members Section (only for team accounts) -->
  {#if !account.personal}
    <Card class="mt-8">
      <CardHeader>
        <div class="flex items-center justify-between">
          <CardTitle class="text-lg flex items-center gap-2">
            <Users class="h-5 w-5" />
            Team Members ({activeMembers.length})
          </CardTitle>
          {#if can_manage}
            {#if showInviteForm}
              <Button onclick={() => (showInviteForm = false)} variant="outline" size="sm">Cancel</Button>
            {:else}
              <Button onclick={() => (showInviteForm = true)} size="sm" class="gap-2">
                <UserPlus class="h-4 w-4" />
                Invite Member
              </Button>
            {/if}
          {/if}
        </div>
      </CardHeader>
      <CardContent>
        <!-- Invite Form -->
        {#if showInviteForm}
          <div class="mb-6 p-4 border rounded-lg bg-muted/50">
            <InviteMemberForm on:close={() => (showInviteForm = false)} on:invite={handleInvite} />
          </div>
        {/if}

        <!-- Members Table -->
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-b">
                <th class="text-left p-4 font-medium">Name</th>
                <th class="text-left p-4 font-medium">Email</th>
                <th class="text-left p-4 font-medium">Role</th>
                <th class="text-left p-4 font-medium">Joined</th>
                {#if can_manage}
                  <th class="text-left p-4 font-medium">Actions</th>
                {/if}
              </tr>
            </thead>
            <tbody>
              {#each activeMembers as member (member.id)}
                <tr class="border-b">
                  <td class="p-4">
                    <div class="flex items-center gap-2">
                      <span class="font-medium">{member.display_name}</span>
                      {#if member.user_id === current_user_id}
                        <Badge variant="outline" class="text-xs">You</Badge>
                      {/if}
                    </div>
                  </td>
                  <td class="p-4 text-sm">{member.user.email_address}</td>
                  <td class="p-4">
                    <Badge
                      variant={member.role === 'owner' ? 'default' : member.role === 'admin' ? 'secondary' : 'outline'}>
                      {member.role}
                    </Badge>
                  </td>
                  <td class="p-4 text-sm text-muted-foreground">
                    {member.confirmed_at ? formatDate(member.confirmed_at) : 'Not confirmed'}
                  </td>
                  {#if can_manage}
                    <td class="p-4">
                      {#if member.can_remove}
                        <Button
                          variant="ghost"
                          size="sm"
                          onclick={() => removeMember(member)}
                          class="text-destructive hover:text-destructive">
                          <Trash class="h-4 w-4" />
                          Remove
                        </Button>
                      {/if}
                    </td>
                  {/if}
                </tr>
              {:else}
                <tr>
                  <td colspan={can_manage ? 5 : 4} class="p-8 text-center text-muted-foreground">
                    You're the only member of this team account. Invite others to collaborate with you.
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>

    <!-- Pending Invitations -->
    {#if pendingInvitations.length > 0}
      <Card class="mt-8">
        <CardHeader>
          <CardTitle class="text-lg flex items-center gap-2">
            <Envelope class="h-5 w-5" />
            Pending Invitations ({pendingInvitations.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="border-b">
                  <th class="text-left p-4 font-medium">Email</th>
                  <th class="text-left p-4 font-medium">Role</th>
                  <th class="text-left p-4 font-medium">Invited By</th>
                  <th class="text-left p-4 font-medium">Invited On</th>
                  {#if can_manage}
                    <th class="text-left p-4 font-medium">Actions</th>
                  {/if}
                </tr>
              </thead>
              <tbody>
                {#each pendingInvitations as member (member.id)}
                  <tr class="border-b">
                    <td class="p-4">{member.user.email_address}</td>
                    <td class="p-4">
                      <Badge variant="outline">{member.role}</Badge>
                    </td>
                    <td class="p-4 text-sm">
                      {member.invited_by?.full_name || 'System'}
                    </td>
                    <td class="p-4 text-sm text-muted-foreground">
                      {formatDate(member.invited_at)}
                    </td>
                    {#if can_manage}
                      <td class="p-4">
                        <div class="flex items-center gap-2">
                          <Button variant="ghost" size="sm" onclick={() => resendInvitation(member)}>
                            <Envelope class="h-4 w-4" />
                            Resend
                          </Button>
                          {#if member.can_remove}
                            <Button
                              variant="ghost"
                              size="sm"
                              onclick={() => removeMember(member)}
                              class="text-destructive hover:text-destructive">
                              <Trash class="h-4 w-4" />
                              Cancel
                            </Button>
                          {/if}
                        </div>
                      </td>
                    {/if}
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    {/if}
  {/if}

  <!-- Account Type Switching -->
  <InfoCard title="Account Type" icon="UserSwitch" class="mt-8">
    <div class="space-y-4">
      <p class="text-muted-foreground">
        {#if account.personal}
          Your account is currently set up as a personal account. You can convert it to a team account to collaborate
          with others.
        {:else}
          Your account is currently set up as a team account.
        {/if}
      </p>

      <div class="flex gap-4">
        {#if account.personal}
          <Button onclick={goToEdit} variant="outline">Convert to Team Account</Button>
        {:else if can_be_personal}
          <Button onclick={goToEdit} variant="outline">Convert to Personal Account</Button>
        {/if}
      </div>

      <!-- Conversion Note -->
      {#if !account.personal}
        {#if can_be_personal}
          <Alert type="notice" title="Can convert to personal account">
            Since you're the only member, you can convert this team account back to a personal account.
          </Alert>
        {:else}
          <Alert type="warning" title="Cannot convert to personal account">
            Team accounts with multiple users cannot be converted to personal accounts.
          </Alert>
        {/if}
      {/if}
    </div>
  </InfoCard>
</div>
