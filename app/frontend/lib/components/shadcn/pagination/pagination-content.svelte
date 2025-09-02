<script>
	import { cn } from "$lib/utils.js";

	let {
		ref = $bindable(null),
		class: className,
		children,
		...restProps
	} = $props();
</script>

<ul
	bind:this={ref}
	data-slot="pagination-content"
	class={cn("flex flex-row items-center gap-1", className)}
	{...restProps}
>
	{@render children?.()}
</ul>