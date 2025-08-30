<script>
  import { router } from '@inertiajs/svelte';
  import { setPasswordPath } from '@/routes';

  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input/index.js';
  import { Label } from '$lib/components/shadcn/label/index.js';

  let { user, processing = $bindable(false), onSuccess } = $props();

  let user_form = $state({
    ...user,
    password: '',
    password_confirmation: '',
  });

  function handleSubmit(e) {
    e.preventDefault();
    processing = true;

    router.patch(setPasswordPath(), user_form, {
      preserveState: false,
      onFinish: () => {
        processing = false;
      },
      onSuccess: () => {
        if (onSuccess) onSuccess();
      },
    });
  }

  // Password strength indicator
  let passwordStrength = $derived.by(() => {
    if (!user_form.password) return { score: 0, text: '', color: '' };

    let score = 0;
    const password = user_form.password;

    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 14) score++;
    if (password.length >= 16) score++;
    if (password.length >= 18) score++;
    if (password.length >= 20) score++;

    // Character variety
    if (/[a-z]/.test(password)) score++;
    if (/[A-Z]/.test(password)) score++;
    if (/[0-9]/.test(password)) score++;
    if (/[^a-zA-Z0-9]/.test(password)) score++;

    if (password.length < 8) score = 1;
    if (password.length < 12) score = 2; // Cap score for short passwords

    const strength = Math.min(Math.floor((score / 6) * 4), 4);
    const levels = [
      { score: 0, text: '', color: '' },
      { score: 1, text: 'Weak', color: 'text-red-500' },
      { score: 4, text: 'Fair', color: 'text-orange-500' },
      { score: 5, text: 'Good', color: 'text-yellow-500' },
      { score: 6, text: 'Strong', color: 'text-green-500' },
    ];

    return levels[strength];
  });
</script>

<form onsubmit={handleSubmit}>
  <div class="grid gap-4">
    <div class="grid gap-2">
      <Label for="email">Email</Label>
      <Input id="email" type="email" autocomplete="email" disabled value={user_form.email_address} />
    </div>

    <div>
      <Label for="first_name">First Name</Label>
      <Input
        type="text"
        id="first_name"
        required
        bind:value={user_form.first_name}
        placeholder="Enter your first name" />
    </div>

    <div>
      <Label for="last_name">Last Name</Label>
      <Input type="text" id="last_name" required bind:value={user_form.last_name} placeholder="Enter your last name" />
    </div>

    <div class="grid gap-2">
      <Label for="password">Password</Label>
      <Input
        id="password"
        type="password"
        autocomplete="new-password"
        required
        bind:value={user_form.password}
        disabled={processing}
        placeholder="Enter a secure password" />
      {#if passwordStrength.text}
        <p class="text-xs {passwordStrength.color}">
          Password strength: {passwordStrength.text}
        </p>
      {/if}
    </div>
    <div class="grid gap-2">
      <Label for="password_confirmation">Confirm Password</Label>
      <Input
        id="password_confirmation"
        type="password"
        autocomplete="new-password"
        required
        bind:value={user_form.password_confirmation}
        disabled={processing}
        placeholder="Re-enter your password" />
    </div>

    <div class="rounded-lg bg-muted p-3">
      <p class="text-xs text-muted-foreground font-medium mb-2">Password requirements:</p>
      <ul class="space-y-1 text-xs text-muted-foreground">
        <li class={user_form.password && user_form.password.length >= 6 ? 'text-green-600' : ''}>
          {#if user_form.password && user_form.password.length >= 6}✓{:else}•{/if} At least 6 characters
        </li>
        <li class={user_form.password && user_form.password.length <= 72 ? 'text-green-600' : ''}>
          {#if user_form.password && user_form.password.length <= 72}✓{:else}•{/if} Maximum 72 characters
        </li>
      </ul>
    </div>

    <Button type="submit" class="w-full" disabled={processing}>
      {processing ? 'Setting up...' : 'Complete Setup'}
    </Button>
  </div>
</form>
