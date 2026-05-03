<script>
  import * as Select from '$lib/components/shadcn/select/index.js';
  import { findModelLabel } from '$lib/agent-models';

  let {
    groupedModels = {},
    value = $bindable(),
    triggerClass = 'w-full max-w-md',
    contentClass = 'max-h-80',
  } = $props();
</script>

<Select.Root
  type="single"
  {value}
  onValueChange={(nextValue) => {
    value = nextValue;
  }}>
  <Select.Trigger class={triggerClass}>
    {findModelLabel(groupedModels, value)}
  </Select.Trigger>
  <Select.Content sideOffset={4} class={contentClass}>
    {#each Object.entries(groupedModels) as [groupName, models]}
      <Select.Group>
        <Select.GroupHeading class="px-2 py-1.5 text-xs font-semibold text-muted-foreground">
          {groupName}
        </Select.GroupHeading>
        {#each models as model (model.model_id)}
          <Select.Item value={model.model_id} label={model.label}>{model.label}</Select.Item>
        {/each}
      </Select.Group>
    {/each}
  </Select.Content>
</Select.Root>
