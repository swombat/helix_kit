# Ruby LLM - Rails Integration Guide

## Version Information
- Documentation source: https://rubyllm.com/
- Rails integration guide: https://rubyllm.com/rails/
- Fetched: 2025-09-06

## Overview

Ruby LLM is a unified Ruby API that provides access to 500+ AI models from multiple providers including OpenAI, Anthropic, Gemini, AWS Bedrock, OpenRouter, DeepSeek, Ollama, and others. It offers a consistent interface across all providers with automatic message persistence, multi-modal support, and Rails integration.

## Installation and Setup

### Rails Generator Setup
```bash
# Install the gem
bundle add ruby_llm

# Run the Rails generator
rails generate ruby_llm:install

# Run migrations
rails db:migrate

# Populate model registry (v1.7.0+)
rails ruby_llm:load_models
```

### Model Configuration
Add the following acts_as declarations to your Rails models:

```ruby
# For Chat model
class Chat < ApplicationRecord
  acts_as_chat
end

# For Message model  
class Message < ApplicationRecord
  acts_as_message
end

# For ToolCall model
class ToolCall < ApplicationRecord
  acts_as_tool_call
end

# For Model metadata (v1.7.0+)
class Model < ApplicationRecord
  acts_as_model
end
```

### Configuration
```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.gemini_api_key = ENV['GOOGLE_GEMINI_API_KEY']
  # Add other provider keys as needed
end
```

## Core Usage Patterns

### Basic Chat Implementation
```ruby
# Create a chat with specific model
chat_record = Chat.create!(model_id: 'gpt-4.1-nano')

# Ask a question
response = chat_record.ask "What is the capital of France?"

# Access persisted messages
assistant_message = chat_record.messages.last
puts assistant_message.content

# Continue conversation
chat_record.ask "What about Italy?"
```

### Direct Usage (without persistence)
```ruby
# Simple one-off chat
chat = RubyLLM.chat
response = chat.ask "Explain Ruby's Global Interpreter Lock"
puts response.content
```

## Streaming Responses

### Basic Streaming
```ruby
chat.ask "Tell me a story about Ruby" do |chunk|
  print chunk.content
end
```

### Rails + Hotwire/Turbo Streaming
Use background jobs for AI response processing with Turbo broadcasts:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
  broadcasts_to :account
end

# In a background job
class AiResponseJob < ApplicationJob
  def perform(chat_id, user_message)
    chat = Chat.find(chat_id)
    
    chat.ask(user_message) do |chunk|
      # Broadcast real-time updates
      chat.broadcast_append_to(
        chat.account,
        target: "chat_#{chat.id}_messages",
        partial: "messages/streaming_chunk",
        locals: { chunk: chunk }
      )
    end
  end
end
```

## Multi-Modal Capabilities

### File Attachment Support
Ruby LLM supports various file types through ActiveStorage:

```ruby
# Attach files to messages
message = chat.messages.build(content: "Analyze this image")
message.files.attach(io: File.open('image.png'), filename: 'image.png')

# Ask about attached files
response = chat.ask "What do you see in this image?" do |msg|
  msg.files.attach(io: File.open('screenshot.png'), filename: 'screenshot.png')
end
```

### Supported File Types
- **Images**: PNG, JPEG, GIF, WebP
- **Audio**: MP3, WAV, M4A, FLAC
- **Documents**: PDF, TXT, Markdown
- **Code**: Various programming language files

### Multi-Modal Usage Examples
```ruby
# Image analysis
chat.ask "Describe this architectural drawing" do |msg|
  msg.files.attach(io: File.open('blueprint.pdf'), filename: 'blueprint.pdf')
end

# Audio transcription and analysis
chat.ask "Summarize this meeting recording" do |msg|
  msg.files.attach(io: File.open('meeting.mp3'), filename: 'meeting.mp3')
end
```

## OpenRouter Integration

### Configuration
```ruby
RubyLLM.configure do |config|
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
end
```

### Available Models (2025)
OpenRouter provides access to 500+ models including:
- **GPT Models**: GPT-4, GPT-5 (with long-context support)
- **Claude Models**: Claude 3.5 Sonnet, Claude 3 Opus
- **Open Source**: Llama 3, Mixtral, DeepSeek R1
- **Image Generation**: DALL-E 3, Midjourney, Stable Diffusion
- **Free Options**: Toppy, Zephyr, DeepSeek R1 (with usage limits)

### Model Selection
```ruby
# Use specific OpenRouter model
chat = Chat.create!(model_id: 'openai/gpt-4-turbo')

# Or let OpenRouter choose best option
chat = Chat.create!(model_id: 'openrouter/auto')
```

## Image Generation

### Basic Image Generation
```ruby
# Simple image generation
image_url = RubyLLM.paint("A Ruby gem sparkling in sunlight")

# With specific model and size
image_url = RubyLLM.paint(
  "Professional headshot photo", 
  model: "dall-e-3",
  size: "1024x1024"
)
```

### Rails Integration with ActiveStorage
```ruby
class ImageGenerationJob < ApplicationJob
  def perform(user_id, prompt)
    user = User.find(user_id)
    
    # Generate image
    image_data = RubyLLM.paint(prompt)
    
    # Save to ActiveStorage
    user.generated_images.attach(
      io: StringIO.new(Base64.decode64(image_data)),
      filename: "generated_#{Time.current.to_i}.png",
      content_type: "image/png"
    )
  end
end
```

## Tools and Structured Output

### Tool Integration
```ruby
class WeatherTool
  def self.get_weather(location:)
    # Implementation here
    { temperature: 22, condition: "sunny" }
  end
end

# Register and use tools
chat.ask "What's the weather like in Paris?" do |msg|
  msg.tools = [WeatherTool]
