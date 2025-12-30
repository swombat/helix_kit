<script>
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  // Import only the icons that are actually used with InfoCard
  import { Info, User, Target, Database, GearSix, ChartBar, Users, UserCircle, UserSwitch } from 'phosphor-svelte';

  // Mapping of icon names to components - add icons here as needed
  const iconMap = {
    Info,
    User,
    Target,
    Database,
    GearSix,
    ChartBar,
    Users,
    UserCircle,
    UserSwitch,
  };

  let { title, icon = null, iconSize = 20, iconWeight = 'regular', class: className = '' } = $props();

  // Get the icon component from the map
  const IconComponent = $derived(icon ? iconMap[icon] : null);
</script>

<Card class={className}>
  <CardHeader>
    <CardTitle class="mb-2 flex items-center gap-2">
      {#if IconComponent}
        <IconComponent size={iconSize} weight={iconWeight} class="text-muted-foreground" />
      {/if}
      {title}
    </CardTitle>
  </CardHeader>
  <CardContent>
    <slot />
  </CardContent>
</Card>
