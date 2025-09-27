<script>
  // shadcn components
  import * as Alert from '$lib/components/shadcn/alert/index.js';
  import { CheckCircle, Warning, WarningOctagon, ArrowCircleRight } from 'phosphor-svelte';
  import * as logging from '$lib/logging';

  let { type = $bindable(), title = $bindable(), description = $bindable(), children } = $props();

  function splitDescription(description) {
    if (description instanceof Array) {
      return (
        "<ul class='list-disc list-inside'>" + description.map((line) => '<li>' + line + '</li>').join('') + '</ul>'
      );
    }
    return description
      .toString()
      .split('\n')
      .map((line) => '<p>' + line + '</p>')
      .join('');
  }

  function getColor(type) {
    switch (type) {
      case 'success':
        return 'bg-green-50 text-green-700 border-green-500 dark:bg-green-950 dark:text-green-500 dark:border-green-500';
      case 'notice':
        return 'bg-blue-50 text-blue-700 border-blue-500 dark:bg-blue-950 dark:text-blue-500 dark:border-blue-500';
      case 'warning':
        return 'bg-yellow-50 text-yellow-700 border-yellow-500 dark:bg-yellow-950 dark:text-yellow-500 dark:border-yellow-500';
      case 'error':
        return 'bg-red-50 text-red-700 border-red-500 dark:bg-red-950 dark:text-red-500 dark:border-red-500';
    }
  }
</script>

<Alert.Root variant={type} class="{getColor(type)} my-2">
  {#if type == 'success'}
    <CheckCircle size={48} />
  {/if}
  {#if type == 'notice'}
    <ArrowCircleRight size={24} />
  {/if}
  {#if type == 'warning'}
    <Warning size={24} />
  {/if}
  {#if type == 'error'}
    <WarningOctagon size={24} />
  {/if}
  <Alert.Title>{title}</Alert.Title>
  <Alert.Description>
    {@render children?.()}
    {#if description}
      {@html splitDescription(description)}
    {/if}
  </Alert.Description>
</Alert.Root>
