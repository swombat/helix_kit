# Telegram Bot API Integration Guide

This document provides comprehensive information for integrating with the Telegram Bot API in a Rails application.

## Overview

The Telegram Bot API allows you to create bots that can send and receive messages, handle commands, and interact with users through the Telegram messaging platform. The API provides an HTTPS interface for all bot operations with support for both webhooks and long polling for receiving updates.

- **API Documentation**: https://core.telegram.org/bots/api
- **Bot Features Guide**: https://core.telegram.org/bots/features
- **Bot Tutorial**: https://core.telegram.org/bots
- **Base URL**: `https://api.telegram.org/bot<token>/METHOD_NAME`

## 1. Creating and Configuring a Bot

### Using BotFather

All bot creation and configuration is done through BotFather, Telegram's official bot management tool.

#### Step 1: Create a New Bot

1. Open Telegram and search for [@BotFather](https://t.me/botfather)
2. Send `/newbot` command
3. Follow the prompts:
   - Enter a name for your bot (e.g., "My Rails Bot")
   - Enter a username ending in "bot" (e.g., "myrails_bot")
4. BotFather will provide your bot token

**Token Format**: `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`

**Critical**: The token is your bot's unique identifier and authentication credential. Anyone with this token has full control of your bot. Store it securely in Rails credentials, never commit to version control.

#### Step 2: Configure Bot Settings

BotFather provides commands for bot configuration:

```
/setdescription - Set bot description (shown before user starts bot)
/setabouttext - Set "About" text (shown in bot profile)
/setuserpic - Set bot profile picture
/setcommands - Define bot command list
/setdomain - Connect bot to a website
/deletebot - Delete your bot
```

#### Setting Bot Commands

Commands appear in the Telegram UI and provide autocomplete for users:

```
/setcommands

Then send command list:
start - Start the bot
help - Get help information
settings - Configure bot settings
```

**Command Format**:
- Commands can be up to 32 characters
- Use only Latin letters, numbers, and underscores
- Commands are case-insensitive but shown in lowercase

#### Command Scopes

You can set different commands for different contexts using BotFather:
- Default commands for all users
- Different commands for group admins
- Language-specific commands

### Bot Authentication

Include your bot token in all API requests via the URL:

```
https://api.telegram.org/bot<token>/METHOD_NAME
```

**Example**:
```ruby
token = Rails.application.credentials.telegram[:bot_token]
url = "https://api.telegram.org/bot#{token}/getMe"
```

## 2. Receiving Updates

Telegram provides two mutually exclusive methods for receiving updates: **getUpdates (long polling)** and **webhooks**. You cannot use both simultaneously.

### Method 1: Long Polling (getUpdates)

Simple to implement and works without HTTPS infrastructure. Good for development and small bots.

#### How It Works

The bot repeatedly requests updates from Telegram's servers. Updates are stored for 24 hours on Telegram's servers.

```ruby
def fetch_updates(offset = nil, timeout = 30)
  params = {
    offset: offset,
    timeout: timeout,
    allowed_updates: ['message', 'callback_query']
  }.compact

  response = HTTParty.get(
    "https://api.telegram.org/bot#{bot_token}/getUpdates",
    query: params
  )

  JSON.parse(response.body)
end
```

**Parameters**:
- `offset` (Integer): Identifier of first update to return. Use `last_update_id + 1` to acknowledge processed updates
- `limit` (Integer): Maximum number of updates to retrieve (1-100, default 100)
- `timeout` (Integer): Long polling timeout in seconds (0-50, default 0)
- `allowed_updates` (Array): Types of updates to receive (omit to receive all)

**Response Structure**:
```json
{
  "ok": true,
  "result": [
    {
      "update_id": 123456789,
      "message": {
        "message_id": 1,
        "from": {
          "id": 987654321,
          "is_bot": false,
          "first_name": "John",
          "username": "johndoe"
        },
        "chat": {
          "id": 987654321,
          "first_name": "John",
          "username": "johndoe",
          "type": "private"
        },
        "date": 1234567890,
        "text": "/start"
      }
    }
  ]
}
```

#### Polling Loop Example

```ruby
class TelegramPollingService
  def initialize
    @bot_token = Rails.application.credentials.telegram[:bot_token]
    @offset = nil
  end

  def start_polling
    loop do
      updates = fetch_updates(@offset)

      next unless updates['ok']

      updates['result'].each do |update|
        process_update(update)
        @offset = update['update_id'] + 1
      end
    rescue => e
      Rails.logger.error "Polling error: #{e.message}"
      sleep 5
    end
  end

  private

  def fetch_updates(offset)
    response = HTTParty.get(
      "https://api.telegram.org/bot#{@bot_token}/getUpdates",
      query: { offset: offset, timeout: 30 }
    )
    JSON.parse(response.body)
  end

  def process_update(update)
    # Handle update asynchronously
    TelegramUpdateJob.perform_later(update)
  end
end
```

### Method 2: Webhooks (Recommended for Production)

Telegram sends updates to your server via HTTPS POST requests. More efficient and real-time than polling.

#### Setting Up Webhooks

**Requirements**:
- HTTPS URL with valid SSL certificate
- Public IP or domain name
- One of these ports: 443, 80, 88, 8443
- Endpoint that responds with 200 OK quickly

```ruby
def set_webhook(webhook_url)
  response = HTTParty.post(
    "https://api.telegram.org/bot#{bot_token}/setWebhook",
    body: {
      url: webhook_url,
      allowed_updates: ['message', 'callback_query'],
      drop_pending_updates: true,
      secret_token: Rails.application.credentials.telegram[:webhook_secret]
    }
  )

  JSON.parse(response.body)
end
```

**Parameters**:
- `url` (String, required): HTTPS URL for webhook
- `certificate` (File): Upload public key certificate for self-signed cert
- `max_connections` (Integer): Maximum simultaneous HTTPS connections (1-100, default 40)
- `allowed_updates` (Array): Types of updates to receive
- `drop_pending_updates` (Boolean): Drop all pending updates on webhook set
- `secret_token` (String): Secret token to verify webhook requests (1-256 characters)

#### Webhook Security

Telegram sends a custom header with webhook requests:

```ruby
class TelegramWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def receive
    # Verify secret token
    secret_token = request.headers['X-Telegram-Bot-Api-Secret-Token']
    expected_token = Rails.application.credentials.telegram[:webhook_secret]

    unless secret_token == expected_token
      head :unauthorized
      return
    end

    # Parse webhook payload
    update = JSON.parse(request.body.read)

    # Process asynchronously
    TelegramUpdateJob.perform_later(update)

    # Respond immediately
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end
end
```

#### Webhook Management

```ruby
# Get current webhook info
def get_webhook_info
  response = HTTParty.get(
    "https://api.telegram.org/bot#{bot_token}/getWebhookInfo"
  )
  JSON.parse(response.body)
end

# Delete webhook (switch back to polling)
def delete_webhook
  response = HTTParty.post(
    "https://api.telegram.org/bot#{bot_token}/deleteWebhook",
    body: { drop_pending_updates: true }
  )
  JSON.parse(response.body)
end
```

### Capturing /start Commands

The `/start` command is sent when a user first opens your bot or clicks a deep link. It arrives as a regular message update.

```ruby
def process_update(update)
  return unless update['message']

  message = update['message']
  chat_id = message['chat']['id']
  text = message['text']

  if text&.start_with?('/start')
    handle_start_command(chat_id, message)
  end
end

def handle_start_command(chat_id, message)
  # Extract deep link parameter if present
  # /start becomes "/start"
  # /start param becomes "/start param"
  parts = message['text'].split(' ', 2)
  deep_link_param = parts[1] if parts.length > 1

  user_id = message['from']['id']
  username = message['from']['username']

  # Store chat_id for this user
  User.find_by(telegram_user_id: user_id)&.update(telegram_chat_id: chat_id)

  # Send welcome message
  send_message(
    chat_id,
    "Welcome #{message['from']['first_name']}!",
    parse_mode: 'HTML'
  )
end
```

### Deep Linking with /start

Deep links allow you to pass parameters to your bot when users click a link:

**Format**:
```
https://t.me/your_bot?start=PARAMETER
```

**Parameter Constraints**:
- A-Z, a-z, 0-9, underscore, and hyphen characters only
- Maximum 64 characters
- Base64url encoding recommended for binary data

**Example**:
```ruby
# Generate deep link
def generate_start_link(user_id, action)
  encoded_param = Base64.urlsafe_encode64("#{action}-#{user_id}")
  "https://t.me/#{bot_username}?start=#{encoded_param}"
end

# Parse deep link parameter
def parse_start_param(param)
  decoded = Base64.urlsafe_decode64(param)
  action, user_id = decoded.split('-', 2)
  { action: action, user_id: user_id }
rescue
  nil
end
```

## 3. Sending Messages

The `sendMessage` method is the primary way to send text messages to users.

### Basic sendMessage

```ruby
def send_message(chat_id, text, options = {})
  response = HTTParty.post(
    "https://api.telegram.org/bot#{bot_token}/sendMessage",
    headers: { 'Content-Type' => 'application/json' },
    body: {
      chat_id: chat_id,
      text: text
    }.merge(options).to_json
  )

  JSON.parse(response.body)
end
```

### Available Parameters

**Required**:
- `chat_id` (Integer or String): Target chat identifier
- `text` (String): Message text, 1-4096 characters

**Optional**:
- `parse_mode` (String): Text formatting mode (`HTML`, `Markdown`, or `MarkdownV2`)
- `entities` (Array): List of special entities (mentions, hashtags, etc.)
- `disable_web_page_preview` (Boolean): Disable link previews
- `disable_notification` (Boolean): Send silently
- `protect_content` (Boolean): Prevent forwarding/saving
- `reply_to_message_id` (Integer): Reply to a specific message
- `reply_markup` (Object): Inline keyboard, custom keyboard, or force reply

### Complete Example

```ruby
send_message(
  chat_id,
  "Hello! Click the button below:",
  parse_mode: 'HTML',
  disable_web_page_preview: true,
  reply_markup: {
    inline_keyboard: [
      [
        { text: 'Visit Website', url: 'https://example.com' },
        { text: 'Get Help', callback_data: 'help' }
      ]
    ]
  }
)
```

## 4. Understanding chat_id

The `chat_id` is the unique identifier for a chat and is crucial for sending messages.

### What is chat_id?

- **Private Chats**: Positive integer representing the user's unique ID
- **Groups**: Negative integer (e.g., -1234567890)
- **Supergroups**: Very large negative integer (e.g., -1001234567890)
- **Channels**: Can also use `@channelname` format

### Obtaining chat_id

**From Incoming Messages**:
```ruby
def extract_chat_id(update)
  if update['message']
    update['message']['chat']['id']
  elsif update['callback_query']
    update['callback_query']['message']['chat']['id']
  elsif update['inline_query']
    update['inline_query']['from']['id']
  end
end
```

**From User ID**:
The `from` field in messages contains the user's unique ID, which serves as `chat_id` for private messages:

```ruby
user_id = update['message']['from']['id']
# user_id and chat_id are the same for private chats
chat_id = user_id
```

### Storing chat_id

**Best Practice**: Store the chat_id when a user interacts with your bot:

```ruby
def store_user_chat_id(update)
  message = update['message']
  return unless message

  user_id = message['from']['id']
  chat_id = message['chat']['id']
  username = message['from']['username']

  user = User.find_or_initialize_by(telegram_user_id: user_id)
  user.update!(
    telegram_chat_id: chat_id,
    telegram_username: username
  )
end
```

### chat_id Considerations

- **Integer Size**: May exceed 32-bit integer limits, use 64-bit integers or strings
- **Persistence**: chat_id remains stable for a user/chat
- **Privacy**: Cannot be used to send messages unless user has started your bot first
- **Channels**: Requires bot to be an admin to send messages

## 5. Message Formatting

Telegram supports three formatting modes for text styling.

### HTML Mode (Recommended)

Most readable and easiest to work with. Similar to standard HTML.

**Supported Tags**:
- `<b>bold</b>` or `<strong>bold</strong>`
- `<i>italic</i>` or `<em>italic</em>`
- `<u>underline</u>` or `<ins>underline</ins>`
- `<s>strikethrough</s>` or `<strike>` or `<del>`
- `<code>monospace</code>`
- `<pre>preformatted block</pre>`
- `<pre><code class="language-python">code with syntax</code></pre>`
- `<a href="url">link text</a>`
- `<tg-spoiler>spoiler text</tg-spoiler>`
- `<blockquote>quote</blockquote>`

**Example**:
```ruby
text = <<~HTML
  <b>Welcome to our bot!</b>

  Here's what you can do:
  • Use <code>/help</code> for assistance
  • Check <a href="https://example.com">our website</a>
  • View <u>underlined text</u>

  <pre>Code example:
  def hello
    puts "Hello!"
  end</pre>
HTML

send_message(chat_id, text, parse_mode: 'HTML')
```

**Character Escaping**: Escape `<`, `>`, `&` when not using as tags:
- `&lt;` for `<`
- `&gt;` for `>`
- `&amp;` for `&`

### Markdown Mode (Legacy)

Original Markdown support, simpler but less flexible.

**Syntax**:
- `*bold*`
- `_italic_`
- `[link text](url)`
- `` `monospace` ``
- `` ```code block``` ``

**Example**:
```ruby
text = "*Welcome!*\n\nUse `/help` for more info."
send_message(chat_id, text, parse_mode: 'Markdown')
```

### MarkdownV2 Mode

Enhanced Markdown with more features but requires extensive escaping.

**Special Characters to Escape**: `_`, `*`, `[`, `]`, `(`, `)`, `~`, `` ` ``, `>`, `#`, `+`, `-`, `=`, `|`, `{`, `}`, `.`, `!`

**Syntax**:
- `*bold*` or `**bold**`
- `_italic_` or `__italic__`
- `__underline__`
- `~strikethrough~`
- `||spoiler||`
- `[link](url)`
- `` `code` ``
- `` ```language\ncode``` ``

**Example**:
```ruby
# Requires escaping special characters
text = "*Welcome\\!*\n\nUse `/help` for more info\\."
send_message(chat_id, text, parse_mode: 'MarkdownV2')
```

**Recommendation**: Use HTML mode for most cases due to simpler escaping rules.

### Links and Buttons

**Inline Links (HTML)**:
```ruby
text = 'Visit <a href="https://example.com">our website</a>'
send_message(chat_id, text, parse_mode: 'HTML')
```

**User Mentions**:
```ruby
# Mention by username
text = 'Hello @username!'

# Mention by ID (shows first name)
text = '<a href="tg://user?id=123456789">John</a>'
send_message(chat_id, text, parse_mode: 'HTML')
```

## 6. Inline Keyboards and Buttons

Inline keyboards appear directly below messages and trigger callbacks when pressed.

### Basic Inline Keyboard

```ruby
keyboard = {
  inline_keyboard: [
    [
      { text: 'Button 1', callback_data: 'btn1' },
      { text: 'Button 2', callback_data: 'btn2' }
    ],
    [
      { text: 'Button 3', callback_data: 'btn3' }
    ]
  ]
}

send_message(chat_id, 'Choose an option:', reply_markup: keyboard)
```

**Structure**:
- Array of button rows (each row is an array)
- Each button is a hash with specific fields
- `callback_data` limited to 1-64 bytes

### Button Types

#### Callback Buttons

Trigger a callback query when pressed:

```ruby
{ text: 'Click Me', callback_data: 'action_id' }
```

Handle callback:
```ruby
def process_callback_query(callback_query)
  chat_id = callback_query['message']['chat']['id']
  data = callback_query['data']
  callback_id = callback_query['id']

  # Process the callback
  case data
  when 'btn1'
    answer_text = 'You clicked Button 1'
  when 'btn2'
    answer_text = 'You clicked Button 2'
  end

  # Answer callback query (removes loading state)
  answer_callback_query(callback_id, answer_text)

  # Optionally edit the message
  edit_message_text(
    chat_id,
    callback_query['message']['message_id'],
    'You selected an option!'
  )
end

def answer_callback_query(callback_query_id, text = nil)
  HTTParty.post(
    "https://api.telegram.org/bot#{bot_token}/answerCallbackQuery",
    headers: { 'Content-Type' => 'application/json' },
    body: {
      callback_query_id: callback_query_id,
      text: text,
      show_alert: false
    }.to_json
  )
end
```

#### URL Buttons

Open a web page:

```ruby
{ text: 'Visit Website', url: 'https://example.com' }
```

#### Web App Buttons

Launch a Telegram Mini App:

```ruby
{ text: 'Open App', web_app: { url: 'https://app.example.com' } }
```

#### Login Buttons

Telegram Login Widget:

```ruby
{
  text: 'Login',
  login_url: {
    url: 'https://example.com/auth/telegram',
    forward_text: 'Login to Example',
    request_write_access: true
  }
}
```

#### Switch Inline Buttons

Switch to inline mode:

```ruby
{ text: 'Share', switch_inline_query: 'Check this out!' }
```

### Editing Messages with Keyboards

```ruby
def edit_message_text(chat_id, message_id, new_text, keyboard = nil)
  body = {
    chat_id: chat_id,
    message_id: message_id,
    text: new_text
  }
  body[:reply_markup] = keyboard if keyboard

  HTTParty.post(
    "https://api.telegram.org/bot#{bot_token}/editMessageText",
    headers: { 'Content-Type' => 'application/json' },
    body: body.to_json
  )
end
```

### Custom Keyboards

Custom keyboards replace the default keyboard at the bottom of the screen:

```ruby
keyboard = {
  keyboard: [
    ['Option 1', 'Option 2'],
    ['Option 3']
  ],
  resize_keyboard: true,
  one_time_keyboard: true
}

send_message(chat_id, 'Choose:', reply_markup: keyboard)
```

**Remove Custom Keyboard**:
```ruby
send_message(
  chat_id,
  'Keyboard removed',
  reply_markup: { remove_keyboard: true }
)
```

## 7. Rate Limits and Best Practices

### Official Rate Limits

Telegram doesn't publish exact rate limits, but these are generally observed:

**Message Sending**:
- **Private chats**: ~30 messages per second across all chats
- **Same chat**: ~1 message per second to avoid flooding
- **Group chats**: ~20 messages per minute
- **Broadcasts**: Use with caution, spread over time

**API Calls**:
- General limit: ~30 requests per second
- May vary based on method and bot usage patterns

### HTTP Response Codes

**429 Too Many Requests**:
Telegram returns this when you exceed rate limits, along with a `retry_after` parameter.

```ruby
def make_api_request(method, params)
  url = "https://api.telegram.org/bot#{bot_token}/#{method}"

  response = HTTParty.post(url,
    headers: { 'Content-Type' => 'application/json' },
    body: params.to_json
  )

  result = JSON.parse(response.body)

  if response.code == 429
    retry_after = result.dig('parameters', 'retry_after') || 30
    Rails.logger.warn "Rate limited, retry after #{retry_after}s"
    sleep retry_after
    return make_api_request(method, params)
  end

  unless result['ok']
    raise TelegramApiError, result['description']
  end

  result
end
```

### Best Practices

#### 1. Implement Request Queuing

```ruby
class TelegramMessageQueue
  def initialize
    @queue = Queue.new
    start_worker
  end

  def enqueue(chat_id, text, options = {})
    @queue.push([chat_id, text, options])
  end

  private

  def start_worker
    Thread.new do
      loop do
        chat_id, text, options = @queue.pop
        send_message(chat_id, text, options)
        sleep 0.1 # Rate limiting
      end
    end
  end
end
```

#### 2. Respond to Callbacks Quickly

Always call `answerCallbackQuery` within a few seconds to remove the loading state.

#### 3. Handle Errors Gracefully

```ruby
def send_message_safely(chat_id, text)
  send_message(chat_id, text)
rescue TelegramApiError => e
  case e.message
  when /bot was blocked/
    # User blocked the bot, remove from active users
    User.find_by(telegram_chat_id: chat_id)&.update(bot_blocked: true)
  when /chat not found/
    # Chat no longer exists
    Rails.logger.warn "Chat #{chat_id} not found"
  else
    raise
  end
end
```

#### 4. Use Webhooks for Production

Webhooks are more efficient and real-time than polling.

#### 5. Process Updates Asynchronously

```ruby
class TelegramUpdateJob < ApplicationJob
  queue_as :telegram

  def perform(update)
    # Process update without blocking webhook response
    TelegramBot.process_update(update)
  end
end
```

#### 6. Respect User Privacy

- Only store necessary data
- Provide data deletion commands
- Handle `/start` and `/stop` appropriately
- Don't spam users

#### 7. Message Length Limits

- Text messages: 4,096 characters maximum
- Caption for media: 1,024 characters
- Split long messages:

```ruby
def send_long_message(chat_id, text)
  text.scan(/.{1,4096}/m).each do |chunk|
    send_message(chat_id, chunk)
    sleep 0.1
  end
end
```

## 8. Available Ruby Gems

### telegram-bot-ruby

A lightweight Ruby wrapper for the Telegram Bot API.

**Installation**:
```ruby
# Gemfile
gem 'telegram-bot-ruby'
```

**Basic Usage**:
```ruby
require 'telegram/bot'

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Hello, #{message.from.first_name}!"
      )
    when '/help'
      bot.api.send_message(
        chat_id: message.chat.id,
        text: 'How can I help you?'
      )
    end
  end
end
```

**Features**:
- Clean API wrapper with snake_case methods
- Automatic camelCase conversion
- Type support with dry-struct
- Support for all Bot API methods
- Webhook support

**GitHub**: https://github.com/atipugin/telegram-bot-ruby
**RubyGems**: https://rubygems.org/gems/telegram-bot-ruby

### telegram-bot (Rails Integration)

A more comprehensive gem with Rails integration, controllers, and session management.

**Installation**:
```ruby
# Gemfile
gem 'telegram-bot'
```

**Rails Setup**:
```ruby
# config/secrets.yml
development:
  telegram:
    bot:
      token: YOUR_BOT_TOKEN
      username: your_bot_username
```

**Controller Example**:
```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  def start!(data = nil)
    respond_with :message, text: "Hello, #{from['first_name']}!"
  end

  def help!
    respond_with :message, text: 'Available commands: /start, /help'
  end

  def message(message)
    respond_with :message, text: "You said: #{message['text']}"
  end

  def callback_query(data)
    answer_callback_query "Received: #{data}"
  end
end
```

**Routes**:
```ruby
# config/routes.rb
telegram_webhook TelegramWebhookController
```

**Features**:
- Rails integration with automatic routing
- Controller-based message handling
- Session management (Redis, file store)
- Message context for multi-step interactions
- Callback query routing
- Inline query support

**GitHub**: https://github.com/telegram-bot-rb/telegram-bot

### Choosing a Gem

**Use telegram-bot-ruby if**:
- You want a lightweight wrapper
- You're building a simple bot
- You prefer manual control
- You're not using Rails

**Use telegram-bot if**:
- You're using Rails
- You need session management
- You want controller-based routing
- You need complex conversation flows

## 9. Complete Rails Integration Example

### Model Setup

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Telegram fields
  # telegram_user_id: integer (bigint)
  # telegram_chat_id: integer (bigint)
  # telegram_username: string
  # telegram_first_name: string
  # telegram_last_name: string
  # bot_blocked: boolean, default: false
  # telegram_connected_at: datetime

  def telegram_connected?
    telegram_chat_id.present?
  end

  def self.find_by_telegram(telegram_user_id)
    find_by(telegram_user_id: telegram_user_id)
  end
end
```

### Migration

```ruby
class AddTelegramFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :telegram_user_id, :bigint
    add_column :users, :telegram_chat_id, :bigint
    add_column :users, :telegram_username, :string
    add_column :users, :telegram_first_name, :string
    add_column :users, :telegram_last_name, :string
    add_column :users, :bot_blocked, :boolean, default: false
    add_column :users, :telegram_connected_at, :datetime

    add_index :users, :telegram_user_id, unique: true
    add_index :users, :telegram_chat_id
  end
end
```

### Service Object

```ruby
# app/services/telegram_bot_service.rb
class TelegramBotService
  BASE_URL = 'https://api.telegram.org/bot'

  def initialize
    @token = Rails.application.credentials.telegram[:bot_token]
    @base_url = "#{BASE_URL}#{@token}"
  end

  def send_message(chat_id, text, options = {})
    make_request('sendMessage', {
      chat_id: chat_id,
      text: text
    }.merge(options))
  end

  def send_message_with_keyboard(chat_id, text, buttons)
    send_message(chat_id, text,
      reply_markup: { inline_keyboard: buttons }
    )
  end

  def edit_message(chat_id, message_id, text, keyboard = nil)
    params = {
      chat_id: chat_id,
      message_id: message_id,
      text: text
    }
    params[:reply_markup] = keyboard if keyboard

    make_request('editMessageText', params)
  end

  def answer_callback_query(callback_query_id, text = nil, show_alert: false)
    make_request('answerCallbackQuery', {
      callback_query_id: callback_query_id,
      text: text,
      show_alert: show_alert
    }.compact)
  end

  def set_webhook(url, secret_token = nil)
    make_request('setWebhook', {
      url: url,
      secret_token: secret_token,
      allowed_updates: ['message', 'callback_query']
    }.compact)
  end

  def delete_webhook
    make_request('deleteWebhook', drop_pending_updates: true)
  end

  private

  def make_request(method, params)
    response = HTTParty.post(
      "#{@base_url}/#{method}",
      headers: { 'Content-Type' => 'application/json' },
      body: params.to_json,
      timeout: 30
    )

    result = JSON.parse(response.body)

    handle_error(result) unless result['ok']

    result['result']
  rescue HTTParty::Error, Timeout::Error => e
    Rails.logger.error "Telegram API error: #{e.message}"
    nil
  end

  def handle_error(result)
    error_code = result['error_code']
    description = result['description']

    case error_code
    when 429
      retry_after = result.dig('parameters', 'retry_after') || 30
      sleep retry_after
      raise TelegramRetryError, "Rate limited, retry after #{retry_after}s"
    when 403
      raise TelegramBlockedError, description
    else
      raise TelegramApiError, "#{error_code}: #{description}"
    end
  end
end

class TelegramApiError < StandardError; end
class TelegramRetryError < TelegramApiError; end
class TelegramBlockedError < TelegramApiError; end
```

### Webhook Controller

```ruby
# app/controllers/telegram_webhooks_controller.rb
class TelegramWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def receive
    unless valid_secret_token?
      head :unauthorized
      return
    end

    update = JSON.parse(request.body.read)
    TelegramUpdateJob.perform_later(update)

    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def valid_secret_token?
    token = request.headers['X-Telegram-Bot-Api-Secret-Token']
    expected = Rails.application.credentials.telegram[:webhook_secret]
    ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected.to_s)
  end
