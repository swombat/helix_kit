# AI Conversations Implementation Plan (Revised)

## Executive Summary

This revised specification implements AI chat functionality following Rails conventions as closely as possible within the Svelte/Inertia constraints. The implementation uses only 3 simple components that act as dumb display terminals, with all business logic in Rails models. The architecture emphasizes server ownership of state, minimal client-side complexity, and maximum use of Inertia's built-in features.

**Key changes in this revision:**
- Uses `json_attributes` concern instead of `to_props_hash` methods
- Corrects sync channel strings to use proper "Parent:id/collection" format
- Implements `createDynamicSync` for components where selection changes dynamically

## Key Design Principles

### Following DHH's Feedback
1. **3 simple components**: Index (list view), Show (chat view), and ChatList (reusable sidebar partial)
2. **Fat models, skinny controllers**: All business logic in models
3. **Server owns state**: Markdown rendering, date formatting, model configuration all server-side
4. **Inertia's useForm**: Leverage built-in form handling instead of manual state
5. **Dynamic subscriptions**: Use `createDynamicSync` for changing selections
6. **Dumb components**: Components are display terminals, not state managers

## Architecture Overview

### Backend (Already Implemented)
- `Chat` and `Message` models with broadcasting via Broadcastable
- `ChatsController` and `MessagesController` with RESTful actions
- `AiResponseJob` for streaming AI responses
- `GenerateTitleJob` for auto-titling conversations
- ActionCable for real-time updates

### Frontend (To Be Implemented)
- **3 Svelte Components**:
  1. `Chats/Index.svelte` - Chat list with inline new chat form
  2. `Chats/Show.svelte` - Chat interface with messages and input
  3. `Chats/ChatList.svelte` - Reusable sidebar partial for Show view

## Implementation Steps

### Phase 1: Update Navigation

- [ ] Add to `/app/frontend/lib/components/navigation/Navbar.svelte`
```javascript
// In the links array after Documentation
{
  href: `/accounts/${currentAccount?.id}/chats`,
  label: 'Chats',
  show: !!currentUser
}
```

### Phase 2: Enhance Models with Business Logic

- [ ] Update `/app/models/chat.rb`
```ruby
class Chat < ApplicationRecord
  include Broadcastable
  include ObfuscatesId
  include JsonAttributes
  
  acts_as_chat
  
  belongs_to :account
  has_many :messages, dependent: :destroy
  
  broadcasts_to :account
  
  validates :model_id, presence: true
  
  after_create_commit -> { GenerateTitleJob.perform_later(self) }, unless: :title?
  
  # Available AI models
  MODELS = [
    ['openrouter/auto', 'Auto (Recommended)'],
    ['openai/gpt-4o-mini', 'GPT-4 Mini'],
    ['anthropic/claude-3.7-sonnet', 'Claude 3.7 Sonnet'],
    ['google/gemini-2.5-pro-preview-03-25', 'Gemini 2.5 Pro']
  ].freeze
  
  scope :latest, -> { order(updated_at: :desc) }
  
  # JSON serialization for Inertia props
  json_attributes :title_or_default, :model_id, :model_name, 
                  :updated_at_formatted, :message_count
  
  # Minimal JSON for sidebar lists
  json_attributes :title_or_default, :updated_at_short,
                  as: :sidebar_json
  
  # Create chat with optional initial message
  def self.create_with_message!(attributes, message_content: nil, user: nil)
    transaction do
      chat = create!(attributes)
      if message_content.present?
        message = chat.messages.create!(
          content: message_content,
          role: 'user',
          user: user
        )
        AiResponseJob.perform_later(chat, message)
      end
      chat
    end
  end
  
  def title_or_default
    title.presence || "New Conversation"
  end
  
  def model_name
    MODELS.find { |m| m[0] == model_id }&.last
  end
  
  def updated_at_formatted
    updated_at.strftime("%b %d at %l:%M %p")
  end
  
  def updated_at_short
    updated_at.strftime("%b %d")
  end
  
  def message_count
    messages.count
  end
end
```

