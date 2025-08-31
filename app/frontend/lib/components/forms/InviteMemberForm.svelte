<script>
  import { createEventDispatcher } from 'svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Select, SelectContent, SelectItem, SelectTrigger } from '$lib/components/shadcn/select';
  import { X, UserPlus } from 'phosphor-svelte';

  const dispatch = createEventDispatcher();

  let email = $state('');
  let role = $state('member');
  let isSubmitting = $state(false);

  function handleSubmit(e) {
    e.preventDefault();
    if (!email) return;

    isSubmitting = true;

    dispatch('invite', { email, role });

    // Reset form
    email = '';
    role = 'member';
    isSubmitting = false;
  }

  function handleClose() {
    dispatch('close');
  }

  function getRoleDescription(roleValue) {
    switch (roleValue) {
      case 'owner':
        return 'Full access to account settings and billing';
      case 'admin':
        return 'Can manage team members and most settings';
      case 'member':
        return 'Basic access to account resources';
      default:
        return '';
    }
  }
</script>

<Card class="mb-8">
  <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
    <CardTitle class="text-lg flex items-center gap-2">
      <UserPlus class="h-5 w-5" />
      Invite Team Member
    </CardTitle>
    <Button variant="ghost" size="sm" onclick={handleClose}>
      <X class="h-4 w-4" />
    </Button>
  </CardHeader>
  <CardContent>
    <form onsubmit={handleSubmit} class="space-y-4">
      <div class="space-y-2">
        <Label for="email">Email Address</Label>
        <Input
          id="email"
          type="email"
          bind:value={email}
          placeholder="colleague@example.com"
          required
          disabled={isSubmitting} />
      </div>

      <div class="space-y-2">
        <Label for="role">Role</Label>
        <Select bind:value={role} disabled={isSubmitting}>
          <SelectTrigger>
            {role || 'Select a role'}
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="member">Member</SelectItem>
            <SelectItem value="admin">Admin</SelectItem>
            <SelectItem value="owner">Owner</SelectItem>
          </SelectContent>
        </Select>
        <p class="text-sm text-muted-foreground">
          {getRoleDescription(role)}
        </p>
      </div>

      <div class="flex justify-end space-x-3 pt-4">
        <Button type="button" variant="outline" onclick={handleClose} disabled={isSubmitting}>Cancel</Button>
        <Button type="submit" disabled={isSubmitting || !email}>
          {isSubmitting ? 'Sending...' : 'Send Invitation'}
        </Button>
      </div>
    </form>
  </CardContent>
</Card>
