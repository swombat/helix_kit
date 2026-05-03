<script>
  import { Badge } from '$lib/components/shadcn/badge';
  import DocumentationCodeBlock from '$lib/components/documentation/DocumentationCodeBlock.svelte';
  import DocumentationTopicCard from '$lib/components/documentation/DocumentationTopicCard.svelte';
  import {
    broadcastsToExample,
    dynamicSyncExample,
    multipleSyncExample,
    parentChildExample,
    svelteChannelMapping,
    syncModelExample,
    syncSvelteExample,
  } from '$lib/documentation-examples';
</script>

<!-- Real-time Synchronization Section -->
<DocumentationTopicCard
  id="realtime-sync"
  title="Real-time Synchronization System"
  subtitle="Automatically update Svelte components when Rails models change">
  <!-- How it Works -->
  <div>
    <h3 class="text-lg font-semibold mb-3">How It Works</h3>
    <ol class="list-decimal list-inside space-y-2 text-muted-foreground">
      <li>Rails models broadcast minimal "marker" messages when they change</li>
      <li>Svelte components subscribe to these broadcasts via ActionCable</li>
      <li>When a broadcast is received, Inertia performs a partial reload of just the affected props</li>
      <li>Updates are debounced (300ms) to handle multiple rapid changes efficiently</li>
    </ol>
  </div>

  <!-- Quick Start -->
  <div>
    <h3 class="text-lg font-semibold mb-3">Quick Start</h3>

    <div class="space-y-4">
      <div>
        <h4 class="font-medium mb-2">1. Add to your Rails model:</h4>
        <DocumentationCodeBlock language="ruby" code={syncModelExample} />
      </div>

      <div>
        <h4 class="font-medium mb-2">2. Use in your Svelte component:</h4>
        <DocumentationCodeBlock language="javascript" code={syncSvelteExample} />
      </div>
    </div>
  </div>

  <!-- Key Files -->
  <div>
    <h3 class="text-lg font-semibold mb-3">Key Implementation Files</h3>

    <div class="grid md:grid-cols-2 gap-4">
      <div>
        <h4 class="font-medium mb-2">Rails Side:</h4>
        <ul class="space-y-1 text-sm">
          <li>
            <a
              href="https://github.com/swombat/helix_kit/blob/master/app/channels/sync_channel.rb"
              class="text-primary hover:underline"
              target="_blank">
              app/channels/sync_channel.rb
            </a>
            <span class="text-muted-foreground"> - ActionCable channel</span>
          </li>
          <li>
            <a
              href="https://github.com/swombat/helix_kit/blob/master/app/models/concerns/broadcastable.rb"
              class="text-primary hover:underline"
              target="_blank">
              app/models/concerns/broadcastable.rb
            </a>
            <span class="text-muted-foreground"> - Broadcasting concern</span>
          </li>
          <li>
            <a
              href="https://github.com/swombat/helix_kit/blob/master/app/models/concerns/sync_authorizable.rb"
              class="text-primary hover:underline"
              target="_blank">
              app/models/concerns/sync_authorizable.rb
            </a>
            <span class="text-muted-foreground"> - Authorization logic</span>
          </li>
          <li>
            <a
              href="https://github.com/swombat/helix_kit/blob/master/app/channels/application_cable/connection.rb"
              class="text-primary hover:underline"
              target="_blank">
              app/channels/application_cable/connection.rb
            </a>
            <span class="text-muted-foreground"> - WebSocket auth</span>
          </li>
        </ul>
      </div>

      <div>
        <h4 class="font-medium mb-2">JavaScript/Svelte Side:</h4>
        <ul class="space-y-1 text-sm">
          <li>
            <a
              href="https://github.com/swombat/helix_kit/blob/master/app/frontend/lib/cable.js"
              class="text-primary hover:underline"
              target="_blank">
              app/frontend/lib/cable.js
            </a>
            <span class="text-muted-foreground"> - Core subscription management</span>
          </li>
          <li>
            <a
              href="https://github.com/swombat/helix_kit/blob/master/app/frontend/lib/use-sync.js"
              class="text-primary hover:underline"
              target="_blank">
              app/frontend/lib/use-sync.js
            </a>
            <span class="text-muted-foreground"> - Svelte hook</span>
          </li>
        </ul>
      </div>
    </div>
  </div>

  <!-- Authorization Model -->
  <div>
    <h3 class="text-lg font-semibold mb-3">Authorization Model</h3>
    <div class="space-y-2">
      <div class="flex items-start gap-2">
        <Badge variant="outline">Account-scoped</Badge>
        <span class="text-muted-foreground"
          >Objects with an `account` property are accessible by all users in that account</span>
      </div>
      <div class="flex items-start gap-2">
        <Badge variant="outline">Admin-only</Badge>
        <span class="text-muted-foreground"
          >Objects without an `account` property are only accessible by site admins</span>
      </div>
      <div class="flex items-start gap-2">
        <Badge variant="outline">Collections</Badge>
        <span class="text-muted-foreground">Site admins can subscribe to `:all` collections for any model</span>
      </div>
    </div>
  </div>

  <!-- Understanding broadcasts_to -->
  <div>
    <h3 class="text-lg font-semibold mb-3">Understanding broadcasts_to</h3>

    <p class="text-muted-foreground mb-4">
      The <code class="text-sm bg-muted px-1 py-0.5 rounded">broadcasts_to</code> method configures where model changes are
      broadcast. Rails automatically detects association types and handles them correctly.
    </p>

    <div class="space-y-4">
      <div>
        <h4 class="font-medium mb-2">Broadcasting Options:</h4>
        <ul class="space-y-3 text-sm">
          <li class="flex items-start gap-2">
            <code class="bg-muted px-2 py-1 rounded text-xs mt-0.5">:all</code>
            <span class="text-muted-foreground">
              Broadcasts to a collection channel, typically used for admin index pages. Only site admins can subscribe.
            </span>
          </li>
          <li class="flex items-start gap-2">
            <code class="bg-muted px-2 py-1 rounded text-xs mt-0.5">:association_name</code>
            <span class="text-muted-foreground">
              Broadcasts to associated records. Rails automatically detects the association type:
              <ul class="mt-2 ml-4 space-y-1">
                <li>
                  • <code class="text-xs">belongs_to</code> / <code class="text-xs">has_one</code> → broadcasts to single
                  record
                </li>
                <li>
                  • <code class="text-xs">has_many</code> / <code class="text-xs">has_and_belongs_to_many</code> → broadcasts
                  to each record
                </li>
              </ul>
            </span>
          </li>
        </ul>
      </div>

      <div>
        <h4 class="font-medium mb-2">Complete Working Example:</h4>
        <DocumentationCodeBlock language="ruby" code={broadcastsToExample} />
        <div class="mt-4">
          <DocumentationCodeBlock language="javascript" code={svelteChannelMapping} />
        </div>
      </div>

      <div class="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg">
        <p class="text-sm font-medium mb-2">💡 Key Insight:</p>
        <p class="text-sm text-muted-foreground">
          Models only broadcast their identity (e.g., "Account:123"). The Svelte components decide which props to reload
          based on their subscriptions. This separation of concerns keeps models clean and gives views full control.
        </p>
      </div>
    </div>
  </div>

  <!-- Advanced Usage -->
  <div>
    <h3 class="text-lg font-semibold mb-3">Advanced Usage</h3>

    <div class="space-y-4">
      <div>
        <h4 class="font-medium mb-2">Multiple Model Subscriptions:</h4>
        <DocumentationCodeBlock language="javascript" code={multipleSyncExample} />
      </div>

      <div>
        <h4 class="font-medium mb-2">Parent-Child Broadcasting:</h4>
        <DocumentationCodeBlock language="ruby" code={parentChildExample} />
      </div>

      <div>
        <h4 class="font-medium mb-2">Dynamic Subscriptions:</h4>
        <DocumentationCodeBlock language="javascript" code={dynamicSyncExample} />
        <p class="text-sm text-muted-foreground mt-2">
          Use <code class="text-xs bg-muted px-1 rounded">createDynamicSync</code> when subscriptions need to change based
          on reactive state. It properly cleans up old subscriptions before creating new ones.
        </p>
      </div>
    </div>
  </div>

  <!-- Testing -->
  <div>
    <h3 class="text-lg font-semibold mb-3">Testing</h3>
    <p class="text-muted-foreground mb-2">Run the synchronization tests to ensure everything is working:</p>
    <DocumentationCodeBlock
      language="ruby"
      code={`rails test test/channels/sync_channel_test.rb
rails test test/models/concerns/broadcastable_test.rb`} />
  </div>

  <!-- Example in Action -->
  <div>
    <h3 class="text-lg font-semibold mb-3">See It In Action</h3>
    <p class="text-muted-foreground">
      The <a href="/admin/accounts" class="text-primary hover:underline">Admin Accounts</a> page uses this synchronization
      system. Open it in two browser tabs, edit an account in one tab, and watch it update in real-time in the other!
    </p>
  </div>
</DocumentationTopicCard>