- [ ] Update `/app/models/message.rb`
```ruby
class Message < ApplicationRecord
  include Broadcastable
  include ObfuscatesId
  include JsonAttributes
  
  acts_as_message
  
  belongs_to :chat, touch: true
  belongs_to :user, optional: true
  
  has_many_attached :files
  
  broadcasts_to :chat
  
  validates :role, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true
  
  # JSON serialization for Inertia props
  json_attributes :role, :content_html, :user_name, :user_avatar_url,
                  :completed?, :error, :created_at_formatted
  
  def completed?
    role == 'user' || (role == 'assistant' && completed)
  end
  
  def user_name
    user&.full_name
  end
  
  def user_avatar_url
    user&.avatar_url
  end
  
  def created_at_formatted
    created_at.strftime("%l:%M %p")
  end
  
  def content_html
    render_markdown
  end
  
  private
  
  def render_markdown
    renderer = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(
        filter_html: true,
        safe_links_only: true,
        hard_wrap: true
      ),
      autolink: true,
      fenced_code_blocks: true,
      tables: true,
      strikethrough: true
    )
    renderer.render(content || "").html_safe
  end
end
```

### Phase 3: Update Controllers

- [ ] Update `/app/controllers/chats_controller.rb`
```ruby
class ChatsController < ApplicationController
  before_action :set_chat, only: [:show, :destroy]
  
  def index
    @chats = current_account.chats.includes(:messages).latest
    
    render inertia: "Chats/Index", props: {
      chats: @chats.as_json,
      models: Chat::MODELS
    }
  end
  
  def show
    @chats = current_account.chats.latest
    @messages = @chat.messages.includes(:user)
    
    render inertia: "Chats/Show", props: {
      chat: @chat.as_json,
      chats: @chats.as_json(as: :sidebar_json),
      messages: @messages.as_json
    }
  end
  
  def create
    @chat = current_account.chats.create_with_message!(
      chat_params,
      message_content: params[:message],
      user: current_user
    )
    redirect_to account_chat_path(current_account, @chat)
  end
  
  def destroy
    @chat.destroy!
    redirect_to account_chats_path(current_account)
  end
  
  private
  
  def set_chat
    @chat = current_account.chats.find(params[:id])
  end
  
  def chat_params
    params.fetch(:chat, {})
      .permit(:model_id)
      .with_defaults(model_id: 'openrouter/auto')
  end
end
```

- [ ] Update `/app/controllers/messages_controller.rb`
```ruby
class MessagesController < ApplicationController
  before_action :set_chat
  
  def create
    @message = @chat.messages.create!(
      message_params.merge(user: current_user, role: 'user')
    )
    
    AiResponseJob.perform_later(@chat, @message)
    
    redirect_to account_chat_path(@chat.account, @chat)
  end
  
  def retry
    @message = @chat.messages.find(params[:id])
    
    # Clear error and retry
    @message.update!(error: nil, completed: false)
    last_user_message = @chat.messages.where(role: 'user').last
    AiResponseJob.perform_later(@chat, last_user_message) if last_user_message
    
    head :ok
  end
  
  private
  
  def set_chat
    @chat = current_account.chats.find(params[:chat_id])
  end
  
  def message_params
    params.require(:message).permit(:content)
  end
end
```

### Phase 4: Create Simple Svelte Components

