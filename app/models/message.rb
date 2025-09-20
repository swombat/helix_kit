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
  validates :content, presence: true, unless: -> { role == "assistant" }

  json_attributes :role, :content_html, :user_name, :user_avatar_url, :completed, :created_at_formatted, :created_at_hour

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
