<script>
  import { Globe, UsersThree } from 'phosphor-svelte';

  let { agents = [], webAccess = $bindable(false), isGroupChat = false, onGroupChatToggle } = $props();
</script>

<div class="border-b border-border px-4 md:px-6 py-2 bg-muted/10 flex flex-wrap items-center gap-3 md:gap-6">
  <label class="flex items-center gap-2 cursor-pointer hover:opacity-80 transition-opacity w-fit">
    <input
      type="checkbox"
      bind:checked={webAccess}
      class="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
    <Globe size={16} class="text-muted-foreground" weight="duotone" />
    <span class="text-sm text-muted-foreground">Allow web access</span>
  </label>

  {#if agents.length > 0}
    <label class="flex items-center gap-2 cursor-pointer hover:opacity-80 transition-opacity w-fit">
      <input
        type="checkbox"
        checked={isGroupChat}
        onchange={onGroupChatToggle}
        class="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
      <UsersThree size={16} class="text-muted-foreground" weight="duotone" />
      <span class="text-sm text-muted-foreground">Group chat with agents</span>
    </label>
  {/if}
</div>
