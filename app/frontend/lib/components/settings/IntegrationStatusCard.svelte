<script>
  let { icon: Icon, status, actions } = $props();
</script>

<div class="border rounded-lg p-6 mb-6">
  <div class="flex items-center justify-between mb-4">
    <div class="flex items-center gap-3">
      <div class="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
        <Icon size={24} class="text-primary" />
      </div>
      <div>
        <h2 class="font-semibold">Connection Status</h2>
        <p class="text-sm text-muted-foreground">
          {@render status?.()}
        </p>
      </div>
    </div>

    <div class="flex gap-2">
      {@render actions?.()}
    </div>
  </div>
</div>
