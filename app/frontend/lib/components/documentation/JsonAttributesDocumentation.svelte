<script>
  import DocumentationCodeBlock from '$lib/components/documentation/DocumentationCodeBlock.svelte';
  import DocumentationTopicCard from '$lib/components/documentation/DocumentationTopicCard.svelte';
  import {
    jsonAttributesAdvanced,
    jsonAttributesBasic,
    jsonAttributesController,
    jsonAttributesOutput,
  } from '$lib/documentation-examples';
</script>

<!-- JSON Attributes Section -->
<DocumentationTopicCard
  id="json-attributes"
  title="JSON Serialization with json_attributes"
  subtitle="Declarative JSON serialization with automatic ID obfuscation for security and clean URLs">
  <!-- How it Works -->
  <div>
    <h3 class="text-lg font-semibold mb-3">How It Works</h3>
    <p class="text-muted-foreground mb-3">
      The <code class="text-sm bg-muted px-1 py-0.5 rounded">json_attributes</code> concern provides a declarative way to
      control how Rails models are serialized to JSON, ensuring security and consistency across your application.
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
        <DocumentationCodeBlock language="ruby" code={jsonAttributesBasic} />
      </div>

      <div>
        <h4 class="font-medium mb-2">2. Use in controllers:</h4>
        <DocumentationCodeBlock language="ruby" code={jsonAttributesController} />
      </div>

      <div>
        <h4 class="font-medium mb-2">3. Resulting JSON output:</h4>
        <DocumentationCodeBlock language="ruby" code={jsonAttributesOutput} />
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
          <p class="text-xs text-muted-foreground">Only specified attributes are serialized, reducing payload size</p>
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
        <DocumentationCodeBlock language="ruby" code={jsonAttributesAdvanced} />
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
          <span><strong>Works with Sync:</strong> Integrates seamlessly with the real-time synchronization system</span>
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
      Every model in this application uses <code class="text-xs bg-muted px-1 rounded">json_attributes</code>. Check the
      Network tab in your browser's DevTools to see the clean, secure JSON payloads being sent to Svelte components.
      Notice how all IDs are obfuscated and sensitive fields are never included.
    </p>
  </div>
</DocumentationTopicCard>
