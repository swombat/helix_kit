<script>
  import Button from '$lib/components/ui/button/button.svelte';
  let { text = 'Click me', ...props } = $props();
</script>

<Button {...props}>
  {text}
</Button>