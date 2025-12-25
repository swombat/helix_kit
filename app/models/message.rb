class Message < ApplicationRecord

  include Broadcastable
  include ObfuscatesId
  include JsonAttributes
  include SyncAuthorizable

  acts_as_message model: :ai_model, model_class: "AiModel", model_foreign_key: :ai_model_id

  belongs_to :chat, touch: true
  belongs_to :user, optional: true
  has_one :account, through: :chat

  has_many_attached :attachments

  attr_accessor :skip_content_validation

  broadcasts_to :chat

  ACCEPTABLE_FILE_TYPES = {
    images: %w[image/png image/jpeg image/jpg image/gif image/webp image/bmp],
    audio: %w[audio/mpeg audio/wav audio/m4a audio/ogg audio/flac],
    video: %w[video/mp4 video/quicktime video/x-msvideo video/webm],
    documents: %w[
      application/pdf
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      text/plain text/markdown text/csv
    ]
  }.freeze

  MAX_FILE_SIZE = 50.megabytes

  validates :role, inclusion: { in: %w[user assistant system tool] }
  validates :content, presence: true, unless: -> { role.in?(%w[assistant tool]) || skip_content_validation }
  validate :acceptable_files

  scope :sorted, -> { order(created_at: :asc) }

  json_attributes :role, :content, :user_name, :user_avatar_url, :completed,
                  :created_at_formatted, :created_at_hour, :streaming, :files_json, :content_html, :tools_used, :tool_status

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

  def files_json
    return [] unless attachments.attached?

    attachments.map do |file|
      file_data = {
        id: file.id,
        filename: file.filename.to_s,
        content_type: file.content_type,
        byte_size: file.byte_size
      }

      # Generate URL safely, handling test environment
      begin
        file_data[:url] = Rails.application.routes.url_helpers.url_for(file)
      rescue ArgumentError => e
        # In test environment, URL generation might fail due to missing host
        file_data[:url] = "/files/#{file.id}"
      end

      file_data
    end
  end

  def file_paths_for_llm
    return [] unless attachments.attached?

    attachments.map do |file|
      if ActiveStorage::Blob.service.respond_to?(:path_for)
        ActiveStorage::Blob.service.path_for(file.key)
      else
        file.open { |f| f.path }
      end
    end
  end

  # Stream content updates for real-time AI response display
  def stream_content(chunk)
    chunk = chunk.to_s
    return if chunk.empty?

    # Use update_columns (plural) to update both at once, still bypassing callbacks
    update_columns(streaming: true, content: (content.to_s + chunk))

    # Broadcast to the chat's messages channel (which we know works)
    Rails.logger.debug "📡 Broadcasting streaming update to Message:#{to_param}:stream (length: #{content.to_s.length}, chunk: #{chunk})"
    broadcast_marker(
      "Message:#{to_param}",
      {
        action: "streaming_update",
        chunk: chunk,
        id: to_param
      }
    )
  end

  # Stop streaming and finalize the message
  def stop_streaming
    Rails.logger.debug "🛑 Stopping streaming for Message:#{to_param}"
    # Use update! to trigger callbacks and broadcast_refresh
    # Also clear tool_status since streaming is complete
    update!(streaming: false, tool_status: nil) if streaming?
    broadcast_marker(
      "Message:#{to_param}",
      {
        action: "streaming_end",
        chunk: nil,
        id: to_param
      }
    )
  end

  # Update tool call status for real-time UI display
  def broadcast_tool_call(tool_name:, tool_args:)
    status = format_tool_status(tool_name, tool_args)
    Rails.logger.debug "🔧 Updating tool status: #{status}"
    update!(tool_status: status)
  end

  # Simple helper for checking tool usage
  def used_tools?
    tools_used.present? && tools_used.any?
  end

  private

  def format_tool_status(tool_name, tool_args)
    case tool_name
    when "WebFetchTool", "web_fetch"
      url = tool_args[:url] || tool_args["url"]
      "Fetching #{truncate_url(url)}"
    when "WebSearchTool", "web_search"
      query = tool_args[:query] || tool_args["query"]
      "Searching for \"#{query}\""
    else
      "Using #{tool_name.to_s.underscore.humanize.downcase}"
    end
  end

  def truncate_url(url)
    return url if url.nil? || url.length <= 50
    "#{url[0..47]}..."
  end

  def acceptable_files
    return unless attachments.attached?

    attachments.each do |file|
      unless acceptable_file_type?(file)
        errors.add(:attachments, "#{file.filename}: file type not supported")
      end

      if file.byte_size > MAX_FILE_SIZE
        errors.add(:attachments, "#{file.filename}: must be less than #{MAX_FILE_SIZE / 1.megabyte}MB")
      end
    end
  end

  def acceptable_file_type?(file)
    ACCEPTABLE_FILE_TYPES.values.flatten.include?(file.content_type)
  end

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
