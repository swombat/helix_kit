<script>
	import { cn } from "$lib/utils.js";
	import {} from "bits-ui";
	let { ref = $bindable(null), class: className, inset, children, ...restProps } = $props();
</script>

<div
	bind:this={ref}
	class={cn("px-2 py-1.5 text-sm font-semibold", inset && "pl-8", className)}
	{...restProps}
>
	{@render children?.()}
</div>
