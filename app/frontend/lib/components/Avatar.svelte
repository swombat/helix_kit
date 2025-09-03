<script>
  import * as Avatar from '$lib/components/shadcn/avatar/index.js';

  let { user = null, size = 'default', class: className = '', onClick = null, ...restProps } = $props();

  console.log('Avatar', user);

  // Extract avatar data from user
  const avatarUrl = user?.avatar_url;
  const name = user ? `${user.first_name || ''} ${user.last_name || ''}`.trim() : '';
  const initials =
    user?.initials ||
    (name
      ? name
          .split(' ')
          .map((n) => n[0])
          .join('')
          .toUpperCase()
          .slice(0, 2)
      : '?');

  // Size variants - following Tailwind convention
  const sizeClasses = {
    small: 'h-6 w-6 text-xs',
    default: 'h-10 w-10 text-sm', // 40px as specified
    medium: 'h-12 w-12 text-base',
    large: 'h-16 w-16 text-lg',
    xl: 'h-20 w-20 text-2xl',
    xxl: 'h-24 w-24 text-3xl',
  };

  const sizeClass = sizeClasses[size] || sizeClasses.default;
</script>

{#if onClick}
  <button
    type="button"
    onclick={onClick}
    class="rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary"
    {...restProps}>
    <Avatar.Root class="{sizeClass} {className}">
      {#if avatarUrl}
        <Avatar.Image src={avatarUrl} alt="{name} avatar" />
      {/if}
      <Avatar.Fallback>
        <span class="font-semibold text-muted-foreground">{initials}</span>
      </Avatar.Fallback>
    </Avatar.Root>
  </button>
{:else}
  <Avatar.Root class="{sizeClass} {className}" {...restProps}>
    {#if avatarUrl}
      <Avatar.Image src={avatarUrl} alt="{name} avatar" />
    {/if}
    <Avatar.Fallback>
      <span class="font-semibold text-muted-foreground">{initials}</span>
    </Avatar.Fallback>
  </Avatar.Root>
{/if}
