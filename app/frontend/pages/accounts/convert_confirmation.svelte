<script>
  import { page, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import Alert from '$lib/components/Alert.svelte';
  import InfoCard from '$lib/components/InfoCard.svelte';
  import { ArrowLeft, UserCircle, Users, CheckCircle, UserSwitch } from 'phosphor-svelte';
  import { accountPath } from '@/routes';

  const { account, can_be_personal, members_count } = $page.props;

  let isConverting = $state(false);
  let teamName = $state('');
  let teamNameError = $state('');

  function validateTeamName() {
    if (!teamName.trim()) {
      teamNameError = 'Team name is required';
      return false;
    }
    if (teamName.trim().length < 2) {
      teamNameError = 'Team name must be at least 2 characters';
      return false;
    }
    teamNameError = '';
    return true;
  }

  function handleConversion() {
    if (account.personal) {
      // Converting to team - validate name first
      if (!validateTeamName()) {
        return;
      }

      isConverting = true;
      router.patch(
        `/accounts/${account.id}`,
        {
          convert_to: 'team',
          account: { name: teamName.trim() },
        },
        {
          onFinish: () => {
            isConverting = false;
          },
        }
      );
    } else {
      // Converting to personal
      isConverting = true;
      router.patch(
        `/accounts/${account.id}`,
        {
          convert_to: 'personal',
        },
        {
          onFinish: () => {
            isConverting = false;
          },
        }
      );
    }
  }

  function goBack() {
    router.visit(accountPath(account.id));
  }

  // Clear error when typing
  $effect(() => {
    if (teamName) {
      teamNameError = '';
    }
  });
</script>

<div class="container mx-auto p-8 max-w-4xl">
  <div class="mb-8">
    <Button variant="ghost" onclick={goBack} class="gap-2 mb-4">
      <ArrowLeft class="h-4 w-4" />
      Back to Account
    </Button>

    <h1 class="text-3xl font-bold mb-2">Account Type Conversion</h1>
    <p class="text-muted-foreground">
      {#if account.personal}
        Convert your personal account to a team account
      {:else}
        Convert your team account to a personal account
      {/if}
    </p>
  </div>

  {#if account.personal}
    <!-- Converting Personal to Team -->
    <InfoCard title="Convert to Team Account" icon="Users">
      <div class="space-y-6">
        <div class="space-y-4">
          <h3 class="font-semibold text-neutral-400 dark:text-neutral-600 text-lg">
            What happens when you convert to a team account:
          </h3>

          <div class="space-y-3">
            <div class="flex gap-3">
              <CheckCircle class="h-5 w-5 text-green-500 mt-0.5 flex-shrink-0" />
              <div>
                <p class="font-medium">Invite team members</p>
                <p class="text-sm text-muted-foreground">
                  You'll be able to invite other users to collaborate on your account
                </p>
              </div>
            </div>

            <div class="flex gap-3">
              <CheckCircle class="h-5 w-5 text-green-500 mt-0.5 flex-shrink-0" />
              <div>
                <p class="font-medium">Assign roles</p>
                <p class="text-sm text-muted-foreground">Control access with owner, admin, and member roles</p>
              </div>
            </div>

            <div class="flex gap-3">
              <CheckCircle class="h-5 w-5 text-green-500 mt-0.5 flex-shrink-0" />
              <div>
                <p class="font-medium">Choose a team name</p>
                <p class="text-sm text-muted-foreground">
                  Your account will have a custom name instead of "Personal Account"
                </p>
              </div>
            </div>
          </div>
        </div>

        <Alert type="notice" title="Important Information">
          <ul class="list-disc list-inside space-y-1 text-sm">
            <li>You can convert back to a personal account only when you're the sole member</li>
            <li>All existing data and settings will be preserved</li>
            <li>You'll become the owner of the team account</li>
          </ul>
        </Alert>

        <div class="space-y-4 mt-6">
          <div class="space-y-2">
            <Label for="team-name">Team Name <span class="text-destructive">*</span></Label>
            <Input
              id="team-name"
              type="text"
              bind:value={teamName}
              placeholder="Enter your team name"
              class={teamNameError ? 'border-destructive' : ''}
              disabled={isConverting}
              onkeydown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  handleConversion();
                }
              }} />
            {#if teamNameError}
              <p class="text-sm text-destructive">{teamNameError}</p>
            {/if}
          </div>

          <div class="flex gap-3 mt-6">
            <Button onclick={handleConversion} disabled={isConverting || !teamName.trim()} class="gap-2">
              <Users class="h-4 w-4" />
              {isConverting ? 'Converting...' : 'Convert to Team Account'}
            </Button>
            <Button variant="outline" onclick={goBack}>Cancel</Button>
          </div>
        </div>
      </div>
    </InfoCard>
  {:else}
    <!-- Converting Team to Personal -->
    <InfoCard title="Convert to Personal Account" icon="UserCircle">
      {#if can_be_personal}
        <div class="space-y-6">
          <div class="space-y-4">
            <h3 class="font-semibold text-neutral-400 dark:text-neutral-600 text-lg">
              What happens when you convert to a personal account:
            </h3>

            <div class="space-y-3">
              <div class="flex gap-3">
                <CheckCircle class="h-5 w-5 text-green-500 mt-0.5 flex-shrink-0" />
                <div>
                  <p class="font-medium">Single user only</p>
                  <p class="text-sm text-muted-foreground">The account will be limited to just you</p>
                </div>
              </div>

              <div class="flex gap-3">
                <CheckCircle class="h-5 w-5 text-green-500 mt-0.5 flex-shrink-0" />
                <div>
                  <p class="font-medium">No team management</p>
                  <p class="text-sm text-muted-foreground">Team features like invitations and roles will be disabled</p>
                </div>
              </div>

              <div class="flex gap-3">
                <CheckCircle class="h-5 w-5 text-green-500 mt-0.5 flex-shrink-0" />
                <div>
                  <p class="font-medium">Account name changes</p>
                  <p class="text-sm text-muted-foreground">The account will be renamed to "Personal Account"</p>
                </div>
              </div>
            </div>
          </div>

          <Alert type="notice" title="Important Information">
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li>You can convert back to a team account at any time</li>
              <li>All existing data will be preserved</li>
              <li>This action is reversible</li>
            </ul>
          </Alert>

          <div class="flex gap-3 mt-6">
            <Button onclick={handleConversion} disabled={isConverting} class="gap-2">
              <UserCircle class="h-4 w-4" />
              {isConverting ? 'Converting...' : 'Convert to Personal Account'}
            </Button>
            <Button variant="outline" onclick={goBack}>Cancel</Button>
          </div>
        </div>
      {:else}
        <Alert type="error" title="Cannot Convert to Personal Account">
          <div class="space-y-3 mt-2">
            <p>
              This team account cannot be converted to a personal account because it has <strong
                >{members_count} members</strong
              >.
            </p>
            <p>Personal accounts can only have one user. To convert this account:</p>
            <ol class="list-decimal list-inside space-y-1 ml-2">
              <li>Remove all other team members</li>
              <li>Ensure you're the only remaining member</li>
              <li>Then try converting again</li>
            </ol>
          </div>
        </Alert>

        <div class="flex gap-3 mt-6">
          <Button variant="outline" onclick={goBack}>Go Back</Button>
        </div>
      {/if}
    </InfoCard>
  {/if}
</div>