- [ ] Create `/app/frontend/pages/Chats/Index.svelte`
```svelte
<script>
  import { page } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { createDynamicSync } from '$lib/use-sync';
  import { Button } from '$lib/components/shadcn/button';
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { ChatCircle, Plus } from 'phosphor-svelte';
  
  let { chats = [], models = [] } = $props();
  const account = $page.props.account;
  
  // Use dynamic sync since we might add selected chat functionality later
  const updateSync = createDynamicSync();
  
  $effect(() => {
    updateSync({
      [`Account:${account.id}/chats`]: 'chats'
    });
  });
  
  // Form for new chat
  const form = useForm({
    model_id: 'openrouter/auto',
    message: ''
  });
  
  let showNewChat = $state(false);
  
  function createChat() {
    $form.post(`/accounts/${account.id}/chats`, {
      onSuccess: () => {
        showNewChat = false;
        $form.reset();
      }
    });
  }
</script>

<div class="container mx-auto p-6 max-w-4xl">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold">AI Conversations</h1>
    <Button onclick={() => showNewChat = !showNewChat}>
      <Plus class="mr-2" />
      New Chat
    </Button>
  </div>
  
  {#if showNewChat}
    <Card class="mb-6">
      <CardHeader>
        <CardTitle>Start New Conversation</CardTitle>
      </CardHeader>
      <CardContent>
        <form onsubmit|preventDefault={createChat}>
          <div class="space-y-4">
            <div>
              <label for="model" class="block text-sm font-medium mb-2">
                AI Model
              </label>
              <select
                id="model"
                bind:value={$form.model_id}
                class="w-full p-2 border rounded-md"
              >
                {#each models as [value, label]}
                  <option {value}>{label}</option>
                {/each}
              </select>
            </div>
            
            <div>
              <label for="message" class="block text-sm font-medium mb-2">
                Your Message
              </label>
              <textarea
                id="message"
                bind:value={$form.message}
                placeholder="Ask anything..."
                required
                class="w-full p-3 border rounded-md min-h-[100px]"
              />
            </div>
            
            <div class="flex gap-2">
              <Button type="submit" disabled={$form.processing}>
                {$form.processing ? 'Creating...' : 'Start Chat'}
              </Button>
              <Button 
                type="button"
                variant="outline"
                onclick={() => showNewChat = false}
              >
                Cancel
              </Button>
            </div>
          </div>
        </form>
      </CardContent>
    </Card>
  {/if}
  
  {#if chats.length > 0}
    <div class="grid gap-3">
      {#each chats as chat}
        <Card class="hover:shadow-md transition-shadow">
          <CardContent class="p-4">
            <a href={`/accounts/${account.id}/chats/${chat.id}`} class="block">
              <h3 class="font-semibold text-lg">{chat.title_or_default}</h3>
              <div class="flex justify-between items-center mt-2 text-sm text-muted-foreground">
                <span>{chat.message_count} messages</span>
                <span>{chat.updated_at_formatted}</span>
              </div>
            </a>
          </CardContent>
        </Card>
      {/each}
    </div>
  {:else if !showNewChat}
    <Card>
      <CardContent class="text-center py-12">
        <ChatCircle class="mx-auto h-12 w-12 text-muted-foreground mb-4" />
        <h3 class="text-lg font-semibold mb-2">No conversations yet</h3>
        <p class="text-muted-foreground">
          Start a new chat to begin exploring AI assistance
        </p>
      </CardContent>
    </Card>
  {/if}
</div>
```

