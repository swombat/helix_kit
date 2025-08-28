<script>
  export let Component;
  export let props = {};
  export let childContent = '';
</script>

<Component {...props}>
  {#if childContent}
    {childContent}
  {/if}
</Component>