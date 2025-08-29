<script>
  import { Button } from '$lib/components/ui/button/index.js';
  import { useForm } from '@inertiajs/svelte';
  import { signupPath } from '@/routes'; // Using signup path for resending since there's no specific resend route yet
  import { ArrowClockwise } from 'phosphor-svelte';

  let { email } = $props();
  let cooldown = $state(0);

  const form = useForm({
    email_address: email,
  });

  function resend() {
    $form.post(signupPath(), {
      onSuccess: () => {
        startCooldown();
      },
    });
  }

  function startCooldown() {
    cooldown = 60;
    const interval = setInterval(() => {
      cooldown--;
      if (cooldown <= 0) {
        clearInterval(interval);
      }
    }, 1000);
  }
</script>

<Button variant="outline" onclick={resend} disabled={$form.processing || cooldown > 0} class="w-full">
  <ArrowClockwise class="mr-2 size-4" />
  {#if cooldown > 0}
    Resend in {cooldown}s
  {:else if $form.processing}
    Sending...
  {:else}
    Resend confirmation email
  {/if}
</Button>
