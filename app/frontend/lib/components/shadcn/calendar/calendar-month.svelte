<script>
	import { cn } from "$lib/utils.js";
	let {
		ref = $bindable(null),
		class: className,
		children,
		...restProps
	} = $props();
</script>

<div {...restProps} bind:this={ref} class={cn("flex flex-col", className)}>
	{@render children?.()}
</div>