# ActionCable - Streaming and Real-Time Updates Documentation

## Version Information
- Documentation version: Rails 8
- Source: https://guides.rubyonrails.org/action_cable_overview.html
- Source: https://api.rubyonrails.org/v8.0/classes/ActionCable/Channel/Streams.html
- Fetched: 2025-09-24

## Key Concepts

ActionCable provides WebSocket communication for Rails applications with these core concepts:

- **Channels**: Server-side classes that handle client connections and message routing
- **Connections**: Authentication layer that identifies users across channels
- **Subscriptions**: Client-side objects that maintain channel connections
- **Broadcasts**: Server-side messages sent to specific channels
- **Streams**: Persistent connections from channels to broadcasting queues

## Rails 8 Major Updates

### Database-Backed Pub/Sub (Solid Cable)
Rails 8 introduces **Solid Cable** as the new default ActionCable adapter in production:
- Uses your existing database (MySQL/PostgreSQL) instead of requiring Redis
- Implemented through fast database polling with SQLite for message storage
- Performance comparable to Redis in most situations
- Reduces external dependencies and deployment complexity
- Supports distributed deployments where jobs run in separate containers

### Enhanced Integration
- Tighter integration with Active Job and background processing
- Improved handling of high-frequency updates
- Better support for real-time features like notifications and chat
- Enhanced caching and faster load times with TurboPack integration

## Implementation Guide

### 1. Channel Creation and Lifecycle

Basic channel structure with proper lifecycle management:

```ruby
class StreamingChannel < ApplicationCable::Channel
  def subscribed
    # Authorization check
    return reject unless authorized?

    # Set up streaming based on parameters
    if params[:type] == "text_stream"
      stream_from "text_stream_#{params[:id]}"
    else
      reject
    end
  end

  def unsubscribed
    # Cleanup when client disconnects
    stop_all_streams
  end

  private

  def authorized?
    # Implement your authorization logic
    current_user.present?
  end
end
```

### 2. Streaming Patterns: stream_from vs stream_for

#### stream_from (Generic Broadcasting)
Best for custom streaming patterns and high-frequency text updates:

```ruby
# In channel
def subscribed
  # Custom channel name for text streaming
  stream_from "text_updates_#{params[:document_id]}"
end

# Broadcasting from anywhere in your app
ActionCable.server.broadcast(
  "text_updates_#{document.id}",
  {
    type: "text_chunk",
    content: "streaming text content...",
    position: 142
  }
)
```

#### stream_for (Model-Specific Broadcasting)
Best for model-based updates with automatic naming:

```ruby
# In channel
def subscribed
  document = Document.find(params[:id])
  return reject unless document.accessible_by?(current_user)

  stream_for document
end

# Broadcasting (automatically uses model's GlobalID)
DocumentChannel.broadcast_to(document, {
  type: "content_update",
  content: updated_content
})
```

### 3. Performance Patterns for High-Frequency Updates

#### Text Streaming Optimization
For streaming text content (like AI responses or live editing):

```ruby
class TextStreamChannel < ApplicationCable::Channel
  def subscribed
    stream_from "text_stream_#{params[:session_id]}"
  end
end

# Efficient text streaming with batching
class TextStreamService
  def initialize(session_id)
    @session_id = session_id
    @buffer = []
    @last_broadcast = Time.current
  end

  def stream_text(chunk)
    @buffer << chunk

    # Batch updates every 50ms or when buffer reaches size limit
    if should_broadcast?
      broadcast_batch
    end
  end

  private

  def should_broadcast?
    @buffer.size >= 10 || Time.current - @last_broadcast > 0.05
  end

  def broadcast_batch
    return if @buffer.empty?

    ActionCable.server.broadcast(
      "text_stream_#{@session_id}",
      {
        type: "text_batch",
        chunks: @buffer.dup,
        timestamp: Time.current.to_f
      }
    )

    @buffer.clear
    @last_broadcast = Time.current
  end
end
```

### 4. Broadcasting to Specific Users/Objects

#### User-Specific Broadcasting
```ruby
# For user-specific updates
class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end
end

# Broadcasting to specific user
NotificationChannel.broadcast_to(user, {
  type: "notification",
  title: "New Message",
  body: "You have received a message"
})
```

#### Object-Specific Broadcasting with Authorization
```ruby
class DocumentChannel < ApplicationCable::Channel
  def subscribed
    document = Document.find_by(id: params[:id])
    return reject unless document&.accessible_by?(current_user)

    # Stream both document updates and text content
    stream_for document
    stream_from "document_text_#{document.id}"
  end
end
```

## Channel Lifecycle Management

### Subscription Management Methods
```ruby
class AdvancedChannel < ApplicationCable::Channel
  def subscribed
    # Multiple stream subscriptions
    stream_from "global_updates"
    stream_for current_user

    # Conditional streaming
    if admin?
      stream_from "admin_notifications"
    end
  end

  def unsubscribed
    # Automatic cleanup of all streams
    stop_all_streams
  end

  # Selective stream management
  def stop_user_stream
    stop_stream_for current_user
  end

  def stop_global_stream
    stop_stream_from "global_updates"
  end
end
```

