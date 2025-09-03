<script>
  import { Avatar as AvatarPrimitive } from 'bits-ui';
  import { cn } from '$lib/utils.js';

  let { ref = $bindable(null), class: className, children, ...restProps } = $props();
</script>

<AvatarPrimitive.Fallback
  bind:ref
  class={cn('flex h-full w-full items-center justify-center rounded-full bg-muted', className)}
  {...restProps}>
  {#if children}
    {@render children()}
  {/if}
</AvatarPrimitive.Fallback>
