<script>
  import { Avatar as AvatarPrimitive } from 'bits-ui';
  import { cn } from '$lib/utils.js';

  let { ref = $bindable(null), class: className, children, ...restProps } = $props();
</script>

<AvatarPrimitive.Root
  bind:ref
  class={cn('relative flex h-10 w-10 shrink-0 overflow-hidden rounded-full', className)}
  {...restProps}>
  {#if children}
    {@render children()}
  {/if}
</AvatarPrimitive.Root>
