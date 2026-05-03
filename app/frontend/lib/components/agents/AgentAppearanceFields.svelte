<script>
  import ColourPicker from '$lib/components/ColourPicker.svelte';
  import IconPicker from '$lib/components/IconPicker.svelte';

  let {
    colour = $bindable(null),
    icon = $bindable(null),
    colourOptions = [],
    iconOptions = [],
    colourLabel = 'Chat Bubble Colour',
    iconLabel = 'Agent Icon',
  } = $props();
</script>

<ColourPicker bind:value={colour} options={colourOptions} label={colourLabel} />
<IconPicker bind:value={icon} options={iconOptions} {colour} label={iconLabel} />