end
```

### Update Processing Job

```ruby
# app/jobs/telegram_update_job.rb
class TelegramUpdateJob < ApplicationJob
  queue_as :telegram

  def perform(update)
    @bot = TelegramBotService.new
    @update = update

    if update['message']
      process_message(update['message'])
    elsif update['callback_query']
      process_callback_query(update['callback_query'])
    end
  end

  private

  def process_message(message)
    chat_id = message['chat']['id']
    text = message['text']
    from = message['from']

    # Store or update user
    user = User.find_or_initialize_by(telegram_user_id: from['id'])
    user.update!(
      telegram_chat_id: chat_id,
      telegram_username: from['username'],
      telegram_first_name: from['first_name'],
      telegram_last_name: from['last_name'],
      telegram_connected_at: Time.current,
      bot_blocked: false
    )

    # Handle commands
    case text
    when /^\/start/
      handle_start(chat_id, text, user)
    when '/help'
      handle_help(chat_id, user)
    when '/settings'
      handle_settings(chat_id, user)
    else
      handle_text_message(chat_id, text, user)
    end
  end

  def process_callback_query(callback_query)
    chat_id = callback_query['message']['chat']['id']
    data = callback_query['data']
    callback_id = callback_query['id']
    message_id = callback_query['message']['message_id']

    # Route callback to appropriate handler
    case data
    when /^settings:/
      handle_settings_callback(chat_id, message_id, data, callback_id)
    when /^action:/
      handle_action_callback(chat_id, message_id, data, callback_id)
    end

    # Always answer callback query
    @bot.answer_callback_query(callback_id)
  end

  def handle_start(chat_id, text, user)
    # Extract deep link parameter
    param = text.split(' ', 2)[1]

    welcome_text = <<~TEXT
      Welcome #{user.telegram_first_name}!

      Your Telegram account is now connected.

      Use /help to see available commands.
    TEXT

    @bot.send_message(chat_id, welcome_text, parse_mode: 'HTML')
  end

  def handle_help(chat_id, user)
    help_text = <<~TEXT
      <b>Available Commands:</b>

      /start - Start the bot
      /help - Show this help message
      /settings - Configure your preferences

      For more information, visit our website.
    TEXT

    @bot.send_message(chat_id, help_text, parse_mode: 'HTML')
  end

  def handle_settings(chat_id, user)
    keyboard = [
      [
        { text: 'Enable Notifications', callback_data: 'settings:notifications:on' },
        { text: 'Disable Notifications', callback_data: 'settings:notifications:off' }
      ],
      [
        { text: 'Disconnect Bot', callback_data: 'settings:disconnect' }
      ]
    ]

    @bot.send_message_with_keyboard(
      chat_id,
      '<b>Settings</b>\n\nChoose an option:',
      keyboard
    )
  end

  def handle_text_message(chat_id, text, user)
    @bot.send_message(
      chat_id,
      "You said: #{text}"
    )
  end

  def handle_settings_callback(chat_id, message_id, data, callback_id)
    action = data.split(':').last

    case action
    when 'on'
      @bot.answer_callback_query(callback_id, 'Notifications enabled')
      @bot.edit_message(chat_id, message_id, 'Notifications are now enabled')
    when 'off'
      @bot.answer_callback_query(callback_id, 'Notifications disabled')
      @bot.edit_message(chat_id, message_id, 'Notifications are now disabled')
    when 'disconnect'
      @bot.answer_callback_query(callback_id, 'Bot disconnected')
      @bot.edit_message(chat_id, message_id, 'Bot has been disconnected')
    end
  end
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  post 'telegram/webhook', to: 'telegram_webhooks#receive'
end
```

### Initializer

```ruby
# config/initializers/telegram.rb
if Rails.env.production?
  # Set webhook in production
  webhook_url = "#{ENV['APP_URL']}/telegram/webhook"
  secret_token = Rails.application.credentials.telegram[:webhook_secret]

  TelegramBotService.new.set_webhook(webhook_url, secret_token)
