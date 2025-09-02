<script>
	let {
		ref = $bindable(null),
		children,
		...restProps
	} = $props();
</script>

<li bind:this={ref} data-slot="pagination-item" {...restProps}>
	{@render children?.()}
</li>