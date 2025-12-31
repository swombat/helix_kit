class SelfAuthoringTool < RubyLLM::Tool

  ACTIONS = %w[view update].freeze

  FIELDS = %w[
    name
    system_prompt
    reflection_prompt
    memory_reflection_prompt
  ].freeze

  description "View or update your configuration. Actions: view, update. Fields: name, system_prompt, reflection_prompt, memory_reflection_prompt."

  param :action, type: :string,
        desc: "view or update",
        required: true

  param :field, type: :string,
        desc: "name, system_prompt, reflection_prompt, or memory_reflection_prompt",
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
    is_default = actual_value.blank? && default_value.present?

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
    end
  end

  def update_field(field, value)
    if value.blank?
      return validation_error("value required for update")
    end

    if @current_agent.update(field => value)
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