end
```

### Sending Notifications to Users

```ruby
# app/services/telegram_notification_service.rb
class TelegramNotificationService
  def initialize
    @bot = TelegramBotService.new
  end

  def notify_user(user, message, options = {})
    return unless user.telegram_connected?
    return if user.bot_blocked?

    @bot.send_message(user.telegram_chat_id, message, options)
  rescue TelegramBlockedError
    user.update(bot_blocked: true)
  end

  def broadcast_to_users(users, message)
    users.find_each do |user|
      notify_user(user, message)
      sleep 0.1 # Rate limiting
    end
  end
end

# Usage
notifier = TelegramNotificationService.new
notifier.notify_user(
  current_user,
  '<b>New Message!</b>\n\nYou have a new notification.',
  parse_mode: 'HTML'
)
```

## 10. Security Considerations

### Token Storage

**Never commit tokens to version control**:

```ruby
# config/credentials.yml.enc (encrypted)
telegram:
  bot_token: "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
  webhook_secret: "your_webhook_secret_here"
```

Access in code:
```ruby
Rails.application.credentials.telegram[:bot_token]
```

### Webhook Security

1. **Use Secret Token**: Set and verify `X-Telegram-Bot-Api-Secret-Token` header
2. **HTTPS Only**: Never use HTTP for webhooks
3. **Validate Payloads**: Check structure and content
4. **Rate Limiting**: Implement rate limiting on webhook endpoint
5. **IP Filtering**: Optionally restrict to Telegram's IP ranges

### User Data Privacy

1. **Minimal Data Storage**: Only store necessary fields
2. **Encryption**: Consider encrypting sensitive data
3. **Data Deletion**: Implement user data deletion
4. **Consent**: Obtain explicit user consent
5. **Logging**: Don't log sensitive user data

### Bot Permissions

1. **Privacy Mode**: Enable by default (bot only sees commands in groups)
2. **Minimal Scopes**: Only request necessary permissions
3. **Group Settings**: Configure appropriate group permissions via BotFather

## 11. Testing

### VCR for API Testing

```ruby
# test/services/telegram_bot_service_test.rb
require 'test_helper'

