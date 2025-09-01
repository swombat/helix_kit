<script>
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Badge } from '$lib/components/shadcn/badge';
</script>

<div class="container mx-auto py-8 px-4 max-w-5xl">
  <h1 class="text-4xl font-bold mb-2">Documentation</h1>
  <p class="text-muted-foreground mb-8">Learn how to use the features of this application</p>

  <!-- Real-time Synchronization Section -->
  <Card class="mb-8">
    <CardHeader>
      <CardTitle class="text-2xl">Real-time Synchronization System</CardTitle>
      <p class="text-muted-foreground mt-2">Automatically update Svelte components when Rails models change</p>
    </CardHeader>
    <CardContent class="space-y-6">
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
            <pre class="bg-muted p-4 rounded-lg overflow-x-auto"><code
                >{`class Account < ApplicationRecord
  include SyncAuthorizable
  include Broadcastable
  
  # Broadcast to admin collection (for index pages)
  broadcasts_to :all
end

class AccountUser < ApplicationRecord
  include Broadcastable
  belongs_to :account
  
  # Broadcast changes to parent account
  broadcasts_to :account
end

class User < ApplicationRecord
  include Broadcastable
  has_many :accounts, through: :account_users
  
  # Broadcast to all associated accounts (auto-detected as collection)
  broadcasts_to :accounts
end`}</code></pre>
          </div>

          <div>
            <h4 class="font-medium mb-2">2. Use in your Svelte component:</h4>
            <pre class="bg-muted p-4 rounded-lg overflow-x-auto"><code
                >{`<script>
  import { useSync } from '$lib/use-sync';
  
  let { accounts = [], selected_account = null } = $props();
  
  // Subscribe to real-time updates
  useSync({
    'Account:all': 'accounts',  // Updates when any account changes
    [\`Account:\${selected_account?.id}\`]: 'selected_account' // Updates specific account
  });
</script>`}</code></pre>
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
                  href="https://github.com/danieltenner/helix_kit/blob/master/app/channels/sync_channel.rb"
                  class="text-primary hover:underline"
                  target="_blank">
                  app/channels/sync_channel.rb
                </a>
                <span class="text-muted-foreground"> - ActionCable channel</span>
              </li>
              <li>
                <a
                  href="https://github.com/danieltenner/helix_kit/blob/master/app/models/concerns/broadcastable.rb"
                  class="text-primary hover:underline"
                  target="_blank">
                  app/models/concerns/broadcastable.rb
                </a>
                <span class="text-muted-foreground"> - Broadcasting concern</span>
              </li>
              <li>
                <a
                  href="https://github.com/danieltenner/helix_kit/blob/master/app/models/concerns/sync_authorizable.rb"
                  class="text-primary hover:underline"
                  target="_blank">
                  app/models/concerns/sync_authorizable.rb
                </a>
                <span class="text-muted-foreground"> - Authorization logic</span>
              </li>
              <li>
                <a
                  href="https://github.com/danieltenner/helix_kit/blob/master/app/channels/application_cable/connection.rb"
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
                  href="https://github.com/danieltenner/helix_kit/blob/master/app/frontend/lib/cable.js"
                  class="text-primary hover:underline"
                  target="_blank">
                  app/frontend/lib/cable.js
                </a>
                <span class="text-muted-foreground"> - Core subscription management</span>
              </li>
              <li>
                <a
                  href="https://github.com/danieltenner/helix_kit/blob/master/app/frontend/lib/use-sync.js"
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
          The <code class="text-sm bg-muted px-1 py-0.5 rounded">broadcasts_to</code> method configures where model changes
          are broadcast. Rails automatically detects association types and handles them correctly.
        </p>

        <div class="space-y-4">
          <div>
            <h4 class="font-medium mb-2">Broadcasting Options:</h4>
            <ul class="space-y-3 text-sm">
              <li class="flex items-start gap-2">
                <code class="bg-muted px-2 py-1 rounded text-xs mt-0.5">:all</code>
                <span class="text-muted-foreground">
                  Broadcasts to a collection channel, typically used for admin index pages. Only site admins can
                  subscribe.
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
            <pre class="bg-muted p-4 rounded-lg overflow-x-auto"><code
                >{`# Controller provides props
class AccountsController < ApplicationController
  def show
    @account = current_user.accounts.find(params[:id])
    render inertia: "accounts/show", props: {
      account: @account.as_json,
      members: @account.account_users.as_json
    }
  end
end

# Models broadcast their identity
class AccountUser < ApplicationRecord
  include Broadcastable
  belongs_to :account
  
  # When AccountUser changes, broadcast to its account
  broadcasts_to :account
end`}</code></pre>
            <pre class="bg-muted p-4 rounded-lg overflow-x-auto mt-4"><code
                >{`// Svelte component maps channels to props
<script>
  import { useSync } from '$lib/use-sync';
  
  let { account, members } = $props();
  
  // When Account:123 broadcasts, reload both props
  useSync({
    [\`Account:\${account.id}\`]: ['account', 'members']
  });
</script>`}</code></pre>
          </div>

          <div class="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg">
            <p class="text-sm font-medium mb-2">💡 Key Insight:</p>
            <p class="text-sm text-muted-foreground">
              Models only broadcast their identity (e.g., "Account:123"). The Svelte components decide which props to
              reload based on their subscriptions. This separation of concerns keeps models clean and gives views full
              control.
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
            <pre class="bg-muted p-4 rounded-lg overflow-x-auto"><code
                >{`useSync({
  'Account:all': 'accounts',
  [\`Account:\${account.id}\`]: 'account',
  [\`User:\${user.id}\`]: 'current_user',
  'SystemSetting:all': 'settings' // Admin only
});`}</code></pre>
          </div>

          <div>
            <h4 class="font-medium mb-2">Parent-Child Broadcasting:</h4>
            <pre class="bg-muted p-4 rounded-lg overflow-x-auto"><code
                >{`class AccountUser < ApplicationRecord
  include Broadcastable
  
  belongs_to :account
  belongs_to :user
  
  # When AccountUser changes, broadcast to parent account
  broadcasts_to :account
end

class User < ApplicationRecord
  include Broadcastable
  
  has_many :account_users
  has_many :accounts, through: :account_users
  
  # When user changes, broadcast to all their accounts
  broadcasts_to :accounts
end`}</code></pre>
          </div>

          <div>
            <h4 class="font-medium mb-2">Dynamic Subscriptions:</h4>
            <pre class="bg-muted p-4 rounded-lg overflow-x-auto"><code
                >{`import { createDynamicSync } from '$lib/use-sync';

let { accounts = [], selected_account = null } = $props();

// Create dynamic sync handler
const updateSync = createDynamicSync();

// Update subscriptions when selected_account changes
$effect(() => {
  const subs = { 'Account:all': 'accounts' };
  
  if (selected_account) {
    subs[\`Account:\${selected_account.id}\`] = 'selected_account';
  }
  
  updateSync(subs);
});`}</code></pre>
            <p class="text-sm text-muted-foreground mt-2">
              Use <code class="text-xs bg-muted px-1 rounded">createDynamicSync</code> when subscriptions need to change
              based on reactive state. It properly cleans up old subscriptions before creating new ones.
            </p>
          </div>
        </div>
      </div>

      <!-- Testing -->
      <div>
        <h3 class="text-lg font-semibold mb-3">Testing</h3>
        <p class="text-muted-foreground mb-2">Run the synchronization tests to ensure everything is working:</p>
        <pre class="bg-muted p-3 rounded-lg"><code
            >{`rails test test/channels/sync_channel_test.rb
rails test test/models/concerns/broadcastable_test.rb`}</code></pre>
      </div>

      <!-- Example in Action -->
      <div>
        <h3 class="text-lg font-semibold mb-3">See It In Action</h3>
        <p class="text-muted-foreground">
          The <a href="/admin/accounts" class="text-primary hover:underline">Admin Accounts</a> page uses this synchronization
          system. Open it in two browser tabs, edit an account in one tab, and watch it update in real-time in the other!
        </p>
      </div>
    </CardContent>
  </Card>

  <!-- Additional Features Section -->
  <Card>
    <CardHeader>
      <CardTitle class="text-2xl">Other Features</CardTitle>
    </CardHeader>
    <CardContent>
      <div class="grid md:grid-cols-2 gap-6">
        <div>
          <h3 class="font-semibold mb-2">Authentication System</h3>
          <p class="text-muted-foreground text-sm">
            Built-in Rails 8 authentication with signup, login, password reset, and email confirmation.
          </p>
        </div>

        <div>
          <h3 class="font-semibold mb-2">Account Management</h3>
          <p class="text-muted-foreground text-sm">
            Support for personal and organization accounts with role-based access control.
          </p>
        </div>

        <div>
          <h3 class="font-semibold mb-2">UI Components</h3>
          <p class="text-muted-foreground text-sm">
            Pre-built components from ShadcnUI and DaisyUI with Tailwind CSS styling.
          </p>
        </div>

        <div>
          <h3 class="font-semibold mb-2">Testing Suite</h3>
          <p class="text-muted-foreground text-sm">
            Comprehensive testing with Playwright, Vitest, and Minitest for full coverage.
          </p>
        </div>
      </div>
    </CardContent>
  </Card>
</div>
