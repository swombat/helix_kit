<script>
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Badge } from '$lib/components/shadcn/badge';
  import Highlight from 'svelte-highlight';
  import ruby from 'svelte-highlight/languages/ruby';
  import javascript from 'svelte-highlight/languages/javascript';
  import 'svelte-highlight/styles/atom-one-dark.css';

  // Code examples as constants for better readability
  const syncModelExample = `class Account < ApplicationRecord
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
end`;

  const syncSvelteExample = `<script>
  import { useSync } from '$lib/use-sync';
  
  let { accounts = [], selected_account = null } = $props();
  
  // Subscribe to real-time updates
  useSync({
    'Account:all': 'accounts',  // Updates when any account changes
    [\`Account:\${selected_account?.id}\`]: 'selected_account' // Updates specific account
  });
<\/script>`;

  const broadcastsToExample = `# Controller provides props
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
end`;

  const svelteChannelMapping = `// Svelte component maps channels to props
<script>
  import { useSync } from '$lib/use-sync';
  
  let { account, members } = $props();
  
  // When Account:123 broadcasts, reload both props
  useSync({
    [\`Account:\${account.id}\`]: ['account', 'members']
  });
<\/script>`;

  const multipleSyncExample = `useSync({
  'Account:all': 'accounts',
  [\`Account:\${account.id}\`]: 'account',
  [\`User:\${user.id}\`]: 'current_user',
  'SystemSetting:all': 'settings' // Admin only
});`;

  const parentChildExample = `class AccountUser < ApplicationRecord
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
end`;

  const dynamicSyncExample = `import { createDynamicSync } from '$lib/use-sync';

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
});`;

  const jsonAttributesBasic = `class User < ApplicationRecord
  include JsonAttributes
  
  # Specify what to include in JSON, excluding sensitive fields
  json_attributes :full_name, :site_admin, except: [:password_digest]
end

class Account < ApplicationRecord
  include JsonAttributes
  
  # Include boolean methods (the ? will be stripped in JSON)
  json_attributes :personal?, :team?, :active?, :is_site_admin, :name
end

class AccountUser < ApplicationRecord
  include JsonAttributes
  
  # Include associations with their json_attributes
  json_attributes :role, :confirmed_at, include: { user: {}, account: {} }
end`;

  const jsonAttributesController = `class AccountsController < ApplicationController
  def show
    @account = current_user.accounts.find(params[:id])
    
    render inertia: "accounts/show", props: {
      # as_json automatically uses json_attributes configuration
      account: @account.as_json,
      # Pass current_user context for authorization in nested associations
      members: @account.account_users.as_json(current_user: current_user)
    }
  end
end`;

  const jsonAttributesAdvanced = `class User < ApplicationRecord
  include JsonAttributes
  
  json_attributes :email_address, :full_name do |hash, options|
    # Add computed properties
    hash[:initials] = full_name.split.map(&:first).join
    
    # Conditional attributes based on context
    if options[:current_user]&.admin?
      hash[:last_login_at] = last_login_at
    end
    
    hash
  end
end`;

  const jsonAttributesOutput = `# Ruby model
user = User.find(1)
user.id          # => 1
user.to_param    # => "usr_abc123xyz"
user.site_admin? # => true

# JSON output
user.as_json
# => {
#   "id": "usr_abc123xyz",    # Automatically obfuscated
#   "full_name": "Jane Doe",
#   "email_address": "jane@example.com",
#   "site_admin": true         # Note: no "?" in key
#   # password_digest is excluded
# }`;
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
            <Highlight language={ruby} code={syncModelExample} />
          </div>

          <div>
            <h4 class="font-medium mb-2">2. Use in your Svelte component:</h4>
            <Highlight language={javascript} code={syncSvelteExample} />
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
            <Highlight language={ruby} code={broadcastsToExample} />
            <div class="mt-4">
              <Highlight language={javascript} code={svelteChannelMapping} />
            </div>
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
            <Highlight language={javascript} code={multipleSyncExample} />
          </div>

          <div>
            <h4 class="font-medium mb-2">Parent-Child Broadcasting:</h4>
            <Highlight language={ruby} code={parentChildExample} />
          </div>

          <div>
            <h4 class="font-medium mb-2">Dynamic Subscriptions:</h4>
            <Highlight language={javascript} code={dynamicSyncExample} />
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
        <Highlight
          language={ruby}
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
    </CardContent>
  </Card>

  <!-- JSON Attributes Section -->
  <Card class="mb-8">
    <CardHeader>
      <CardTitle class="text-2xl">JSON Serialization with json_attributes</CardTitle>
      <p class="text-muted-foreground mt-2">
        Declarative JSON serialization with automatic ID obfuscation for security and clean URLs
      </p>
    </CardHeader>
    <CardContent class="space-y-6">
      <!-- How it Works -->
      <div>
        <h3 class="text-lg font-semibold mb-3">How It Works</h3>
        <p class="text-muted-foreground mb-3">
          The <code class="text-sm bg-muted px-1 py-0.5 rounded">json_attributes</code> concern provides a declarative way
          to control how Rails models are serialized to JSON, ensuring security and consistency across your application.
        </p>
        <ol class="list-decimal list-inside space-y-2 text-muted-foreground">
          <li>Explicitly declare which attributes and methods to include in JSON</li>
          <li>
            Automatically obfuscate IDs using the model's <code class="text-xs bg-muted px-1 rounded">to_param</code> method
          </li>
          <li>Strip <code class="text-xs bg-muted px-1 rounded">?</code> from boolean method names</li>
          <li>Support nested associations with their own json_attributes</li>
          <li>Pass context (like current_user) through to nested models</li>
        </ol>
      </div>

      <!-- Basic Usage -->
      <div>
        <h3 class="text-lg font-semibold mb-3">Basic Usage</h3>

        <div class="space-y-4">
          <div>
            <h4 class="font-medium mb-2">1. Define in your models:</h4>
            <Highlight language={ruby} code={jsonAttributesBasic} />
          </div>

          <div>
            <h4 class="font-medium mb-2">2. Use in controllers:</h4>
            <Highlight language={ruby} code={jsonAttributesController} />
          </div>

          <div>
            <h4 class="font-medium mb-2">3. Resulting JSON output:</h4>
            <Highlight language={ruby} code={jsonAttributesOutput} />
          </div>
        </div>
      </div>

      <!-- Key Features -->
      <div>
        <h3 class="text-lg font-semibold mb-3">Key Features</h3>

        <div class="grid md:grid-cols-2 gap-4">
          <div class="space-y-3">
            <div>
              <h4 class="font-medium text-sm mb-1">🔒 Security First</h4>
              <p class="text-xs text-muted-foreground">
                Sensitive fields like <code class="text-xs bg-muted px-1 rounded">password_digest</code> are never accidentally
                exposed
              </p>
            </div>

            <div>
              <h4 class="font-medium text-sm mb-1">🎭 ID Obfuscation</h4>
              <p class="text-xs text-muted-foreground">
                Real database IDs are hidden, replaced with obfuscated versions for better security
              </p>
            </div>

            <div>
              <h4 class="font-medium text-sm mb-1">✨ Clean Boolean Keys</h4>
              <p class="text-xs text-muted-foreground">
                Methods like <code class="text-xs bg-muted px-1 rounded">admin?</code> become
                <code class="text-xs bg-muted px-1 rounded">admin</code> in JSON
              </p>
            </div>
          </div>

          <div class="space-y-3">
            <div>
              <h4 class="font-medium text-sm mb-1">🔗 Association Support</h4>
              <p class="text-xs text-muted-foreground">
                Include nested models with their own json_attributes configuration
              </p>
            </div>

            <div>
              <h4 class="font-medium text-sm mb-1">🎯 Context Propagation</h4>
              <p class="text-xs text-muted-foreground">
                Pass <code class="text-xs bg-muted px-1 rounded">current_user</code> through nested associations for authorization
              </p>
            </div>

            <div>
              <h4 class="font-medium text-sm mb-1">🚀 Performance</h4>
              <p class="text-xs text-muted-foreground">
                Only specified attributes are serialized, reducing payload size
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Advanced Usage -->
      <div>
        <h3 class="text-lg font-semibold mb-3">Advanced Usage</h3>

        <div class="space-y-4">
          <div>
            <h4 class="font-medium mb-2">Custom Enhancement Block:</h4>
            <Highlight language={ruby} code={jsonAttributesAdvanced} />
            <p class="text-sm text-muted-foreground mt-2">
              Use the block form to add computed properties or conditional attributes based on who's viewing the data.
            </p>
          </div>
        </div>
      </div>

      <!-- Benefits -->
      <div>
        <h3 class="text-lg font-semibold mb-3">Benefits</h3>

        <div class="bg-green-50 dark:bg-green-900/20 p-4 rounded-lg">
          <ul class="space-y-2 text-sm">
            <li class="flex items-start gap-2">
              <span class="text-green-600 dark:text-green-400">✓</span>
              <span><strong>Security:</strong> Sensitive attributes are never accidentally exposed</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-green-600 dark:text-green-400">✓</span>
              <span
                ><strong>Clean URLs:</strong> <code class="text-xs bg-muted px-1 rounded">/users/usr_abc123</code>
                instead of <code class="text-xs bg-muted px-1 rounded">/users/1</code></span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-green-600 dark:text-green-400">✓</span>
              <span><strong>Consistency:</strong> All models serialize the same way throughout the app</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-green-600 dark:text-green-400">✓</span>
              <span><strong>Maintainability:</strong> JSON structure is defined in one place (the model)</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-green-600 dark:text-green-400">✓</span>
              <span
                ><strong>Works with Sync:</strong> Integrates seamlessly with the real-time synchronization system</span>
            </li>
          </ul>
        </div>
      </div>

      <!-- Key Files -->
      <div>
        <h3 class="text-lg font-semibold mb-3">Implementation Files</h3>

        <ul class="space-y-1 text-sm">
          <li>
            <a
              href="https://github.com/swombat/helix_kit/blob/master/app/models/concerns/json_attributes.rb"
              class="text-primary hover:underline"
              target="_blank">
              app/models/concerns/json_attributes.rb
            </a>
            <span class="text-muted-foreground"> - The concern implementation</span>
          </li>
          <li>
            <a
              href="https://github.com/swombat/helix_kit/blob/master/docs/json-attributes.md"
              class="text-primary hover:underline"
              target="_blank">
              docs/json-attributes.md
            </a>
            <span class="text-muted-foreground"> - Complete documentation with examples</span>
          </li>
        </ul>
      </div>

      <!-- See it in Action -->
      <div>
        <h3 class="text-lg font-semibold mb-3">See It In Action</h3>
        <p class="text-muted-foreground">
          Every model in this application uses <code class="text-xs bg-muted px-1 rounded">json_attributes</code>. Check
          the Network tab in your browser's DevTools to see the clean, secure JSON payloads being sent to Svelte
          components. Notice how all IDs are obfuscated and sensitive fields are never included.
        </p>
      </div>
    </CardContent>
  </Card>
</div>
