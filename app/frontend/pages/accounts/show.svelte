<script>
  import { page, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Badge } from '$lib/components/shadcn/badge';
  import Alert from '$lib/components/Alert.svelte';
  import { editAccountPath } from '@/routes';
  import { Gear } from 'phosphor-svelte';
  import PendingInvitationsCard from '$lib/components/accounts/PendingInvitationsCard.svelte';
  import TeamMembersCard from '$lib/components/accounts/TeamMembersCard.svelte';
  import InfoCard from '$lib/components/InfoCard.svelte';
  import { useSync } from '$lib/use-sync';
  import * as logging from '$lib/logging';

  let { account, can_be_personal, members = [], can_manage = false, current_user_id } = $props();

  // Subscribe to real-time updates for this account and its members
  useSync({
    [`Account:${account.id}`]: ['account', 'members'],
  });

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

  function goToConvertConfirmation() {
    router.visit(editAccountPath(account.id) + '?convert=true');
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
    logging.debug('Props changed:', $page.props);
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
    <TeamMembersCard
      members={activeMembers}
      canManage={can_manage}
      currentUserId={current_user_id}
      bind:showInviteForm
      {formatDate}
      onInvite={handleInvite}
      onRemoveMember={removeMember} />

    <!-- Pending Invitations -->
    {#if pendingInvitations.length > 0}
      <PendingInvitationsCard
        invitations={pendingInvitations}
        canManage={can_manage}
        {formatDate}
        onResendInvitation={resendInvitation}
        onRemoveMember={removeMember} />
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
          <Button onclick={goToConvertConfirmation} variant="outline">Convert to Team Account</Button>
        {:else if can_be_personal}
          <Button onclick={goToConvertConfirmation} variant="outline">Convert to Personal Account</Button>
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