class TelegramBotServiceTest < ActiveSupport::TestCase
  setup do
    @service = TelegramBotService.new
    @chat_id = 123456789
  end

  test "sends message successfully" do
    VCR.use_cassette('telegram/send_message') do
      result = @service.send_message(@chat_id, 'Test message')
      assert result.present?
      assert_equal 'Test message', result['text']
    end
  end

  test "handles rate limiting" do
    VCR.use_cassette('telegram/rate_limit') do
      assert_raises(TelegramRetryError) do
        @service.send_message(@chat_id, 'Test')
      end
    end
  end
end
```

### Webhook Testing

```ruby
# test/controllers/telegram_webhooks_controller_test.rb
require 'test_helper'

class TelegramWebhooksControllerTest < ActionDispatch::IntegrationTest
  test "rejects requests without secret token" do
    post telegram_webhook_url, params: {}, as: :json
    assert_response :unauthorized
  end

  test "processes valid webhook" do
    update = {
      update_id: 123,
      message: {
        message_id: 1,
        from: { id: 123, first_name: 'Test' },
        chat: { id: 123, type: 'private' },
        text: '/start'
      }
    }

    headers = {
      'X-Telegram-Bot-Api-Secret-Token' =>
        Rails.application.credentials.telegram[:webhook_secret]
    }

    assert_enqueued_with(job: TelegramUpdateJob) do
      post telegram_webhook_url,
        params: update.to_json,
        headers: headers
    end

    assert_response :ok
  end
