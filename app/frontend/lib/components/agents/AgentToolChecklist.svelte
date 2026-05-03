<script>
  let { tools = [], enabledTools = $bindable([]), compact = false } = $props();

  function toggleTool(toolClassName) {
    const nextTools = [...enabledTools];
    const index = nextTools.indexOf(toolClassName);

    if (index === -1) {
      nextTools.push(toolClassName);
    } else {
      nextTools.splice(index, 1);
    }

    enabledTools = nextTools;
  }
</script>

{#if tools.length === 0}
  <p class="text-sm text-muted-foreground">
    No tools are currently available. Tools will appear here as they are added to the system.
  </p>
{:else}
  <div class={compact ? 'space-y-3 max-h-48 overflow-y-auto border rounded-md p-3' : 'space-y-4'}>
    {#each tools as tool (tool.class_name)}
      <label class="flex items-start gap-3 cursor-pointer group">
        <input
          type="checkbox"
          checked={enabledTools.includes(tool.class_name)}
          onchange={() => toggleTool(tool.class_name)}
          class="mt-1 w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
        <div class={compact ? 'space-y-0.5' : 'space-y-1'}>
          <div class="{compact ? 'text-sm ' : ''}font-medium group-hover:text-primary transition-colors">
            {tool.name}
          </div>
          {#if tool.description}
            <p class="{compact ? 'text-xs' : 'text-sm'} text-muted-foreground">{tool.description}</p>
          {/if}
        </div>
      </label>
    {/each}
  </div>
{/if}
