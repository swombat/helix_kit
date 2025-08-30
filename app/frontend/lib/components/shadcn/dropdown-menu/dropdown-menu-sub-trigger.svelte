<script>
	import { DropdownMenu as DropdownMenuPrimitive } from "bits-ui";
	import { CaretRight } from "phosphor-svelte";
	import { cn } from "$lib/utils.js";

	let { ref = $bindable(null), class: className, inset, children, ...restProps } = $props();
</script>

<DropdownMenuPrimitive.SubTrigger
	bind:ref
	class={cn(
		"data-[highlighted]:bg-accent data-[state=open]:bg-accent flex cursor-default select-none items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
		inset && "pl-8",
		className
	)}
	{...restProps}
>
	{@render children?.()}
	<ChevronRight class="ml-auto" />
</DropdownMenuPrimitive.SubTrigger>
