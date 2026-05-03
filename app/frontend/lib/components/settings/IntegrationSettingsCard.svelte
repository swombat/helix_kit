<script>
  import { Label } from '$lib/components/shadcn/label/index.js';
  import { Switch } from '$lib/components/shadcn/switch/index.js';

  let { enabled = false, label, description, switchId = 'enabled', onToggle } = $props();
</script>

<div class="border rounded-lg p-6">
  <h2 class="font-semibold mb-4">Settings</h2>

  <div class="flex items-center justify-between">
    <div class="flex items-center gap-3">
      <Switch id={switchId} checked={enabled} onCheckedChange={onToggle} />
      <Label for={switchId}>{label}</Label>
    </div>
  </div>

  <p class="text-sm text-muted-foreground mt-4">{description}</p>
</div>
