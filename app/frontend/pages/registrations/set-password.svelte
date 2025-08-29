<script>
  import { Button } from "$lib/components/ui/button/index.js";
  import * as Card from "$lib/components/ui/card/index.js";
  import { Input } from "$lib/components/ui/input/index.js";
  import { InputError } from "$lib/components/ui/input-error/index.js";
  import { Label } from "$lib/components/ui/label/index.js";
  import { Link, useForm } from "@inertiajs/svelte";
  import Logo from "$lib/components/logo.svelte";
  import AuthLayout from "../../layouts/auth-layout.svelte";
  import { setPasswordPath } from "@/routes";
  import { CheckCircle } from "phosphor-svelte";
  
  let { email } = $props();

  const form = useForm({
    password: null,
    password_confirmation: null,
  });

  function submit(e) {
    e.preventDefault();
    $form.patch(setPasswordPath());
  }
  
  // Password strength indicator
  let passwordStrength = $derived.by(() => {
    if (!$form.password) return { score: 0, text: "", color: "" };
    
    let score = 0;
    const password = $form.password;
    
    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    
    // Character variety
    if (/[a-z]/.test(password)) score++;
    if (/[A-Z]/.test(password)) score++;
    if (/[0-9]/.test(password)) score++;
    if (/[^a-zA-Z0-9]/.test(password)) score++;
    
    const strength = Math.min(Math.floor((score / 6) * 4), 4);
    const levels = [
      { score: 0, text: "", color: "" },
      { score: 1, text: "Weak", color: "text-red-500" },
      { score: 2, text: "Fair", color: "text-orange-500" },
      { score: 3, text: "Good", color: "text-yellow-500" },
      { score: 4, text: "Strong", color: "text-green-500" }
    ];
    
    return levels[strength];
  });
</script>

<AuthLayout>
  <div class="flex flex-col h-screen w-full items-center justify-center px-4">
    <Link href="/" class="mb-8">
      <Logo class="h-8 w-48" />
    </Link>
    
    <Card.Root class="mx-auto max-w-sm w-full">
      <Card.Header>
        <div class="flex justify-center mb-4">
          <div class="rounded-full bg-green-100 p-3">
            <CheckCircle size={24} class="text-green-600" />
          </div>
        </div>
        <Card.Title class="text-2xl text-center">Email Confirmed!</Card.Title>
        <Card.Description class="text-center">
          Now let's secure your account with a password.
        </Card.Description>
        {#if email}
          <p class="text-sm text-muted-foreground text-center mt-2">
            Account: <strong>{email}</strong>
          </p>
        {/if}
      </Card.Header>
      <Card.Content>
        <form onsubmit={submit}>
          <div class="grid gap-4">
            <div class="grid gap-2">
              <Label for="password">Password</Label>
              <Input 
                id="password" 
                type="password" 
                required 
                bind:value={$form.password}
                disabled={$form.processing}
                placeholder="Enter a secure password"
              />
              {#if passwordStrength.text}
                <p class="text-xs {passwordStrength.color}">
                  Password strength: {passwordStrength.text}
                </p>
              {/if}
              <InputError errors={$form.errors.password} />
            </div>
            <div class="grid gap-2">
              <Label for="password_confirmation">Confirm Password</Label>
              <Input 
                id="password_confirmation" 
                type="password" 
                required 
                bind:value={$form.password_confirmation}
                disabled={$form.processing}
                placeholder="Re-enter your password"
              />
              <InputError errors={$form.errors.password_confirmation} />
            </div>
            
            <div class="rounded-lg bg-muted p-3">
              <p class="text-xs text-muted-foreground font-medium mb-2">Password requirements:</p>
              <ul class="space-y-1 text-xs text-muted-foreground">
                <li class={$form.password && $form.password.length >= 6 ? "text-green-600" : ""}>
                  {#if $form.password && $form.password.length >= 6}✓{:else}•{/if} At least 6 characters
                </li>
                <li class={$form.password && $form.password.length <= 72 ? "text-green-600" : ""}>
                  {#if $form.password && $form.password.length <= 72}✓{:else}•{/if} Maximum 72 characters
                </li>
              </ul>
            </div>
            
            <Button type="submit" class="w-full" disabled={$form.processing}>
              {$form.processing ? 'Setting up...' : 'Complete Setup'}
            </Button>
          </div>
        </form>
      </Card.Content>
    </Card.Root>
  </div>
</AuthLayout>