<script>
  import { page } from '@inertiajs/svelte';
  import { Toaster } from '$lib/components/shadcn/sonner/index.js';
  import { toast } from 'svelte-sonner';
  import Navbar from '$lib/components/navigation/Navbar.svelte'; // Adjust the path as necessary

  let { children } = $props();

  $effect(() => {
    let flash = $page.props?.flash || {};

    flash.notice && toast.success(flash.notice);
    flash.alert && toast.error(flash.alert);
  });
</script>

<div class="bg-bg">
  <main>{@render children?.()}</main>
  <Toaster />
</div>
