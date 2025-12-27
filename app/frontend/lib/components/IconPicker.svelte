<script>
  import { cn } from '$lib/utils.js';
  import {
    Robot,
    Brain,
    Sparkle,
    Lightning,
    Star,
    Heart,
    Sun,
    Moon,
    Eye,
    Globe,
    Compass,
    Rocket,
    Atom,
    Lightbulb,
    Crown,
    Shield,
    Fire,
    Target,
    Trophy,
    Flask,
    Code,
    Cube,
    PuzzlePiece,
    Cat,
    Dog,
    Bird,
    Alien,
    Ghost,
    Detective,
    Butterfly,
    Flower,
    Tree,
    Leaf,
  } from 'phosphor-svelte';

  let { value = $bindable(null), options = [], label = 'Icon', colour = null } = $props();

  // Map icon names to their components
  const iconComponents = {
    Robot,
    Brain,
    Sparkle,
    Lightning,
    Star,
    Heart,
    Sun,
    Moon,
    Eye,
    Globe,
    Compass,
    Rocket,
    Atom,
    Lightbulb,
    Crown,
    Shield,
    Fire,
    Target,
    Trophy,
    Flask,
    Code,
    Cube,
    PuzzlePiece,
    Cat,
    Dog,
    Bird,
    Alien,
    Ghost,
    Detective,
    Butterfly,
    Flower,
    Tree,
    Leaf,
  };

  function selectIcon(icon) {
    value = icon;
  }

  function getIconBgClass(isSelected) {
    if (colour) {
      return `bg-${colour}-100 dark:bg-${colour}-900`;
    }
    return isSelected ? 'bg-primary/20' : 'bg-muted';
  }

  function getIconTextClass() {
    if (colour) {
      return `text-${colour}-700 dark:text-${colour}-300`;
    }
    return 'text-primary';
  }
</script>

<div class="space-y-2">
  <label class="text-sm font-medium leading-none">{label}</label>
  <div class="flex flex-wrap gap-2">
    {#each options as iconName}
      {@const IconComponent = iconComponents[iconName]}
      {#if IconComponent}
        <button
          type="button"
          onclick={() => selectIcon(iconName)}
          class={cn(
            'p-2 rounded-lg border-2 transition-all hover:scale-110',
            getIconBgClass(value === iconName),
            value === iconName ? 'border-primary ring-2 ring-primary/20' : 'border-transparent'
          )}
          title={iconName}>
          <IconComponent class={cn('size-5', getIconTextClass())} weight="duotone" />
        </button>
      {/if}
    {/each}
  </div>
  {#if value}
    <p class="text-xs text-muted-foreground">Selected: {value}</p>
  {:else}
    <p class="text-xs text-muted-foreground">No icon selected (uses Robot by default)</p>
  {/if}
</div>
