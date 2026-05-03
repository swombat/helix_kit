export const syncModelExample = `class Account < ApplicationRecord
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

export const syncSvelteExample = `<script>
  import { useSync } from '$lib/use-sync';
  
  let { accounts = [], selected_account = null } = $props();
  
  // Subscribe to real-time updates
  useSync({
    'Account:all': 'accounts',  // Updates when any account changes
    [\`Account:\${selected_account?.id}\`]: 'selected_account' // Updates specific account
  });
<\/script>`;

export const broadcastsToExample = `# Controller provides props
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

export const svelteChannelMapping = `// Svelte component maps channels to props
<script>
  import { useSync } from '$lib/use-sync';
  
  let { account, members } = $props();
  
  // When Account:123 broadcasts, reload both props
  useSync({
    [\`Account:\${account.id}\`]: ['account', 'members']
  });
<\/script>`;

export const multipleSyncExample = `useSync({
  'Account:all': 'accounts',
  [\`Account:\${account.id}\`]: 'account',
  [\`User:\${user.id}\`]: 'current_user',
  'SystemSetting:all': 'settings' // Admin only
});`;

export const parentChildExample = `class AccountUser < ApplicationRecord
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

export const dynamicSyncExample = `import { createDynamicSync } from '$lib/use-sync';

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

export const jsonAttributesBasic = `class User < ApplicationRecord
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

export const jsonAttributesController = `class AccountsController < ApplicationController
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

export const jsonAttributesAdvanced = `class User < ApplicationRecord
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

export const jsonAttributesOutput = `# Ruby model
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

export const promptBasicExample = `# Create a prompt with a template
prompt = Prompt.new(template: "summarize_text")

# Or specify a model
prompt = Prompt.new(
  model: "openai/gpt-5",
  template: "analyze_user_feedback"
)

# Available model constants
Prompt::DEFAULT_MODEL # "openai/gpt-5"
Prompt::SMART_MODEL   # "openai/gpt-5"
Prompt::LIGHT_MODEL   # "openai/gpt-5-mini"
Prompt::CHAT_MODEL    # "openai/gpt-5-chat"`;

export const promptTemplateStructure = `# File structure for prompts
app/prompts/
└── my_prompt_type/
    ├── system.prompt.erb  # System message template (optional)
    └── user.prompt.erb    # User message template (optional)

# Example: app/prompts/summarize_text/system.prompt.erb
You are a helpful assistant that summarizes text concisely.
Focus on key points and maintain clarity.

# Example: app/prompts/summarize_text/user.prompt.erb
Please summarize the following text:

<%= text %>

Provide a summary in <%= max_words %> words or less.`;

export const promptExecutionMethods = `# Execute to get a string response
response = prompt.execute_to_string

# Execute with streaming (yields incremental responses)
prompt.execute_to_string do |incremental_response, delta|
  puts incremental_response  # Full response so far
  puts delta                  # Just the new chunk
end

# Execute to get JSON response(s)
json_response = prompt.execute_to_json

# Execute with JSON streaming
prompt.execute_to_json do |json_object|
  # Each complete JSON object is yielded as parsed
  process_json(json_object)
end

# Execute and save to a model (PromptOutput or similar)
prompt.execute(
  output_class: "PromptOutput",
  output_id: prompt_output.id,
  output_property: :ai_summary  # Property to update
)`;

export const promptRenderingExample = `# Render template with arguments
prompt = Prompt.new(template: "summarize_text")

params = prompt.render(
  text: "Long article text here...",
  max_words: 100
)
# Returns: { system: "...", user: "...", model: "openai/gpt-5" }

# Templates use ERB with hash arguments
# In user.prompt.erb:
# <%= text %>        # Inserts the text variable
# <%= max_words %>   # Inserts the max_words variable`;

export const promptSubclassExample = `# Create a specialized prompt class
class SummarizePrompt < Prompt
  def initialize(text:, max_words: 100)
    super(model: Prompt::LIGHT_MODEL, template: "summarize")
    
    @text = text
    @max_words = max_words
  end
  
  def render(**args)
    super(
      text: @text,
      max_words: @max_words
    )
  end
end

# Usage
prompt = SummarizePrompt.new(
  text: article.content,
  max_words: 150
)
summary = prompt.execute_to_string`;

export const promptConversationExample = `# For conversation-based prompts
prompt = Prompt.new(
  model: "openai/gpt-5",
  template: "conversation"  # Special template type
)

# Render conversation from messages
params = prompt.render(
  conversation: conversation  # Must have .messages association
)
# Returns messages in OpenRouter format:
# {
#   messages: [
#     { role: "user", content: "Hello" },
#     { role: "assistant", content: "Hi there!" }
#   ],
#   model: "openai/gpt-5"
# }`;

export const promptErrorHandling = `# Built-in retry logic for API errors

# Automatically retries on rate limiting:
# - Up to 6 attempts with exponential backoff (2^n seconds)
# - Logs retry attempts for debugging

# Automatically retries on timeout:
# - Up to 3 attempts
# - Useful for long-running requests

# All other errors bubble up immediately
try
  response = prompt.execute_to_string
rescue StandardError => e
  # Handle non-retryable errors
  Rails.logger.error "Prompt failed: #{e.message}"
end`;
