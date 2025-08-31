<script>
  import { badgeVariants } from './index.js';
  import { cn } from '$lib/utils.js';

  let { class: className, variant = 'default', ...restProps } = $props();
</script>

<span class={cn(badgeVariants({ variant }), className)} {...restProps}>
  <slot />
</span>
