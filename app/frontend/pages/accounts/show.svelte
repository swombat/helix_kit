<script>
  import { page, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { editAccountPath } from '@/routes';
  import { Gear } from 'phosphor-svelte';
  import AccountSummaryCards from '$lib/components/accounts/AccountSummaryCards.svelte';
  import AccountTypeCard from '$lib/components/accounts/AccountTypeCard.svelte';
  import PendingInvitationsCard from '$lib/components/accounts/PendingInvitationsCard.svelte';
  import TeamMembersCard from '$lib/components/accounts/TeamMembersCard.svelte';
  import FlashMessages from '$lib/components/FlashMessages.svelte';
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

  <FlashMessages flash={$page.props.flash} />

  <AccountSummaryCards {account} activeMemberCount={activeMembers.length || 0} {formatDate} />

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

  <AccountTypeCard {account} canBePersonal={can_be_personal} onConvert={goToConvertConfirmation} />
</div>
