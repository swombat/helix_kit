<script>
  import DocumentationCodeBlock from '$lib/components/documentation/DocumentationCodeBlock.svelte';
  import DocumentationQuickNavigation from '$lib/components/documentation/DocumentationQuickNavigation.svelte';
  import RealtimeSyncDocumentation from '$lib/components/documentation/RealtimeSyncDocumentation.svelte';
  import DocumentationTopicCard from '$lib/components/documentation/DocumentationTopicCard.svelte';

  import {
    jsonAttributesAdvanced,
    jsonAttributesBasic,
    jsonAttributesController,
    jsonAttributesOutput,
    promptBasicExample,
    promptConversationExample,
    promptErrorHandling,
    promptExecutionMethods,
    promptRenderingExample,
    promptSubclassExample,
    promptTemplateStructure,
  } from '$lib/documentation-examples';
</script>

<div class="container mx-auto py-8 px-4 max-w-5xl">
  <h1 class="text-4xl font-bold mb-2">Documentation</h1>
  <p class="text-muted-foreground mb-8">Learn how to use the features of this application</p>

  <DocumentationQuickNavigation />

  <RealtimeSyncDocumentation />

  <!-- JSON Attributes Section -->
  <DocumentationTopicCard
    id="json-attributes"
    title="JSON Serialization with json_attributes"
    subtitle="Declarative JSON serialization with automatic ID obfuscation for security and clean URLs">
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
  </DocumentationTopicCard>

  <!-- Prompt System Section -->
  <DocumentationTopicCard
    id="prompt-system"
    title="AI Prompt System (Prompt.rb)"
    subtitle="Flexible system for managing AI prompts with ERB templates, streaming support, and automatic retry logic">
    <!-- How it Works -->
    <div>
      <h3 class="text-lg font-semibold mb-3">How It Works</h3>
      <p class="text-muted-foreground mb-3">
        The Prompt.rb system provides a structured way to interact with AI models through OpenRouter API. It uses ERB
        templates for prompt composition and supports multiple execution modes.
      </p>
      <ol class="list-decimal list-inside space-y-2 text-muted-foreground">
        <li>
          Create prompt templates in <code class="text-xs bg-muted px-1 rounded">/app/prompts/</code> subdirectories
        </li>
        <li>Use ERB syntax to inject dynamic variables into prompts</li>
        <li>Execute prompts with various output formats (string, JSON, streaming)</li>
        <li>Automatically handle rate limiting and timeouts with built-in retry logic</li>
        <li>Optionally save outputs directly to database models</li>
      </ol>
    </div>

    <!-- Basic Usage -->
    <div id="prompt-basics">
      <h3 class="text-lg font-semibold mb-3">Basic Usage & Template Structure</h3>

      <div class="space-y-4">
        <div>
          <h4 class="font-medium mb-2">1. Creating a Prompt:</h4>
          <DocumentationCodeBlock language="ruby" code={promptBasicExample} />
        </div>

        <div>
          <h4 class="font-medium mb-2">2. Template File Structure:</h4>
          <DocumentationCodeBlock language="ruby" code={promptTemplateStructure} />
          <p class="text-sm text-muted-foreground mt-2">
            Templates use ERB syntax and can access any variables passed to the <code
              class="text-xs bg-muted px-1 rounded">render</code> method. Both system and user templates are optional - use
            what makes sense for your use case.
          </p>
        </div>

        <div>
          <h4 class="font-medium mb-2">3. Rendering Templates:</h4>
          <DocumentationCodeBlock language="ruby" code={promptRenderingExample} />
        </div>
      </div>
    </div>

    <!-- Execution Methods -->
    <div id="prompt-execution">
      <h3 class="text-lg font-semibold mb-3">Execution Methods</h3>

      <div class="space-y-4">
        <div>
          <h4 class="font-medium mb-2">Available Execution Methods:</h4>
          <DocumentationCodeBlock language="ruby" code={promptExecutionMethods} />
        </div>

        <div class="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg">
          <p class="text-sm font-medium mb-2">💡 Streaming Support:</p>
          <p class="text-sm text-muted-foreground">
            Both <code class="text-xs bg-muted px-1 rounded">execute_to_string</code> and
            <code class="text-xs bg-muted px-1 rounded">execute_to_json</code> support streaming via blocks. This is useful
            for real-time UI updates or processing large responses incrementally.
          </p>
        </div>
      </div>
    </div>

    <!-- Advanced Patterns -->
    <div id="prompt-advanced">
      <h3 class="text-lg font-semibold mb-3">Advanced Patterns</h3>

      <div class="space-y-4">
        <div>
          <h4 class="font-medium mb-2">Creating Specialized Prompt Classes:</h4>
          <DocumentationCodeBlock language="ruby" code={promptSubclassExample} />
          <p class="text-sm text-muted-foreground mt-2">
            Subclassing <code class="text-xs bg-muted px-1 rounded">Prompt</code> allows you to create reusable, domain-specific
            prompt classes with their own logic and defaults.
          </p>
        </div>

        <div>
          <h4 class="font-medium mb-2">Conversation-Based Prompts:</h4>
          <DocumentationCodeBlock language="ruby" code={promptConversationExample} />
          <p class="text-sm text-muted-foreground mt-2">
            The special <code class="text-xs bg-muted px-1 rounded">"conversation"</code> template type formats messages
            from a conversation object for chat-based interactions.
          </p>
        </div>

        <div>
          <h4 class="font-medium mb-2">Error Handling & Retries:</h4>
          <DocumentationCodeBlock language="ruby" code={promptErrorHandling} />
        </div>
      </div>
    </div>

    <!-- Key Features -->
    <div>
      <h3 class="text-lg font-semibold mb-3">Key Features</h3>

      <div class="grid md:grid-cols-2 gap-4">
        <div class="space-y-3">
          <div>
            <h4 class="font-medium text-sm mb-1">📝 ERB Templates</h4>
            <p class="text-xs text-muted-foreground">
              Use familiar ERB syntax to create dynamic, reusable prompt templates
            </p>
          </div>

          <div>
            <h4 class="font-medium text-sm mb-1">🔄 Streaming Support</h4>
            <p class="text-xs text-muted-foreground">
              Process responses incrementally for better UX and memory efficiency
            </p>
          </div>

          <div>
            <h4 class="font-medium text-sm mb-1">🔁 Automatic Retries</h4>
            <p class="text-xs text-muted-foreground">
              Built-in exponential backoff for rate limiting and timeout errors
            </p>
          </div>
        </div>

        <div class="space-y-3">
          <div>
            <h4 class="font-medium text-sm mb-1">🎯 Multiple Output Formats</h4>
            <p class="text-xs text-muted-foreground">Support for text, JSON, and direct model updates</p>
          </div>

          <div>
            <h4 class="font-medium text-sm mb-1">🤖 Model Flexibility</h4>
            <p class="text-xs text-muted-foreground">
              Easy switching between GPT-5, Claude, and other OpenRouter models
            </p>
          </div>

          <div>
            <h4 class="font-medium text-sm mb-1">💾 Database Integration</h4>
            <p class="text-xs text-muted-foreground">
              Save outputs directly to ActiveRecord models with streaming updates
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Model Mappings -->
    <div>
      <h3 class="text-lg font-semibold mb-3">Model Mappings</h3>
      <p class="text-muted-foreground mb-3">The system includes shorthand mappings for common models:</p>
      <div class="bg-muted p-4 rounded-lg">
        <ul class="space-y-1 text-sm font-mono">
          <li><code>"4o"</code> → <code>"openai/chatgpt-4o-latest"</code></li>
          <li><code>"o1"</code> → <code>"openai/o1"</code></li>
          <li><code>"4o-mini"</code> → <code>"openai/gpt-4o-mini"</code></li>
        </ul>
      </div>
    </div>

    <!-- Key Files -->
    <div>
      <h3 class="text-lg font-semibold mb-3">Implementation Files</h3>

      <ul class="space-y-1 text-sm">
        <li>
          <code class="bg-muted px-2 py-0.5 rounded">app/prompts/prompt.rb</code>
          <span class="text-muted-foreground"> - Core Prompt class implementation</span>
        </li>
        <li>
          <code class="bg-muted px-2 py-0.5 rounded">app/prompts/*/</code>
          <span class="text-muted-foreground"> - Template directories (create as needed)</span>
        </li>
        <li>
          <code class="bg-muted px-2 py-0.5 rounded">app/models/prompt_output.rb</code>
          <span class="text-muted-foreground"> - Model for storing prompt outputs</span>
        </li>
        <li>
          <code class="bg-muted px-2 py-0.5 rounded">test/prompts/*_prompt_test.rb</code>
          <span class="text-muted-foreground"> - Test examples showing usage patterns</span>
        </li>
      </ul>
    </div>

    <!-- Testing -->
    <div>
      <h3 class="text-lg font-semibold mb-3">Testing</h3>
      <p class="text-muted-foreground mb-2">
        The system uses VCR to record and replay API responses in tests. This allows for fast, deterministic testing
        without hitting the API:
      </p>
      <DocumentationCodeBlock
        language="ruby"
        code={`rails test test/prompts/  # Run all prompt tests

# VCR cassettes are stored in test/vcr_cassettes/
# Delete a cassette to re-record API responses`} />
    </div>

    <!-- Best Practices -->
    <div>
      <h3 class="text-lg font-semibold mb-3">Best Practices</h3>
      <div class="bg-green-50 dark:bg-green-900/20 p-4 rounded-lg">
        <ul class="space-y-2 text-sm">
          <li class="flex items-start gap-2">
            <span class="text-green-600 dark:text-green-400">✓</span>
            <span><strong>Use templates for reusable prompts:</strong> Keep prompts DRY and maintainable</span>
          </li>
          <li class="flex items-start gap-2">
            <span class="text-green-600 dark:text-green-400">✓</span>
            <span><strong>Choose the right model:</strong> Use LIGHT_MODEL for simple tasks to save costs</span>
          </li>
          <li class="flex items-start gap-2">
            <span class="text-green-600 dark:text-green-400">✓</span>
            <span><strong>Handle streaming for long responses:</strong> Improves perceived performance</span>
          </li>
          <li class="flex items-start gap-2">
            <span class="text-green-600 dark:text-green-400">✓</span>
            <span><strong>Create prompt subclasses:</strong> For domain-specific logic and validation</span>
          </li>
          <li class="flex items-start gap-2">
            <span class="text-green-600 dark:text-green-400">✓</span>
            <span><strong>Use VCR in tests:</strong> Ensures tests are fast and reproducible</span>
          </li>
        </ul>
      </div>
    </div>
  </DocumentationTopicCard>
</div>