end
```

### Structured Output
```ruby
# Get JSON response with specific schema
response = chat.ask "Extract key information from this document", 
  response_format: {
    type: "json_object",
    schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        summary: { type: "string" },
        key_points: { type: "array", items: { type: "string" } }
      }
    }
  }

parsed_data = JSON.parse(response.content)
```

## Advanced Configuration

### Chat Configuration Options
```ruby
chat = RubyLLM.chat(
  model: "gpt-4",
  temperature: 0.7,           # Control creativity (0.0-2.0)
  max_tokens: 1000,          # Limit response length
  system_prompt: "You are a helpful Ruby expert",
  tools: [CustomTool],       # Available tools
  response_format: { type: "json_object" }  # Structured output
)
```

### Metadata and Token Tracking
```ruby
response = chat.ask "Explain recursion"

# Access metadata
puts "Tokens used: #{response.usage.total_tokens}"
puts "Input tokens: #{response.usage.prompt_tokens}"
puts "Output tokens: #{response.usage.completion_tokens}"
```

## Error Handling

### Common Error Patterns
```ruby
begin
  response = chat.ask "Generate content"
rescue RubyLLM::APIError => e
  Rails.logger.error "API Error: #{e.message}"
  # Handle API failures
rescue RubyLLM::RateLimitError => e
  # Handle rate limits - consider background job retry
  retry_later
rescue RubyLLM::ContentPolicyError => e
  # Handle content policy violations
  notify_user("Content violates policy: #{e.message}")
end
```

### Content Policy Handling
```ruby
begin
  image_url = RubyLLM.paint("artistic portrait")
rescue RubyLLM::ContentPolicyError => e
  # Handle image generation policy violations
  flash[:error] = "Image generation request was rejected: #{e.message}"
end
```

## Rails Controller Integration

### Chat Controller Example
```ruby
class ChatsController < ApplicationController
  def show
    @chat = current_user.chats.find(params[:id])
    @messages = @chat.messages.includes(:files_attachments)
  end

  def create_message
    @chat = current_user.chats.find(params[:chat_id])
    
    # Process in background for streaming
    AiResponseJob.perform_later(@chat.id, message_params[:content])
    
    redirect_to @chat
  end

  private

  def message_params
    params.require(:message).permit(:content, files: [])
  end
end
```

### Inertia.js Integration
```ruby
class ChatsController < ApplicationController
  def show
    chat = current_user.chats.find(params[:id])
    
    render inertia: 'Chats/Show', props: {
      chat: chat.as_json(include: :messages),
      available_models: Model.available.pluck(:id, :name)
    }
  end
end
```

## Performance Considerations

### Background Processing
```ruby
# Always process AI requests in background jobs
class AiChatJob < ApplicationJob
  queue_as :ai_processing
  
  def perform(chat_id, user_message)
    chat = Chat.find(chat_id)
    
    # Use streaming for real-time updates
    chat.ask(user_message) do |chunk|
      broadcast_chunk(chat, chunk)
    end
  end
end
```

### Caching Strategies
```ruby
# Cache model listings
def available_models
  Rails.cache.fetch("ruby_llm_models", expires_in: 1.hour) do
    Model.available.order(:name).pluck(:id, :name, :provider)
  end
end

# Cache embeddings for similarity search
def cached_embedding(text)
  cache_key = "embedding_#{Digest::SHA256.hexdigest(text)}"
  Rails.cache.fetch(cache_key, expires_in: 1.day) do
    RubyLLM.embed(text)
  end
end
```

## Testing Strategies

### Test Setup
```ruby
# In test_helper.rb or spec_helper.rb
RubyLLM.configure do |config|
  config.openai_api_key = "test-key"
  # Use mock responses in tests
end
```

### Mocking AI Responses
```ruby
class AiChatTest < ActionDispatch::IntegrationTest
  setup do
    # Mock AI responses
    allow(RubyLLM).to receive(:chat).and_return(
      double(ask: double(content: "Mocked AI response"))
    )
  end

  test "should create chat message" do
    post chat_messages_path(@chat), params: { 
      message: { content: "Hello AI" } 
    }
    
    assert_response :redirect
    assert_equal "Mocked AI response", @chat.messages.last.content
  end
end
```

## Security Considerations

### API Key Management
- Store all API keys in Rails credentials or environment variables
- Never commit API keys to version control
- Use different keys for different environments
- Rotate keys regularly

### Content Filtering
```ruby
class ChatMessage < ApplicationRecord
  before_save :check_content_policy

  private

  def check_content_policy
    # Implement custom content filtering
    if content.match?(/inappropriate_pattern/)
      errors.add(:content, "Content violates policy")
      throw :abort
    end
  end
end
```

## Important Considerations

### Version Compatibility
- Ruby LLM requires Rails 7.0+
- Database-backed model registry available from v1.7.0+
- ActiveStorage integration requires Rails 6.0+

### Rate Limiting
- Implement application-level rate limiting for API calls
- Use background jobs to handle API rate limits gracefully
- Consider implementing exponential backoff for retries

### Model Selection
- Different models have different capabilities (vision, audio, etc.)
- OpenRouter provides automatic fallback and cost optimization
- Consider model costs and response times for your use case

## Related Documentation
- [Chat Documentation](https://rubyllm.com/chat/) - Detailed conversation features
- [Tools Documentation](https://rubyllm.com/tools/) - Custom tool integration
- [Streaming Documentation](https://rubyllm.com/streaming/) - Real-time response handling
- [Image Generation](https://rubyllm.com/image-generation/) - AI image creation
- [OpenRouter API Docs](https://openrouter.ai/docs) - Provider-specific features