class Message < ApplicationRecord

  include Broadcastable
  include ObfuscatesId
  include JsonAttributes
  include SyncAuthorizable

  acts_as_message

  belongs_to :chat, touch: true
  belongs_to :user, optional: true
  has_one :account, through: :chat

  has_many_attached :files

  broadcasts_to :chat

  validates :role, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true, unless: -> { role == "assistant" }

  json_attributes :role, :content_html, :user_name, :user_avatar_url, :completed, :created_at_formatted, :created_at_hour, :streaming

  def completed?
    # User messages are always completed
    # Assistant messages are completed if they have content
    role == "user" || (role == "assistant" && content.present?)
  end

  alias_method :completed, :completed?

  def user_name
    user&.full_name
  end

  def user_avatar_url
    user&.avatar_url
  end

  def created_at_formatted
    created_at.strftime("%l:%M %p")
  end

  def created_at_hour
    created_at.strftime("%Y-%m-%d %l:00")
  end

  def content_html
    render_markdown
  end

  # Stream content updates for real-time AI response display
  def stream_content(chunk)
    # Use update_columns (plural) to update both at once, still bypassing callbacks
    update_columns(streaming: true, content: (content.to_s + chunk))

    # Broadcast to the chat's messages channel (which we know works)
    Rails.logger.debug "📡 Broadcasting streaming update to Chat:#{chat.obfuscated_id}:messages"
    ActionCable.server.broadcast(
      "Chat:#{chat.obfuscated_id}:messages",
      {
        action: "streaming_update",
        content: content,
        content_html: content_html,
        streaming: true,
        obfuscated_id: obfuscated_id
      }
    )
  end

  # Stop streaming and finalize the message
  def stop_streaming
    Rails.logger.debug "🛑 Stopping streaming for Message:#{obfuscated_id}"
    # Use update! to trigger callbacks and broadcast_refresh
    update!(streaming: false) if streaming?
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