- [ ] Create `/app/frontend/pages/Chats/Show.svelte`
```svelte
<script>
  import { page } from '@inertiajs/svelte';
  import { useForm } from '@inertiajs/svelte';
  import { createDynamicSync } from '$lib/use-sync';
  import { Button } from '$lib/components/shadcn/button';
  import Avatar from '$lib/components/Avatar.svelte';
  import ChatList from './ChatList.svelte';
  import { Send, ArrowClockwise } from 'phosphor-svelte';
  import { onMount, tick } from 'svelte';
  
  let { chat, chats = [], messages = [] } = $props();
  const account = $page.props.account;
  const currentUser = $page.props.user;
  
  // Use dynamic sync since chat can change via sidebar selection
  const updateSync = createDynamicSync();
  
  $effect(() => {
    updateSync({
      [`Account:${account.id}/chats`]: 'chats',
      [`Chat:${chat.id}`]: ['chat', 'messages']
    });
  });
  
  // Message form
  const form = useForm({
    content: ''
  });
  
  let messagesContainer = $state();
  
  // Auto-scroll on new messages
  $effect(() => {
    if (messages.length && messagesContainer) {
      tick().then(() => {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      });
    }
  });
  
  function sendMessage() {
    $form.post(`/accounts/${account.id}/chats/${chat.id}/messages`, {
      onSuccess: () => $form.reset(),
      preserveScroll: true
    });
  }
  
  function retryMessage(messageId) {
    // Simple POST without form
    fetch(`/messages/${messageId}/retry`, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    });
  }
</script>

<div class="flex h-[calc(100vh-4rem)]">
  <!-- Sidebar -->
  <ChatList {chats} {account} currentChatId={chat.id} />
  
  <!-- Main chat -->
  <main class="flex-1 flex flex-col">
    <!-- Messages -->
    <div class="flex-1 overflow-y-auto p-4" bind:this={messagesContainer}>
      {#if messages.length === 0}
        <div class="text-center text-muted-foreground mt-8">
          <p>Start a conversation by typing a message below</p>
        </div>
      {:else}
        <div class="space-y-4 max-w-3xl mx-auto">
          {#each messages as message}
            <div class="flex gap-3 {message.role === 'user' ? 'justify-end' : ''}">
              {#if message.role === 'assistant'}
                <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                  AI
                </div>
              {/if}
              
              <div class="max-w-[70%] rounded-lg p-3 {message.role === 'user' ? 'bg-primary text-primary-foreground' : 'bg-muted'}">
                {#if message.error}
                  <div class="text-destructive">
                    Failed to get response.
                    <Button
                      variant="ghost"
                      size="sm"
                      onclick={() => retryMessage(message.id)}
                    >
                      <ArrowClockwise class="mr-1" />
                      Retry
                    </Button>
                  </div>
                {:else}
                  {@html message.content_html}
                  {#if !message.completed}
                    <span class="inline-block w-2 h-4 bg-current animate-pulse ml-1" />
                  {/if}
                {/if}
                <div class="text-xs opacity-60 mt-1">
                  {message.created_at_formatted}
                </div>
              </div>
              
              {#if message.role === 'user'}
                <Avatar user={currentUser} size="small" class="!size-8" />
              {/if}
            </div>
          {/each}
        </div>
      {/if}
    </div>
    
    <!-- Input -->
    <form onsubmit|preventDefault={sendMessage} class="border-t p-4">
      <div class="max-w-3xl mx-auto flex gap-2">
        <textarea
          bind:value={$form.content}
          onkeydown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              sendMessage();
            }
          }}
          placeholder="Type your message..."
          disabled={$form.processing}
          required
          class="flex-1 p-3 border rounded-md resize-none min-h-[60px] max-h-[200px]"
        />
        <Button type="submit" disabled={$form.processing} class="self-end">
          {#if $form.processing}
            Sending...
          {:else}
            <Send class="size-4" />
          {/if}
        </Button>
      </div>
    </form>
  </main>
</div>

<style>
  /* Server-rendered HTML styles */
  :global(.max-w-\[70\%] pre) {
    @apply bg-gray-900 text-gray-100 rounded p-3 overflow-x-auto my-2;
  }
  
  :global(.max-w-\[70\%] code:not(pre code)) {
    @apply bg-gray-100 dark:bg-gray-800 px-1 py-0.5 rounded text-sm;
  }
  
  :global(.max-w-\[70\%] ul, .max-w-\[70\%] ol) {
    @apply ml-4 my-2;
  }
</style>
```

