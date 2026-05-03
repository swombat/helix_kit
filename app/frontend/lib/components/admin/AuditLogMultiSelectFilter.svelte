<script>
  import * as Select from '$lib/components/shadcn/select/index.js';

  let { value = $bindable(), items = [], placeholder = 'All' } = $props();

  const selectedItems = $derived(items.filter((item) => value?.includes(item.value)));
</script>

<Select.Root
  type="multiple"
  {value}
  onValueChange={(nextValue) => {
    value = nextValue;
  }}>
  <Select.Trigger class="w-full">
    <span class="truncate text-clip">
      {#if selectedItems.length > 0}
        {#each selectedItems as item}
          <span class="text-xs mx-1 border-1 px-1 py-0.5 rounded-md bg-accent">
            {item.selectedLabel || item.label}
          </span>
        {/each}
      {:else}
        {placeholder}
      {/if}
    </span>
  </Select.Trigger>
  <Select.Content>
    {#each items as item}
      <Select.Item value={item.value}>{item.label}</Select.Item>
    {/each}
  </Select.Content>
</Select.Root>
