<script>
  import { page } from '@inertiajs/svelte'
  import { Toaster } from "$lib/components/shadcn/sonner/index.js";
  import { toast } from "svelte-sonner";
  import Navbar from "$lib/components/navigation/navbar.svelte"; // Adjust the path as necessary
  import { ModeWatcher } from 'mode-watcher';

  let { children } = $props();

  $effect(() => {
    let flash = $page.props?.flash || {}
    
    flash.notice && toast.success(flash.notice)
    flash.alert && toast.error(flash.alert)
  })
</script>

<ModeWatcher />
<div class="bg-bg">
  <Navbar />
  <main>{@render children?.()}</main>
  <Toaster />
</div>