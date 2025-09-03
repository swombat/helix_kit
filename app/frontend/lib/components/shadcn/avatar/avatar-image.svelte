<script>
  import { Avatar as AvatarPrimitive } from 'bits-ui';
  import { cn } from '$lib/utils.js';

  let { ref = $bindable(null), class: className, ...restProps } = $props();
</script>

<AvatarPrimitive.Image bind:ref class={cn('aspect-square h-full w-full', className)} {...restProps} />
