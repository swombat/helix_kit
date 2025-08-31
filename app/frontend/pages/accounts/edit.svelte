<script>
  import { page, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Badge } from '$lib/components/shadcn/badge';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';
  import { accountPath } from '@/routes';
  import { UserCircle, Users, Warning, ArrowLeft, Check } from 'phosphor-svelte';

  const { account, can_be_personal } = $page.props;

  // State for conversion
  let showTeamConversion = $state(false);
  let showPersonalConversion = $state(false);
  let teamName = $state(account.name || '');
  let isSubmitting = $state(false);

  function goBack() {
    router.visit(accountPath(account.id));
  }

  function showTeamConversionDialog() {
    teamName = ''; // Reset team name
    showTeamConversion = true;
  }

  function showPersonalConversionDialog() {
    showPersonalConversion = true;
  }

  function cancelConversion() {
    showTeamConversion = false;
    showPersonalConversion = false;
    teamName = account.name || '';
  }

  async function convertToTeam() {
    if (!teamName.trim()) {
      return;
    }

    isSubmitting = true;
    try {
      router.put(accountPath(account.id), {
        convert_to: 'team',
        account: { name: teamName.trim() },
      });
    } catch (error) {
      isSubmitting = false;
    }
  }

  async function convertToPersonal() {
    isSubmitting = true;
    try {
      router.put(accountPath(account.id), {
        convert_to: 'personal',
      });
    } catch (error) {
      isSubmitting = false;
    }
  }
</script>