end
```

### Manual Testing with curl

```bash
# Send message
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -H "Content-Type: application/json" \
  -d '{
    "chat_id": 123456789,
    "text": "Test message",
    "parse_mode": "HTML"
  }'

# Set webhook
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com/telegram/webhook",
    "secret_token": "your_secret"
  }'

# Get webhook info
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
```

## 12. Common Patterns and Solutions

### Multi-Step Conversations

Track conversation state to handle multi-step interactions:

```ruby
class TelegramConversationService
  def initialize(user)
    @user = user
  end

  def start_conversation(state)
    @user.update(telegram_conversation_state: state.to_json)
  end

  def get_state
    JSON.parse(@user.telegram_conversation_state || '{}')
  end

  def update_state(data)
    current = get_state
    @user.update(telegram_conversation_state: current.merge(data).to_json)
  end

  def end_conversation
    @user.update(telegram_conversation_state: nil)
  end
end

# In update processor
def handle_text_message(chat_id, text, user)
  conversation = TelegramConversationService.new(user)
  state = conversation.get_state

  case state['step']
  when 'awaiting_name'
    conversation.update_state(name: text, step: 'awaiting_email')
    @bot.send_message(chat_id, 'Great! Now enter your email:')
  when 'awaiting_email'
    # Process and complete
    process_registration(state['name'], text)
    conversation.end_conversation
    @bot.send_message(chat_id, 'Registration complete!')
  end
