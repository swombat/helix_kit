<script>
	import { RangeCalendar as RangeCalendarPrimitive } from "bits-ui";
	import { cn } from "$lib/utils.js";

	let {
		ref = $bindable(null),
		class: className,
		...restProps
	} = $props();
</script>

<RangeCalendarPrimitive.Heading
	bind:ref
	class={cn("px-(--cell-size) text-sm font-medium", className)}
	{...restProps}
/>