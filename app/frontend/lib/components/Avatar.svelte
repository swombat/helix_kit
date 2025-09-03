<script>
  import * as Avatar from '$lib/components/shadcn/avatar/index.js';

  let { user = null, size = 'default', class: className = '', onClick = null, ...restProps } = $props();

  const sizeClasses = {
    small: 'size-6 text-xs',
    default: 'size-10 text-sm',
    medium: 'size-12 text-base',
    large: 'size-16 text-lg',
    xl: 'size-20 text-2xl',
    xxl: 'size-24 text-3xl',
  };
</script>

{#if onClick}
  <button
    type="button"
    onclick={onClick}
    class="rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary"
    {...restProps}>
    <Avatar.Root class="{sizeClasses[size]} {className}">
      {#if user.avatar_url}
        <Avatar.Image src={user.avatar_url} alt="{user.full_name} avatar" />
      {/if}
      <Avatar.Fallback>
        <span class="font-semibold text-muted-foreground">{user.initials}</span>
      </Avatar.Fallback>
    </Avatar.Root>
  </button>
{:else}
  <Avatar.Root class="{sizeClasses[size]} {className}" {...restProps}>
    {#if user.avatar_url}
      <Avatar.Image src={user.avatar_url} alt="{user.full_name} avatar" />
    {/if}
    <Avatar.Fallback>
      <span class="font-semibold text-muted-foreground">{user.initials}</span>
    </Avatar.Fallback>
  </Avatar.Root>
{/if}