end
```

### Message Pagination

Split long content across multiple messages with navigation:

```ruby
def send_paginated_list(chat_id, items, page: 1, per_page: 5)
  total_pages = (items.count / per_page.to_f).ceil
  page = [[page, 1].max, total_pages].min

  offset = (page - 1) * per_page
  page_items = items[offset, per_page]

  text = page_items.map.with_index(offset + 1) do |item, i|
    "#{i}. #{item}"
  end.join("\n")

  keyboard = []
  keyboard << [{ text: '« Previous', callback_data: "page:#{page - 1}" }] if page > 1
  keyboard << [{ text: 'Next »', callback_data: "page:#{page + 1}" }] if page < total_pages

  @bot.send_message_with_keyboard(
    chat_id,
    "#{text}\n\nPage #{page}/#{total_pages}",
    keyboard
  )
end
```

### Broadcasting with Rate Limiting

```ruby
class TelegramBroadcastService
  DELAY_BETWEEN_MESSAGES = 0.1 # seconds

  def broadcast(users, message, options = {})
    users.find_in_batches(batch_size: 100) do |batch|
      batch.each do |user|
        next unless user.telegram_connected?
        next if user.bot_blocked?

        begin
          TelegramBotService.new.send_message(
            user.telegram_chat_id,
            message,
            options
          )
        rescue TelegramBlockedError
          user.update(bot_blocked: true)
        rescue TelegramApiError => e
          Rails.logger.error "Broadcast error for user #{user.id}: #{e.message}"
        end

        sleep DELAY_BETWEEN_MESSAGES
      end
    end
  end
