<script>
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';

  let { id, title, subtitle, children } = $props();
</script>

<Card {id} class="mb-8">
  <CardHeader>
    <CardTitle class="text-2xl">{title}</CardTitle>
    <p class="text-muted-foreground mt-2">{subtitle}</p>
  </CardHeader>
  <CardContent class="space-y-6">
    {@render children?.()}
  </CardContent>
</Card>
