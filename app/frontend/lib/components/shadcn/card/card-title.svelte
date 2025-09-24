<script>
  import { cn } from '$lib/utils.js';

  let { ref = $bindable(null), class: className, level = 3, children, ...restProps } = $props();
</script>

<h3 bind:this={ref} class={cn('font-semibold leading-none tracking-tight', className)} {...restProps}>
  {@render children?.()}
</h3>
