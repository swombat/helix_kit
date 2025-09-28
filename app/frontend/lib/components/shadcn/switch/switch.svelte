<script>
  import { cn } from '$lib/utils.js';

  let {
    checked = false,
    onCheckedChange = () => {},
    disabled = false,
    id = '',
    class: className = '',
    ...restProps
  } = $props();

  function handleClick() {
    if (disabled) return;
    onCheckedChange(!checked);
  }

  function handleInputChange(event) {
    if (disabled) return;
    onCheckedChange(event.target.checked);
  }
</script>

<button
  role="switch"
  type="button"
  aria-checked={checked}
  aria-describedby={id ? `${id}-description` : undefined}
  data-state={checked ? 'checked' : 'unchecked'}
  {disabled}
  onclick={handleClick}
  class={cn(
    'peer inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:cursor-not-allowed disabled:opacity-50',
    checked ? 'bg-primary' : 'bg-input',
    className
  )}
  {...restProps}>
  <span
    data-state={checked ? 'checked' : 'unchecked'}
    class={cn(
      'pointer-events-none block h-5 w-5 rounded-full bg-background shadow-lg ring-0 transition-transform',
      checked ? 'translate-x-5' : 'translate-x-0'
    )}></span>
</button>

<input type="checkbox" {id} {checked} onchange={handleInputChange} {disabled} class="sr-only" aria-hidden="true" />