### Error Handling and Recovery
```ruby
class RobustChannel < ApplicationCable::Channel
  rescue_from StandardError, with: :handle_error

  def subscribed
    begin
      setup_streams
    rescue => e
      logger.error "Channel subscription failed: #{e.message}"
      reject
    end
  end

  private

  def handle_error(exception)
    logger.error "Channel error: #{exception.message}"
    transmit({
      type: "error",
      message: "Connection error occurred"
    })
  end

  def setup_streams
    # Your streaming logic with potential failures
    stream_from "critical_updates_#{params[:id]}"
  end
end
```

## Performance Best Practices

### 1. Connection Management
```ruby
# config/application.rb
config.action_cable.worker_pool_size = 4  # Adjust based on load
```

### 2. Message Size Optimization
```ruby
# Keep broadcast payloads small for better performance
ActionCable.server.broadcast(channel, {
  id: record.id,
  action: "update",
  # Send minimal data, let client fetch details if needed
  timestamp: Time.current.to_f
})
```

### 3. Batching for High-Frequency Updates
```ruby
class BatchedBroadcaster
  def initialize(channel)
    @channel = channel
    @pending_updates = []
    @timer = nil
  end

  def queue_update(data)
    @pending_updates << data
    schedule_broadcast
  end

  private

  def schedule_broadcast
    return if @timer

    @timer = Timer.new(0.1) do  # 100ms batching
      broadcast_batch
      @timer = nil
    end
  end

  def broadcast_batch
    return if @pending_updates.empty?

    ActionCable.server.broadcast(@channel, {
      type: "batch_update",
      updates: @pending_updates.dup
    })

    @pending_updates.clear
  end
end
```

### 4. Memory Management for Long-Lived Channels
```ruby
class EfficientChannel < ApplicationCable::Channel
  def subscribed
    # Avoid storing large objects in instance variables
    # They persist for the entire connection lifetime
    @user_id = current_user.id  # Store ID, not full object

    stream_from "updates_#{@user_id}"
  end

  def process_action(data)
    # Fetch fresh data for each action to avoid stale references
    user = User.find(@user_id)
    # Process with fresh user object
  end
end
```

## Rails 8 Configuration

### Cable Configuration (config/cable.yml)
```yaml
development:
  adapter: async

test:
  adapter: test

production:
  # Rails 8 default: database-backed with Solid Cable
  adapter: solid_cable
  # Legacy Redis configuration (optional)
  # adapter: redis
  # url: redis://localhost:6379/1
  # channel_prefix: myapp_production
```

### Database-Backed ActionCable Setup
```ruby
# Rails 8 automatically configures Solid Cable
# No additional setup required for basic usage

# For custom configuration:
# config/application.rb
config.solid_cable.silence_polling = true  # Reduce log noise
```

## Integration with Existing Sync System

This codebase already implements a sophisticated sync system using ActionCable. Key patterns:

### Existing SyncChannel Pattern
```ruby
# app/channels/sync_channel.rb demonstrates:
# 1. Authorization-based subscriptions
# 2. Dynamic model-based streaming
# 3. Collection and single-object patterns
# 4. Obfuscated ID usage for security

stream_from "#{params[:model]}:#{params[:id]}"  # Single object
stream_from "#{params[:model]}:all"             # Collection
```

### Broadcastable Concern Integration
The existing `Broadcastable` concern provides:
- Automatic broadcasting on model changes
- Structured marker messages for Svelte integration
- Smart association-based broadcasting
- Configurable broadcast targets

For text streaming, you can extend this pattern:
```ruby
# Add text streaming capability
class Document < ApplicationRecord
  include Broadcastable

  broadcasts_to :account  # Existing pattern

  def stream_text_update(chunk)
    ActionCable.server.broadcast(
      "document_text_#{obfuscated_id}",
      {
        type: "text_chunk",
        content: chunk,
        position: content.length,
        timestamp: Time.current.to_f
      }
    )
  end
end
```

## Important Considerations

### Memory Management
- Channels are long-lived objects that persist for the connection duration
- Avoid storing large objects in instance variables
- Use database IDs instead of full ActiveRecord objects
- Implement cleanup in `unsubscribed` method

### Security
- Always authorize subscriptions in the `subscribed` method
- Use obfuscated IDs or UUIDs instead of sequential IDs
- Validate all parameters from clients
- Implement proper authentication in `ApplicationCable::Connection`

### Performance Monitoring
- Monitor connection counts and memory usage
- Use appropriate worker pool sizes
- Consider message batching for high-frequency updates
- Monitor database performance with Solid Cable

### Error Handling
- Use `rescue_from` for graceful error handling
- Always validate parameters before streaming
- Implement reconnection logic on the client side
- Use `reject` instead of raising exceptions in channels

## Related Documentation

- [Synchronization System Usage](/docs/synchronization-usage.md)
- [Synchronization System Internals](/docs/synchronization-internals.md)
- [Rails 8 ActionCable Guide](https://guides.rubyonrails.org/action_cable_overview.html)
- [ActionCable API Documentation](https://api.rubyonrails.org/v8.0/classes/ActionCable/Channel/Base.html)