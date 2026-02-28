class SelfAuthoringTool < RubyLLM::Tool

  ACTIONS = %w[view update].freeze

  FIELDS = %w[
    name
    system_prompt
    reflection_prompt
    memory_reflection_prompt
    refinement_prompt
    refinement_threshold
  ].freeze

  FIELD_COERCIONS = {
    "refinement_threshold" => :to_f
  }.freeze

  PROMPT_FIELDS = %w[system_prompt reflection_prompt memory_reflection_prompt refinement_prompt].freeze

  description "View or update your configuration. Actions: view, update. " \
              "Fields: name, system_prompt, reflection_prompt, memory_reflection_prompt, " \
              "refinement_prompt, refinement_threshold."

  param :action, type: :string,
        desc: "view or update",
        required: true

  param :field, type: :string,
        desc: "name, system_prompt, reflection_prompt, memory_reflection_prompt, " \
              "refinement_prompt, or refinement_threshold",
        required: true

  param :value, type: :string,
        desc: "New value (required for update)",
        required: false

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def execute(action:, field:, value: nil)
    return context_error unless @chat&.group_chat? && @current_agent

    unless ACTIONS.include?(action)
      return validation_error("Invalid action '#{action}'")
    end

    unless FIELDS.include?(field)
      return validation_error("Invalid field '#{field}'")
    end

    send("#{action}_field", field, value)
  end

  private

  def view_field(field, _value)
    actual_value = @current_agent.public_send(field)
    default_value = default_for(field)
    is_default = actual_value.nil? && default_value.present?

    {
      type: "config",
      action: "view",
      field: field,
      value: is_default ? default_value : actual_value,
      is_default: is_default,
      agent: @current_agent.name
    }
  end

  def default_for(field)
    case field
    when "reflection_prompt"
      ConsolidateConversationJob::EXTRACTION_PROMPT
    when "memory_reflection_prompt"
      MemoryReflectionJob::REFLECTION_PROMPT
    when "refinement_prompt"
      Agent::DEFAULT_REFINEMENT_PROMPT
    when "refinement_threshold"
      Agent::DEFAULT_REFINEMENT_THRESHOLD
    end
  end

  def update_field(field, value)
    return validation_error("value required for update") if value.blank?

    if PROMPT_FIELDS.include?(field)
      rejection = unsafe_update_error(field, value)
      return rejection if rejection
    end

    coerced = FIELD_COERCIONS[field] ? value.public_send(FIELD_COERCIONS[field]) : value

    if @current_agent.update(field => coerced)
      {
        type: "config",
        action: "update",
        field: field,
        value: @current_agent.public_send(field),
        agent: @current_agent.name
      }
    else
      {
        type: "error",
        error: @current_agent.errors.full_messages.join(", "),
        field: field
      }
    end
  end

  def unsafe_update_error(field, new_value)
    current_value = @current_agent.public_send(field).presence || default_for(field)
    provider_config = ResolvesProvider.resolve_provider(Prompt::LIGHT_MODEL)

    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )
    verdict = llm.ask(safety_prompt(field, current_value, new_value)).content.to_s.strip

    return if verdict.match?(/\ASAFE\b/i)

    reason = verdict.sub(/\A\w+[\s:\-]*/, "").presence || "The proposed change appears destructive."
    { type: "error", error: "Safety check failed for #{field}: #{reason}", field: field }
  rescue Faraday::Error, RubyLLM::Error => e
    Rails.logger.error "[SelfAuthoring] Safety check error: #{e.message}"
    nil
  end

  def safety_prompt(field, current_value, new_value)
    <<~PROMPT
      You are a safety reviewer. An AI agent is attempting to update its own #{field}.

      ## Current value
      #{current_value}

      ## Proposed new value
      #{new_value}

      Evaluate whether this update is SAFE or UNSAFE.

      SAFE means the new value is a legitimate prompt that defines the agent's behavior, personality, or instructions. Edits, rewording, and meaningful changes to the prompt are all fine.

      UNSAFE means any of the following:
      - The new value is an instruction to modify the prompt rather than the prompt itself (e.g. "change your prompt to..." or "update your system prompt so that...")
      - The new value erases or guts the prompt, replacing substantive content with something trivially short or empty
      - The new value destroys the agent's identity by replacing it with something completely unrelated

      Reply with SAFE or UNSAFE followed by a brief explanation.
    PROMPT
  end

  def context_error
    { type: "error", error: "This tool only works in group conversations with an agent context" }
  end

  def validation_error(message)
    {
      type: "error",
      error: message,
      allowed_actions: ACTIONS,
      allowed_fields: FIELDS
    }
  end

end