end
```

## 13. Troubleshooting

### Common Errors

**"Unauthorized"**:
- Check bot token is correct
- Verify token hasn't been reset via BotFather

**"Bad Request: chat not found"**:
- User has deleted the chat with the bot
- Invalid chat_id format
- Mark user as inactive

**"Forbidden: bot was blocked by the user"**:
- User blocked the bot
- Update user record: `bot_blocked: true`

**"Bad Request: message is too long"**:
- Message exceeds 4,096 characters
- Split into multiple messages

**"Bad Request: can't parse entities"**:
- Invalid HTML/Markdown syntax
- Check for unescaped special characters

### Debugging Tips

1. **Test with BotFather**: Use @BotFather to verify bot configuration
2. **Check Webhook Info**: Use `getWebhookInfo` to see webhook status
3. **Monitor Logs**: Log all API responses during development
4. **Use getMe**: Verify bot token with `getMe` endpoint
5. **Test in Private Chat**: Start with private chats before groups

## 14. Additional Resources

### Official Documentation

- [Telegram Bot API](https://core.telegram.org/bots/api) - Complete API reference
- [Bot Features](https://core.telegram.org/bots/features) - Comprehensive features guide
- [Bots Introduction](https://core.telegram.org/bots) - Getting started tutorial
- [BotFather](https://t.me/botfather) - Bot creation and management

### Ruby Libraries

- [telegram-bot-ruby](https://github.com/atipugin/telegram-bot-ruby) - Lightweight API wrapper
- [telegram-bot](https://github.com/telegram-bot-rb/telegram-bot) - Rails integration with controllers

### Community Resources

- [Telegram Bot API Updates](https://core.telegram.org/bots/api#recent-changes) - API changelog
- [Telegram Bot Platform](https://t.me/BotNews) - Official news channel
- [Community Examples](https://core.telegram.org/bots/samples) - Code samples in various languages

### Tools

- [Telegram Bot API Testing](https://api.telegram.org/bot<token>/getMe) - Test bot connection
- [ngrok](https://ngrok.com/) - Tunnel for local webhook testing
- [Webhook Test Tool](https://webhook.site/) - Debug webhook payloads

## 15. Implementation Checklist

When implementing Telegram bot integration:

- [ ] Create bot via @BotFather and obtain token
- [ ] Store token securely in Rails credentials
- [ ] Decide on polling vs webhooks (webhooks recommended)
- [ ] Set up webhook endpoint with secret token verification
- [ ] Create database migrations for telegram fields
- [ ] Implement TelegramBotService for API interactions
- [ ] Create webhook controller and update processing job
- [ ] Handle /start command and store user chat_id
- [ ] Implement message sending with rate limiting
- [ ] Add inline keyboards for interactive features
- [ ] Handle callback queries
- [ ] Implement error handling for blocked users
- [ ] Add notification service for sending updates
- [ ] Test webhook security
- [ ] Test rate limiting behavior
- [ ] Document bot commands via BotFather
- [ ] Set up monitoring and logging
- [ ] Implement user data deletion
- [ ] Test in production environment

---

**Last Updated**: January 29, 2026
**API Documentation Version**: Latest
**Document Version**: 1.0
