<script>
  import {
    Drawer,
    DrawerContent,
    DrawerHeader,
    DrawerTitle,
    DrawerClose,
  } from '$lib/components/shadcn/drawer/index.js';
  import InfoCard from '$lib/components/InfoCard.svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import Highlight from 'svelte-highlight';
  import json from 'svelte-highlight/languages/json';
  import 'svelte-highlight/styles/atom-one-dark.css';
  import Avatar from '$lib/components/Avatar.svelte';

  let { open = $bindable(false), selectedLog = null, onClose = () => {} } = $props();
</script>

<!-- Detail Drawer -->
<Drawer {open} onOpenChange={(open) => !open && onClose()}>
  <DrawerContent class="h-[85vh] max-w-3xl mx-auto">
    {#if selectedLog}
      <DrawerHeader class="border-b pb-4">
        <DrawerTitle class="text-xl font-semibold flex items-center gap-3">
          <span>Audit Log Details - {selectedLog.display_action}</span>
        </DrawerTitle>
      </DrawerHeader>

      <div class="overflow-y-auto flex-1 p-6">
        <div class="space-y-6">
          <!-- Primary Information Section -->
          <InfoCard title="Event Information" icon="Info">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">Timestamp</dt>
                <dd class="mt-1 text-sm font-medium">
                  {new Date(selectedLog.created_at).toLocaleString('en-US', {
                    dateStyle: 'medium',
                    timeStyle: 'medium',
                  })}
                </dd>
              </div>

              <div>
                <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">Event ID</dt>
                <dd class="mt-1 text-sm font-mono bg-muted px-2 py-1 rounded inline-block">
                  #{selectedLog.id}
                </dd>
              </div>
            </div>
          </InfoCard>

          <!-- Actor Information -->
          {#if selectedLog.user || selectedLog.account}
            <InfoCard title="Actor Information" icon="User">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                {#if selectedLog.user}
                  <div>
                    <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">User</dt>
                    <dd class="mt-1 text-sm">
                      <div class="flex items-center gap-2">
                        <Avatar user={selectedLog.user} size="small" />
                        <div>
                          <div class="font-medium">{selectedLog.user.email_address}</div>
                          {#if selectedLog.user.id}
                            <div class="text-xs text-muted-foreground">ID: {selectedLog.user.id}</div>
                          {/if}
                        </div>
                      </div>
                    </dd>
                  </div>
                {/if}

                {#if selectedLog.account}
                  <div>
                    <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">Account</dt>
                    <dd class="mt-1 text-sm">
                      <div class="font-medium">{selectedLog.account.name}</div>
                      {#if selectedLog.account.id}
                        <div class="text-xs text-muted-foreground">ID: {selectedLog.account.id}</div>
                      {/if}
                    </dd>
                  </div>
                {/if}
              </div>
            </InfoCard>
          {/if}

          <!-- Affected Object -->
          {#if selectedLog.auditable_type || selectedLog.auditable}
            <InfoCard title="Affected Object" icon="Target">
              <div class="space-y-4">
                <div>
                  <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">Object Type</dt>
                  <dd class="mt-1 text-sm font-medium">
                    <span class="bg-primary/10 text-primary px-2 py-1 rounded">
                      {selectedLog.auditable_type} #{selectedLog.auditable_id}
                    </span>
                  </dd>
                </div>

                {#if selectedLog.auditable}
                  <div>
                    <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">Object Data</dt>
                    <dd>
                      <div class="rounded-lg overflow-x-auto text-xs select-text">
                        <Highlight language={json} code={JSON.stringify(selectedLog.auditable, null, 2)} />
                      </div>
                    </dd>
                  </div>
                {/if}
              </div>
            </InfoCard>
          {/if}

          <!-- Additional Data -->
          {#if selectedLog.data && Object.keys(selectedLog.data).length > 0}
            <InfoCard title="Additional Data" icon="Database">
              <div class="rounded-lg overflow-x-auto text-xs select-text">
                <Highlight language={json} code={JSON.stringify(selectedLog.data, null, 2)} />
              </div>
            </InfoCard>
          {/if}

          <!-- Technical Details -->
          {#if selectedLog.ip_address || selectedLog.user_agent}
            <InfoCard title="Technical Details" icon="GearSix">
              <div class="space-y-3">
                {#if selectedLog.ip_address}
                  <div>
                    <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">IP Address</dt>
                    <dd class="mt-1 text-sm font-mono bg-muted px-2 py-1 rounded inline-block">
                      {selectedLog.ip_address}
                    </dd>
                  </div>
                {/if}

                {#if selectedLog.user_agent}
                  <div>
                    <dt class="text-xs font-medium text-muted-foreground uppercase tracking-wider">User Agent</dt>
                    <dd class="mt-1 text-xs bg-muted p-2 rounded break-words font-mono">
                      {selectedLog.user_agent}
                    </dd>
                  </div>
                {/if}
              </div>
            </InfoCard>
          {/if}
        </div>
      </div>

      <div class="p-4 border-t bg-background">
        <DrawerClose asChild>
          <Button variant="outline" class="w-full sm:w-auto">Close</Button>
        </DrawerClose>
      </div>
    {/if}
  </DrawerContent>
</Drawer>
