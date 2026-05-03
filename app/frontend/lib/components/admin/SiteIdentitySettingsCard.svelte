<script>
  import { Button } from '$lib/components/shadcn/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';

  let { setting = {}, form, logoFile = null, onLogoChange, onRemoveLogo } = $props();
</script>

<Card>
  <CardHeader>
    <CardTitle>Site Identity</CardTitle>
    <CardDescription>Customize your site's name and branding</CardDescription>
  </CardHeader>
  <CardContent class="space-y-4">
    <div class="space-y-2">
      <Label for="site_name">Site Name</Label>
      <Input id="site_name" type="text" bind:value={form.site_name} placeholder="HelixKit" required />
    </div>

    <div class="space-y-2">
      <Label for="logo">Site Logo</Label>

      {#if setting.logo_url && !logoFile}
        <div class="flex items-center gap-4">
          <img src={setting.logo_url} alt="Site logo" class="h-16 w-auto border rounded" />
          <div class="flex gap-2">
            <Button type="button" variant="outline" size="sm" onclick={() => document.getElementById('logo').click()}>
              Change
            </Button>
            <Button type="button" variant="destructive" size="sm" onclick={onRemoveLogo}>Remove</Button>
          </div>
        </div>
      {/if}

      <Input
        id="logo"
        type="file"
        accept="image/png,image/jpeg,image/gif,image/webp,image/svg+xml"
        onchange={onLogoChange}
        class={setting.logo_url && !logoFile ? 'hidden' : ''} />

      {#if logoFile}
        <p class="text-sm text-muted-foreground">New: {logoFile.name}</p>
      {/if}
    </div>
  </CardContent>
</Card>
