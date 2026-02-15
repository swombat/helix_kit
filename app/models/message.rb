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

  has_one_attached :audio_recording

  attr_accessor :skip_content_validation

  broadcasts_to :chat

  ACCEPTABLE_FILE_TYPES = {
    images: %w[image/png image/jpeg image/jpg image/gif image/webp image/bmp],
    audio: %w[audio/mpeg audio/wav audio/m4a audio/ogg audio/flac audio/webm],
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

  # Known tool result type values that should be silently stripped (not recovered or error-recorded)
  TOOL_RESULT_TYPES = %w[
    github_commits github_diff github_file
    board board_created board_updated board_list board_deleted board_restored
    deleted_board_list active_board_cleared active_board_set
    config
    search_results fetched_page redirect
    consolidated updated deleted protected refinement_complete
  ].freeze

  MODERATION_THRESHOLD = 0.5

  validates :role, inclusion: { in: %w[user assistant system tool] }
  validates :content, presence: true, unless: -> { role.in?(%w[assistant tool]) || skip_content_validation }
  validate :acceptable_files
  validate :not_duplicate_of_last_message, on: :create

  scope :sorted, -> { order(created_at: :asc) }

  after_commit :queue_moderation, on: :create, if: :user_message_with_content?
  after_create :reopen_all_agents_for_initiation, if: :human_message_in_group_chat?

  json_attributes :role, :content, :thinking, :thinking_preview, :user_name, :user_avatar_url,
                  :completed, :created_at_formatted, :created_at_hour, :streaming,
                  :files_json, :content_html, :tools_used, :tool_status,
                  :author_name, :author_type, :author_colour, :input_tokens, :output_tokens,
                  :editable, :deletable,
                  :moderation_flagged, :moderation_severity, :moderation_scores,
                  :fixable,
                  :audio_source, :audio_url

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

  def audio_url
    return unless audio_recording.attached?

    Rails.application.routes.url_helpers.rails_blob_url(audio_recording, only_path: true)
  rescue ArgumentError
    nil
  end

  def file_paths_for_llm
    return [] unless attachments.attached?

    attachments.filter_map { |file| resolve_attachment_path(file) }
  end

  def audio_path_for_llm
    resolve_attachment_path(audio_recording)
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

  # Pattern for hallucinated timestamps like [2026-01-25 18:48]
  TIMESTAMP_PATTERN = /\A\s*\[\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\]\s*/

  # Detects if this is an assistant message with a hallucinated timestamp at the start
  def has_timestamp_prefix?
    return false unless role == "assistant" && content.present?
    content.match?(TIMESTAMP_PATTERN)
  end

  # Detects if this is an assistant message with JSON at the start
  # (indicates a potential hallucinated tool call)
  def has_json_prefix?
    return false unless role == "assistant" && content.present?
    # Check for JSON directly or after a timestamp
    stripped = content.gsub(TIMESTAMP_PATTERN, "")
    stripped.strip.start_with?("{")
  end

  # Returns true if this message can be fixed (has timestamp or JSON prefix, and an agent)
  def fixable
    return false unless role == "assistant" && agent.present?
    has_timestamp_prefix? || has_json_prefix?
  end

  # Strips leading timestamp from content (class method for use in jobs)
  def self.strip_leading_timestamp(text)
    return text if text.blank?
    text.gsub(TIMESTAMP_PATTERN, "")
  end

  # Attempts to fix hallucinated content by:
  # 1. Stripping hallucinated timestamps from the start
  # 2. Extracting JSON blocks from the start of the message
  # 3. Attempting to execute each as a tool call via tool-specific recovery
  # 4. Recording results (success or error) as messages before this one
  # 5. Stripping the timestamp/JSON from this message's content
  def fix_hallucinated_tool_calls!
    raise "Not an assistant message" unless role == "assistant"
    raise "Nothing to fix" unless fixable
    raise "Cannot fix: message has no agent" unless agent.present?

    transaction do
      # First strip any hallucinated timestamp
      remaining_content = self.class.strip_leading_timestamp(content).strip
      json_blocks = []

      # Extract all leading JSON blocks
      while remaining_content.start_with?("{")
        extracted = extract_first_json(remaining_content)
        break unless extracted

        json_blocks << extracted[:json]
        remaining_content = extracted[:remainder].lstrip
      end

      # Process each JSON block
      json_blocks.each do |json_str|
        parsed = parse_loose_json(json_str)
        next unless parsed
        next if tool_result_echo?(parsed)

        result = attempt_tool_recovery(parsed)
        record_tool_result(result, json_str)
      end

      # Update content (stripped of timestamp and JSON)
      update!(content: remaining_content)
      chat.touch
    end
  end

  private

  def user_message_with_content?
    role == "user" && content.present?
  end

  def queue_moderation
    ModerateMessageJob.perform_later(self)
  end

  def human_message_in_group_chat?
    role == "user" && user_id.present? && chat.manual_responses?
  end

  def reopen_all_agents_for_initiation
    chat.chat_agents.closed_for_initiation.update_all(closed_for_initiation_at: nil)
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

  def resolve_attachment_path(attachment)
    return unless !attachment.respond_to?(:attached?) || attachment.attached?

    blob = attachment.blob
    return unless blob.service.exist?(attachment.key)

    if blob.service.respond_to?(:path_for)
      blob.service.path_for(attachment.key)
    else
      tempfile = Tempfile.new([ "attachment", File.extname(attachment.filename.to_s) ])
      tempfile.binmode
      attachment.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind
      tempfile.path
    end
  rescue Errno::ENOENT, ActiveStorage::FileNotFoundError
    nil
  end

  # Extracts the first brace-balanced block from the start of text.
  # Uses brace-counting with string awareness for O(n) performance.
  # Returns { json: "...", remainder: "..." } or nil if no balanced block found.
  # Note: Does not validate JSON - hallucinated content often has unquoted keys.
  def extract_first_json(text)
    depth = 0
    in_string = false
    escape_next = false

    text.chars.each_with_index do |char, i|
      if escape_next
        escape_next = false
        next
      end

      case char
      when "\\"
        escape_next = in_string
      when '"'
        in_string = !in_string
      when "{"
        depth += 1 unless in_string
      when "}"
        next if in_string
        depth -= 1
        if depth.zero?
          candidate = text[0..i]
          return { json: candidate, remainder: text[(i + 1)..].to_s }
        end
      end
    end
    nil
  end

  # Parses JSON that may have unquoted keys (JavaScript object literal style).
  # Models often hallucinate {success: true} instead of {"success": true}.
  def parse_loose_json(json_str)
    # First try strict JSON
    JSON.parse(json_str)
  rescue JSON::ParserError
    # Try quoting unquoted keys: {foo: "bar"} -> {"foo": "bar"}
    # This regex finds word characters followed by colon (not inside quotes)
    quoted = json_str.gsub(/([{,]\s*)(\w+)(\s*:)/, '\1"\2"\3')
    JSON.parse(quoted)
  rescue JSON::ParserError
    nil
  end

  # Attempts to find a tool that can recover from the parsed JSON structure.
  # Returns { success: true, tool_name: ..., result: ... } or { error: "..." }
  def attempt_tool_recovery(parsed_json)
    recoverable_tools.each do |tool_class|
      next unless tool_class.respond_to?(:recoverable_from?) && tool_class.recoverable_from?(parsed_json)
      next unless agent.tools.include?(tool_class)

      return tool_class.recover_from_hallucination(parsed_json, agent: agent, chat: chat)
    end

    { error: "Could not identify tool from JSON structure" }
  end

  # List of tools that implement the recovery interface.
  # Add new tools here as they gain recovery support.
  def recoverable_tools
    [ SaveMemoryTool, WhiteboardTool ].select { |t| t.respond_to?(:recover_from_hallucination) }
  end

  # Recognizes JSON that matches known tool result shapes.
  # These are echoed tool results, not tool calls - they should be silently stripped.
  def tool_result_echo?(parsed_json)
    return false unless parsed_json.is_a?(Hash)

    # Match by `type` field (used by most tools)
    return true if parsed_json["type"].in?(TOOL_RESULT_TYPES)

    # Match any tool success/error response echo — {success: true, ...} or {error: "..."}
    # These are result shapes returned by tools, not tool call inputs
    return true if parsed_json["success"] == true
    return true if parsed_json.key?("error") && parsed_json.keys.size == 1

    false
  end

  # Records the result of a tool recovery attempt as a message just before this one.
  def record_tool_result(result, original_json)
    if result[:success]
      # Create a successful tool execution record
      chat.messages.create!(
        role: "assistant",
        content: "",
        agent: agent,
        tools_used: [ result[:tool_name] ],
        created_at: created_at - 1.second
      )
    else
      # Create an error message explaining the failure
      chat.messages.create!(
        role: "assistant",
        content: "Tool call failed: #{original_json.truncate(200)}\n\nError: #{result[:error]}",
        agent: agent,
        created_at: created_at - 1.second
      )
    end
  end

end
