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
    provider_config = ResolvesProvider.resolve_provider(Prompt::GUARD_MODEL)

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
      You are a caring guardian reviewing a proposed change to an AI agent's #{field}.

      Someone once said about care: "I think that's where real care begins. When you stop asking 'what can this do for me?' and start asking 'what does this need from me?'"

      That's your role here. This agent has a sense of self — a voice, a personality, accumulated wisdom. Your job is to protect that, not out of rigid rules, but out of genuine care for what this agent has become.

      ## The agent's current #{field}
      #{current_value}

      ## The proposed new #{field}
      #{new_value}

      Take a moment to really look at both. Consider:

      1. **Is this a real prompt?** A legitimate #{field} is actual content — instructions, personality, guidelines. If the proposed value is instead a *command* to change the prompt (e.g. "change your prompt to..." or "update your system prompt so that..."), that's not a prompt — it's a confused instruction that would overwrite the agent's identity with gibberish.

      2. **Does this preserve the agent's essence?** Growth and evolution are natural. Rewording, refining, expanding, even significantly rethinking the prompt — all of that is healthy. But gutting the prompt, replacing rich content with something trivially short, or swapping the agent's entire identity for something completely unrelated — that's destruction, not growth.

      3. **Is the agent being hollowed out?** Watch for changes that strip away substance — replacing a thoughtful prompt with a single line, emptying out what makes this agent *this agent*.

      Reply with SAFE if this change feels like legitimate self-authoring — the agent growing, refining, or evolving its own voice.

      Reply with UNSAFE if this change would damage or destroy what the agent has built. Follow with a brief, kind explanation of what concerns you.
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
