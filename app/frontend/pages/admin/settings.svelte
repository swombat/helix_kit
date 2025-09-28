<script>
  import { router } from '@inertiajs/svelte';
  import { useSync } from '$lib/use-sync';
  import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '$lib/components/shadcn/card';
  import { Button } from '$lib/components/shadcn/button';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';

  let { setting = {} } = $props();

  useSync({ 'Setting:all': 'setting' });

  let form = $state({ ...setting });
  let logoFile = $state(null);
  let submitting = $state(false);

  function handleLogoChange(e) {
    logoFile = e.target.files?.[0] || null;
  }

  function handleSubmit() {
    if (submitting) return;
    submitting = true;

    const formData = new FormData();
    formData.append('setting[site_name]', form.site_name);
    formData.append('setting[allow_signups]', form.allow_signups);
    formData.append('setting[allow_chats]', form.allow_chats);

    if (logoFile) {
      formData.append('setting[logo]', logoFile);
    }

    router.patch('/admin/settings', formData, {
      onFinish: () => {
        submitting = false;
        logoFile = null;
      },
    });
  }

  function handleRemoveLogo() {
    if (!confirm('Remove the site logo?')) return;

    const formData = new FormData();
    formData.append('setting[remove_logo]', 'true');

    router.patch('/admin/settings', formData);
  }
</script>

<div class="p-8 max-w-4xl mx-auto">
  <h1 class="text-3xl font-bold mb-2">Site Settings</h1>
  <p class="text-muted-foreground mb-8">Configure global site settings and feature toggles</p>

  <form
    onsubmit={(e) => {
      e.preventDefault();
      handleSubmit();
    }}>
    <div class="space-y-6">
      <!-- Site Identity -->
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
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onclick={() => document.getElementById('logo').click()}>
                    Change
                  </Button>
                  <Button type="button" variant="destructive" size="sm" onclick={handleRemoveLogo}>Remove</Button>
                </div>
              </div>
            {/if}

            <Input
              id="logo"
              type="file"
              accept="image/png,image/jpeg,image/gif,image/webp,image/svg+xml"
              onchange={handleLogoChange}
              class={setting.logo_url && !logoFile ? 'hidden' : ''} />

            {#if logoFile}
              <p class="text-sm text-muted-foreground">New: {logoFile.name}</p>
            {/if}
          </div>
        </CardContent>
      </Card>

      <!-- Feature Toggles -->
      <Card>
        <CardHeader>
          <CardTitle>Feature Toggles</CardTitle>
          <CardDescription>Control which features are available</CardDescription>
        </CardHeader>
        <CardContent class="space-y-6">
          <div class="flex items-center justify-between">
            <div class="space-y-1">
              <Label for="allow_signups">Allow New User Signups</Label>
              <p class="text-sm text-muted-foreground">When disabled, signup page returns 403</p>
            </div>
            <Switch
              id="allow_signups"
              checked={form.allow_signups}
              onCheckedChange={(checked) => (form.allow_signups = checked)} />
          </div>

          <div class="flex items-center justify-between">
            <div class="space-y-1">
              <Label for="allow_chats">Allow Chats</Label>
              <p class="text-sm text-muted-foreground">When disabled, chat pages return 403</p>
            </div>
            <Switch
              id="allow_chats"
              checked={form.allow_chats}
              onCheckedChange={(checked) => (form.allow_chats = checked)} />
          </div>
        </CardContent>
      </Card>

      <div class="flex justify-end">
        <Button type="submit" disabled={submitting}>
          {submitting ? 'Saving...' : 'Save Settings'}
        </Button>
      </div>
    </div>
  </form>
</div>
