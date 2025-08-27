<script>
  import { page } from '@inertiajs/svelte'
  import { Toaster } from "$lib/components/ui/sonner/index.js";
  import { toast } from "svelte-sonner";
  import Navbar from "$lib/components/navbar.svelte"; // Adjust the path as necessary

  let { children } = $props();

  $effect(() => {
    let flash = $page.props?.flash || {}
    
    flash.notice && toast.success(flash.notice)
    flash.alert && toast.error(flash.alert)
  })
</script>

<div class="bg-bg">
  <Navbar />
  <main>{@render children()}</main>
  <Toaster />
</div>