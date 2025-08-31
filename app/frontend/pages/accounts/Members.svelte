<script>
  import { page, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Badge } from '$lib/components/shadcn/badge';
  import { Alert, AlertDescription } from '$lib/components/shadcn/alert';
  import { Users, UserPlus, Trash, Envelope } from 'phosphor-svelte';
  import InviteMemberForm from '$lib/components/forms/InviteMemberForm.svelte';

  const { account, members = [], can_manage = false, current_user_id } = $page.props;

  let showInviteForm = $state(false);

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

  function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
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
        <h1 class="text-3xl font-bold mb-2 flex items-center gap-2">
          <Users class="h-8 w-8" />
          Team Members
        </h1>
        <p class="text-muted-foreground">Manage your team members and invitations</p>
      </div>
      {#if can_manage && !account.personal}
        <Button onclick={() => (showInviteForm = true)} class="gap-2">
          <UserPlus class="h-4 w-4" />
          Invite Member
        </Button>
      {/if}
    </div>
  </div>

  {#if $page.props.flash?.success}
    <Alert class="mb-6">
      <AlertDescription>{$page.props.flash.success}</AlertDescription>
    </Alert>
  {/if}

  {#if $page.props.flash?.errors}
    <Alert variant="destructive" class="mb-6">
      <AlertDescription>
        {#if Array.isArray($page.props.flash.errors)}
          {$page.props.flash.errors.join(', ')}
        {:else}
          {$page.props.flash.errors}
        {/if}
      </AlertDescription>
    </Alert>
  {/if}

  <!-- Invite Member Form -->
  {#if showInviteForm}
    <InviteMemberForm on:close={() => (showInviteForm = false)} on:invite={handleInvite} />
  {/if}

  <!-- Active Members -->
  <Card class="mb-8">
    <CardHeader>
      <CardTitle class="text-lg flex items-center gap-2">
        <Users class="h-5 w-5" />
        Active Members ({activeMembers.length})
      </CardTitle>
    </CardHeader>
    <CardContent>
      {#if activeMembers.length === 0}
        <p class="text-muted-foreground text-center py-8">No active members found.</p>
      {:else}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-b">
                <th class="text-left p-4 font-medium text-muted-foreground">Name</th>
                <th class="text-left p-4 font-medium text-muted-foreground">Email</th>
                <th class="text-left p-4 font-medium text-muted-foreground">Role</th>
                <th class="text-left p-4 font-medium text-muted-foreground">Joined</th>
                {#if can_manage}<th class="text-left p-4 font-medium text-muted-foreground">Actions</th>{/if}
              </tr>
            </thead>
            <tbody>
              {#each activeMembers as member}
                <tr class="border-b hover:bg-muted/50">
                  <td class="p-4">
                    <div class="font-medium">
                      {member.display_name}
                      {#if member.user.id === current_user_id}
                        <Badge variant="secondary" class="ml-2">You</Badge>
                      {/if}
                    </div>
                  </td>
                  <td class="p-4 text-sm text-muted-foreground">
                    {member.user.email_address}
                  </td>
                  <td class="p-4">
                    <Badge
                      variant={member.role === 'owner' ? 'default' : member.role === 'admin' ? 'secondary' : 'outline'}>
                      {member.role}
                    </Badge>
                  </td>
                  <td class="p-4 text-sm text-muted-foreground">
                    {formatDate(member.confirmed_at)}
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
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </CardContent>
  </Card>

  <!-- Pending Invitations -->
  {#if pendingInvitations.length > 0}
    <Card>
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
                <th class="text-left p-4 font-medium text-muted-foreground">Email</th>
                <th class="text-left p-4 font-medium text-muted-foreground">Role</th>
                <th class="text-left p-4 font-medium text-muted-foreground">Invited By</th>
                <th class="text-left p-4 font-medium text-muted-foreground">Invited</th>
                {#if can_manage}<th class="text-left p-4 font-medium text-muted-foreground">Actions</th>{/if}
              </tr>
            </thead>
            <tbody>
              {#each pendingInvitations as member}
                <tr class="border-b hover:bg-muted/50">
                  <td class="p-4 font-medium">
                    {member.user.email_address}
                  </td>
                  <td class="p-4">
                    <Badge
                      variant={member.role === 'owner' ? 'default' : member.role === 'admin' ? 'secondary' : 'outline'}>
                      {member.role}
                    </Badge>
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

  {#if !account.personal && pendingInvitations.length === 0 && activeMembers.length === 1}
    <Alert class="mt-6">
      <AlertDescription>
        You're the only member of this team account. Invite others to collaborate with you.
      </AlertDescription>
    </Alert>
  {/if}
</div>
