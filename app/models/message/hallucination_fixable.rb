module Message::HallucinationFixable

  extend ActiveSupport::Concern

  TIMESTAMP_PATTERN = /\A\s*\[\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\]\s*/

  TOOL_RESULT_TYPES = %w[
    github_commits github_diff github_file
    board board_created board_updated board_list board_deleted board_restored
    deleted_board_list active_board_cleared active_board_set
    config
    search_results fetched_page redirect
    consolidated updated deleted protected refinement_complete
  ].freeze

  class_methods do
    def strip_leading_timestamp(text)
      return text if text.blank?
      text.gsub(TIMESTAMP_PATTERN, "")
    end
  end

  def has_timestamp_prefix?
    return false unless role == "assistant" && content.present?
    content.match?(TIMESTAMP_PATTERN)
  end

  def has_json_prefix?
    return false unless role == "assistant" && content.present?
    stripped = content.gsub(TIMESTAMP_PATTERN, "")
    stripped.strip.start_with?("{")
  end

  def fixable
    return false unless role == "assistant" && agent.present?
    has_timestamp_prefix? || has_json_prefix?
  end

  def fix_hallucinated_tool_calls!
    raise "Not an assistant message" unless role == "assistant"
    raise "Nothing to fix" unless fixable
    raise "Cannot fix: message has no agent" unless agent.present?

    transaction do
      remaining_content = self.class.strip_leading_timestamp(content).strip
      json_blocks = []

      while remaining_content.start_with?("{")
        extracted = extract_first_json(remaining_content)
        break unless extracted

        json_blocks << extracted[:json]
        remaining_content = extracted[:remainder].lstrip
      end

      json_blocks.each do |json_str|
        parsed = parse_loose_json(json_str)
        next unless parsed
        next if tool_result_echo?(parsed)

        result = attempt_tool_recovery(parsed)
        record_tool_result(result, json_str)
      end

      update!(content: remaining_content)
      chat.touch
    end
  end

  private

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

  def parse_loose_json(json_str)
    JSON.parse(json_str)
  rescue JSON::ParserError
    quoted = json_str.gsub(/([{,]\s*)(\w+)(\s*:)/, '\1"\2"\3')
    JSON.parse(quoted)
  rescue JSON::ParserError
    nil
  end

  def attempt_tool_recovery(parsed_json)
    recoverable_tools.each do |tool_class|
      next unless tool_class.respond_to?(:recoverable_from?) && tool_class.recoverable_from?(parsed_json)
      next unless agent.tools.include?(tool_class)

      return tool_class.recover_from_hallucination(parsed_json, agent: agent, chat: chat)
    end

    { error: "Could not identify tool from JSON structure" }
  end

  def recoverable_tools
    [ SaveMemoryTool, WhiteboardTool ].select { |tool| tool.respond_to?(:recover_from_hallucination) }
  end

  def tool_result_echo?(parsed_json)
    return false unless parsed_json.is_a?(Hash)

    return true if parsed_json["type"].in?(TOOL_RESULT_TYPES)
    return true if parsed_json["success"] == true
    return true if parsed_json.key?("error") && parsed_json.keys.size == 1

    false
  end

  def record_tool_result(result, original_json)
    if result[:success]
      chat.messages.create!(
        role: "assistant",
        content: "",
        agent: agent,
        tools_used: [ result[:tool_name] ],
        created_at: created_at - 1.second
      )
    else
      chat.messages.create!(
        role: "assistant",
        content: "Tool call failed: #{original_json.truncate(200)}\n\nError: #{result[:error]}",
        agent: agent,
        created_at: created_at - 1.second
      )
    end
  end

end
