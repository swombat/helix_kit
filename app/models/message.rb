class Message < ApplicationRecord

  include Broadcastable
  include ObfuscatesId
  include JsonAttributes
  include SyncAuthorizable

  acts_as_message model: :ai_model, model_class: "AiModel", model_foreign_key: :ai_model_id

  # RubyLLM 1.10+ uses thinking_text column and returns a RubyLLM::Thinking object.
  # We override to maintain backwards compatibility with our string-based API.
  # Virtual attribute enables mass assignment (e.g., create!(thinking: "..."))
  attribute :thinking, :string

  def thinking
    thinking_text
  end

  def thinking=(value)
    # Handle both string values (our code) and RubyLLM::Thinking objects
    text_value = value.respond_to?(:text) ? value.text : value
    self.thinking_text = text_value
  end

  belongs_to :chat, touch: true
  belongs_to :user, optional: true
  belongs_to :agent, optional: true
  has_one :account, through: :chat

  has_many_attached :attachments do |attachable|
    # Small thumbnail for message list (fast loading)
    attachable.variant :thumb,
      resize_to_limit: [ 200, 200 ],
      format: :jpeg,
      saver: { quality: 70, strip: true }

    # Medium preview for lightbox (~500kb target)
    attachable.variant :preview,
      resize_to_limit: [ 1200, 1200 ],
      format: :jpeg,
      saver: { quality: 80, strip: true }
  end

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
      text/plain text/markdown text/csv text/html text/css text/xml
      application/json application/xml
      text/x-python application/x-python
      text/x-ruby application/x-ruby
      application/javascript text/javascript
      application/x-yaml text/yaml text/x-yaml
    ]
  }.freeze

  # Extensions to accept even if browser sends wrong/empty MIME type
  ACCEPTABLE_EXTENSIONS = %w[
    .md .markdown .txt .csv .json .xml .html .htm .css .js .ts .jsx .tsx
    .py .rb .yaml .yml .toml .ini .log .rst .tex .sh .bash .zsh
    .c .h .cpp .hpp .java .go .rs .swift .kt .scala .r .sql
  ].freeze

  MAX_FILE_SIZE = 50.megabytes

  MODERATION_THRESHOLD = 0.5

  validates :role, inclusion: { in: %w[user assistant system tool] }
  validates :content, presence: true, unless: -> { role.in?(%w[assistant tool]) || skip_content_validation }
  validate :acceptable_files
  validate :not_duplicate_of_last_message, on: :create

  scope :sorted, -> { order(created_at: :asc) }

  after_commit :queue_moderation, on: :create, if: :user_message_with_content?

  json_attributes :role, :content, :thinking, :thinking_preview, :user_name, :user_avatar_url,
                  :completed, :created_at_formatted, :created_at_hour, :streaming,
                  :files_json, :content_html, :tools_used, :tool_status,
                  :author_name, :author_type, :author_colour, :input_tokens, :output_tokens,
                  :editable, :deletable,
                  :moderation_flagged, :moderation_severity, :moderation_scores

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

  def author_name
    if agent.present?
      agent.name
    elsif user.present?
      user.full_name.presence || user.email_address.split("@").first
    else
      "System"
    end
  end

  def author_type
    if agent.present?
      "agent"
    elsif user.present?
      "human"
    else
      "system"
    end
  end

  def author_colour
    if agent.present?
      agent.colour
    elsif user.present?
      user.chat_colour
    end
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

  def thinking_preview
    return nil if thinking.blank?
    thinking.truncate(80, separator: " ")
  end

  def files_json
    return [] unless attachments.attached?

    url_helpers = Rails.application.routes.url_helpers

    attachments.map do |file|
      file_data = {
        id: file.id,
        filename: file.filename.to_s,
        content_type: file.content_type,
        byte_size: file.byte_size
      }

      # Generate URLs safely, handling test environment
      begin
        file_data[:url] = url_helpers.rails_blob_url(file, only_path: true)

        # Add variant URLs for images
        if file.content_type&.start_with?("image/")
          file_data[:thumb_url] = url_helpers.rails_representation_url(file.variant(:thumb), only_path: true)
          file_data[:preview_url] = url_helpers.rails_representation_url(file.variant(:preview), only_path: true)
        end
      rescue ArgumentError
        # In test environment, URL generation might fail due to missing host
        file_data[:url] = "/files/#{file.id}"
      end

      file_data
    end
  end

  def file_paths_for_llm
    return [] unless attachments.attached?

    attachments.filter_map do |file|
      # Skip files that don't exist (e.g., after database restore without storage)
      next unless file.blob.service.exist?(file.key)

      if file.blob.service.respond_to?(:path_for)
        # Disk service: return local path directly
        file.blob.service.path_for(file.key)
      else
        # Remote service (S3, etc.): download to temp file that persists beyond this block
        tempfile = Tempfile.new([ "attachment", File.extname(file.filename.to_s) ])
        tempfile.binmode
        file.download { |chunk| tempfile.write(chunk) }
        tempfile.rewind
        tempfile.path
        # Note: tempfile will be cleaned up by Ruby GC after the LLM API call completes
      end
    rescue Errno::ENOENT, ActiveStorage::FileNotFoundError
      # File disappeared between exist? check and access, skip it
      nil
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

  # Stream thinking updates for real-time display
  def stream_thinking(chunk)
    chunk = chunk.to_s
    return if chunk.empty?

    update_columns(thinking_text: (thinking_text.to_s + chunk))

    broadcast_marker(
      "Message:#{to_param}",
      {
        action: "thinking_update",
        chunk: chunk,
        id: to_param
      }
    )
  end

  # Stop streaming and finalize the message
  def stop_streaming
    Rails.logger.info "🛑 Stopping streaming for Message:#{to_param}, currently streaming: #{streaming?}"
    # Use update! to trigger callbacks and broadcast_refresh
    # Also clear tool_status since streaming is complete
    if streaming?
      update!(streaming: false, tool_status: nil)
      Rails.logger.info "🛑 Message #{to_param} updated to streaming: false"
    end

    # Broadcast streaming_end to both Message and Chat channels for reliability
    # The Chat channel broadcast ensures the frontend receives the event even if
    # the Message channel subscription hasn't been set up yet (race condition fix)
    broadcast_marker(
      "Message:#{to_param}",
      {
        action: "streaming_end",
        chunk: nil,
        id: to_param
      }
    )
    broadcast_marker(
      "Chat:#{chat.obfuscated_id}",
      {
        action: "streaming_end",
        chunk: nil,
        id: to_param
      }
    )
    Rails.logger.info "🛑 Broadcasted streaming_end to Message:#{to_param} and Chat:#{chat.obfuscated_id}"
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

  def owned_by?(user)
    role == "user" && (user_id == user&.id || user&.site_admin)
  end

  alias_method :editable_by?, :owned_by?
  alias_method :deletable_by?, :owned_by?

  def editable
    editable_by?(Current.user)
  end

  def deletable
    deletable_by?(Current.user)
  end

  def moderation_flagged?
    moderation_scores&.values&.any? { |score| score.to_f >= MODERATION_THRESHOLD }
  end

  alias_method :moderation_flagged, :moderation_flagged?

  def moderation_severity
    return unless moderation_flagged?
    moderation_scores.values.max.to_f >= 0.8 ? :high : :medium
  end

  private

  def user_message_with_content?
    role == "user" && content.present?
  end

  def queue_moderation
    ModerateMessageJob.perform_later(self)
  end

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
    return true if ACCEPTABLE_FILE_TYPES.values.flatten.include?(file.content_type)

    # Also accept files by extension (browsers often send wrong MIME types for text files)
    extension = File.extname(file.filename.to_s).downcase
    ACCEPTABLE_EXTENSIONS.include?(extension)
  end

  def not_duplicate_of_last_message
    return if content.blank? || chat.nil?

    # Only check against persisted messages (exclude any unsaved records in the association)
    # Use reorder to override any default scope ordering
    last_message = chat.messages.where.not(id: nil).reorder(created_at: :desc).first
    return if last_message.nil?

    if last_message.content == content
      errors.add(:base, :duplicate_message, message: "This message was already sent")
    end
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