- [ ] Create `/app/frontend/pages/Chats/ChatList.svelte`
```svelte
<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button';
  import { Plus } from 'phosphor-svelte';
  
  let { chats, account, currentChatId } = $props();
  
  function selectChat(chatId) {
    router.visit(`/accounts/${account.id}/chats/${chatId}`);
  }
  
  function newChat() {
    router.visit(`/accounts/${account.id}/chats`);
  }
</script>

<aside class="w-64 border-r bg-muted/10 flex flex-col">
  <div class="p-4 border-b">
    <Button class="w-full" onclick={newChat}>
      <Plus class="mr-2" />
      New Chat
    </Button>
  </div>
  
  <div class="flex-1 overflow-y-auto p-2">
    {#each chats as chat}
      <button
        onclick={() => selectChat(chat.id)}
        class="w-full text-left p-3 rounded-md mb-1 transition-colors
               {chat.id === currentChatId ? 'bg-primary/10 text-primary' : 'hover:bg-muted'}"
      >
        <div class="font-medium truncate">{chat.title_or_default}</div>
        <div class="text-xs text-muted-foreground">
          {chat.updated_at_short}
        </div>
      </button>
    {/each}
  </div>
</aside>
```

### Phase 5: Add Routes

- [ ] Update `/config/routes.rb` to add retry endpoint
```ruby
# After the existing chat/message routes
resources :messages, only: [] do
  member do
    post :retry
  end
end
```

## Key Improvements in This Revision

### json_attributes Implementation
1. **Declarative configuration** - No manual hash building
2. **Automatic ID obfuscation** - IDs become obfuscated params
3. **Clean boolean handling** - `?` automatically stripped from method names
4. **Multiple serialization formats** - Using `as: :sidebar_json` for different contexts

### Correct Sync Channel Format
1. **Collection channels** - `Account:${id}/chats` not just `Account:${id}`
2. **Follows conventions** - Matches documented patterns in synchronization-usage.md
3. **Clear hierarchy** - Parent:id/collection makes relationships obvious

### Dynamic Sync Implementation
1. **Handles changing selections** - Chat selection updates subscriptions
2. **Efficient updates** - Only subscribes to what's needed
3. **Follows existing patterns** - Matches admin/accounts.svelte approach
4. **Clean effects** - Single effect manages all subscriptions

## What We Eliminated
1. **Manual serialization methods** - json_attributes handles everything
2. **Complex subscription logic** - createDynamicSync simplifies
3. **Incorrect channel formats** - Fixed to proper conventions
4. **Static subscriptions** - Dynamic subscriptions handle selection changes

## What We Kept Simple
1. **3 focused components** - Each does one thing well
2. **Server owns logic** - Models contain all business rules
3. **Inertia patterns** - useForm for all form handling
4. **Rails conventions** - RESTful routes, fat models
5. **Clear data flow** - Props down, actions up

## Testing Strategy

### Model Tests
- [ ] Test `Chat.create_with_message!` transaction
- [ ] Test message markdown rendering
- [ ] Test json_attributes serialization
- [ ] Test different serialization contexts (default vs sidebar_json)

### Controller Tests
- [ ] Test authorization scoping
- [ ] Test chat creation with initial message
- [ ] Test message retry endpoint
- [ ] Test proper JSON serialization

### System Tests
- [ ] Test full chat flow with Playwright
- [ ] Test real-time updates via broadcasts
- [ ] Test dynamic subscription updates
- [ ] Test error handling and retry

## Performance & Security

### Performance
- Server-side markdown rendering (once per message)
- Efficient queries with includes
- Dynamic subscriptions minimize overhead
- json_attributes optimizes serialization
- Minimal client-side JavaScript

### Security
- All authorization through Rails associations
- CSRF protection via Inertia
- HTML sanitization in Redcarpet
- ID obfuscation via ObfuscatesId concern
- No client-side secrets

## The Rails Way Achieved

This implementation follows Rails philosophy:
1. **Fat models** - Business logic in `Chat.create_with_message!`
2. **Skinny controllers** - Controllers just orchestrate
3. **Server owns state** - Markdown, dates, configuration all server-side
4. **Convention over configuration** - Standard RESTful patterns, json_attributes DSL
5. **Simple and boring** - Code any Rails developer understands instantly

## Conclusion

This revised specification achieves maximum simplicity while properly using the codebase's established patterns. The use of json_attributes eliminates boilerplate, correct sync channels ensure proper real-time updates, and dynamic subscriptions handle changing UI state efficiently. Any Rails developer could understand and maintain this code with minimal Svelte knowledge.