<div class="container mx-auto p-8 max-w-4xl">
  <!-- Header -->
  <div class="mb-8">
    <div class="flex items-center gap-4 mb-4">
      <Button variant="ghost" onclick={goBack} class="gap-2">
        <ArrowLeft class="h-4 w-4" />
        Back to Account
      </Button>
    </div>
    <h1 class="text-3xl font-bold mb-2">Edit Account Settings</h1>
    <p class="text-muted-foreground">Change your account type and manage settings</p>
  </div>

  <!-- Current Account Info -->
  <Card class="mb-8">
    <CardHeader>
      <CardTitle class="flex items-center gap-2">
        <UserCircle class="h-5 w-5" />
        Current Account
      </CardTitle>
    </CardHeader>
    <CardContent>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-4">
          <div>
            <h3 class="font-semibold">
              {account.personal ? 'Personal Account' : account.name}
            </h3>
            <div class="flex items-center gap-2 mt-1">
              <Badge variant={account.personal ? 'default' : 'secondary'}>
                {account.personal ? 'Personal' : 'Team'}
              </Badge>
              <span class="text-sm text-muted-foreground">
                {account.users?.length || account.users_count || 0}
                {account.users?.length === 1 || account.users_count === 1 ? 'user' : 'users'}
              </span>
            </div>
          </div>
        </div>
      </div>
    </CardContent>
  </Card>

  <!-- Conversion Options -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Convert to Team -->
    {#if account.personal}
      <Card>
        <CardHeader>
          <CardTitle class="flex items-center gap-2">
            <Users class="h-5 w-5" />
            Convert to Team Account
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div class="space-y-4">
            <p class="text-sm text-muted-foreground">
              Convert your personal account to a team account to collaborate with others. You'll be able to invite team
              members and share resources.
            </p>
            <div class="flex flex-col gap-2">
              <h4 class="text-sm font-medium">Benefits of Team Accounts:</h4>
              <ul class="text-sm text-muted-foreground space-y-1">
                <li>• Invite team members</li>
                <li>• Shared resources and collaboration</li>
                <li>• Team-wide settings and preferences</li>
              </ul>
            </div>
            <Button onclick={showTeamConversionDialog} class="w-full" variant="outline">Convert to Team Account</Button>
          </div>
        </CardContent>
      </Card>
    {/if}

    <!-- Convert to Personal -->
    {#if !account.personal && can_be_personal}
      <Card>
        <CardHeader>
          <CardTitle class="flex items-center gap-2">
            <UserCircle class="h-5 w-5" />
            Convert to Personal Account
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div class="space-y-4">
            <p class="text-sm text-muted-foreground">
              Convert your team account back to a personal account. This is only possible when you're the only member of
              the team.
            </p>
            <div class="flex flex-col gap-2">
              <h4 class="text-sm font-medium">This will:</h4>
              <ul class="text-sm text-muted-foreground space-y-1">
                <li>• Change account type to personal</li>
                <li>• Simplify account management</li>
                <li>• Remove team-specific features</li>
              </ul>
            </div>
            <Button onclick={showPersonalConversionDialog} class="w-full" variant="outline">
              Convert to Personal Account
            </Button>
          </div>
        </CardContent>
      </Card>
    {:else if !account.personal && !can_be_personal}
      <Card>
        <CardHeader>
          <CardTitle class="flex items-center gap-2">
            <Warning class="h-5 w-5 text-amber-500" />
            Cannot Convert to Personal
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div class="space-y-4">
            <p class="text-sm text-muted-foreground">
              Team accounts with multiple users cannot be converted to personal accounts. You would need to remove all
              other team members first.
            </p>
            <div class="p-3 bg-amber-50 dark:bg-amber-950/20 rounded-md border border-amber-200 dark:border-amber-800">
              <p class="text-sm text-amber-800 dark:text-amber-200">
                <strong>Current team size:</strong>
                {account.users?.length || account.users_count || 0} users
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    {/if}
  </div>
</div>

<!-- Team Conversion Modal -->
{#if showTeamConversion}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
    <div class="bg-background border rounded-lg shadow-lg max-w-md w-full">
      <div class="p-6">
        <h2 class="text-lg font-semibold mb-4">Convert to Team Account</h2>
        <p class="text-sm text-muted-foreground mb-4">
          Choose a name for your team account. You can change this later.
        </p>

        <div class="space-y-4">
          <div>
            <Label for="team-name">Team Name</Label>
            <Input id="team-name" bind:value={teamName} placeholder="Enter team name" class="mt-1" />
          </div>
        </div>

        <div class="flex gap-2 mt-6">
          <Button onclick={cancelConversion} variant="outline" class="flex-1" disabled={isSubmitting}>Cancel</Button>
          <Button onclick={convertToTeam} class="flex-1 gap-2" disabled={!teamName.trim() || isSubmitting}>
            {#if isSubmitting}
              <div class="animate-spin h-4 w-4 border-2 border-current border-t-transparent rounded-full"></div>
            {:else}
              <Check class="h-4 w-4" />
            {/if}
            Convert
          </Button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- Personal Conversion Modal -->
{#if showPersonalConversion}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
    <div class="bg-background border rounded-lg shadow-lg max-w-md w-full">
      <div class="p-6">
        <h2 class="text-lg font-semibold mb-4">Convert to Personal Account</h2>
        <p class="text-sm text-muted-foreground mb-4">
          Are you sure you want to convert this team account to a personal account? This action will remove
          team-specific features.
        </p>

        <div class="bg-blue-50 dark:bg-blue-950/20 p-3 rounded-md border border-blue-200 dark:border-blue-800 mb-4">
          <p class="text-sm text-blue-800 dark:text-blue-200">
            <strong>Note:</strong> You can always convert back to a team account later.
          </p>
        </div>

        <div class="flex gap-2 mt-6">
          <Button onclick={cancelConversion} variant="outline" class="flex-1" disabled={isSubmitting}>Cancel</Button>
          <Button onclick={convertToPersonal} class="flex-1 gap-2" disabled={isSubmitting}>
            {#if isSubmitting}
              <div class="animate-spin h-4 w-4 border-2 border-current border-t-transparent rounded-full"></div>
            {:else}
              <Check class="h-4 w-4" />
            {/if}
            Convert
          </Button>
        </div>
      </div>
    </div>
  </div>
{/if}
