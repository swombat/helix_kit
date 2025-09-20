<script>
  import { page } from '@inertiajs/svelte';
  import { Toaster } from '$lib/components/shadcn/sonner/index.js';
  import { toast } from 'svelte-sonner';
  import Navbar from '$lib/components/navigation/navbar.svelte'; // Adjust the path as necessary
  import { ModeWatcher, setMode, resetMode, mode } from 'mode-watcher';

  let { children } = $props();
  let themeInitialized = false;

  $effect(() => {
    let flash = $page.props?.flash || {};

    flash.notice && toast.success(flash.notice);
    flash.alert && toast.error(flash.alert);
  });

  // Apply user's theme preference on initial load only
  $effect(() => {
    if (!themeInitialized) {
      const userTheme = $page.props?.user?.preferences?.theme || $page.props?.theme_preference;
      if (userTheme && userTheme !== 'system') {
        setMode(userTheme);
      } else if (userTheme === 'system') {
        resetMode();
      }
      themeInitialized = true;
    }
  });
</script>

<ModeWatcher />
<div class="bg-bg">
  <Navbar />
  <main>{@render children?.()}</main>
  <Toaster />
</div>
