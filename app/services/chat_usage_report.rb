class ChatUsageReport

  TOKEN_FIELDS = %i[
    uncached_input_tokens
    cache_creation_input_tokens
    cache_read_input_tokens
    output_tokens
    reasoning_output_tokens
  ].freeze

  def initialize(chat:)
    @chat = chat
  end

  def call
    rows = message_rows + runtime_rows
    groups = rows.group_by { |row| [ row[:provider], row[:model] ] }

    {
      models: groups.map { |(provider, model), model_rows| model_json(provider, model, model_rows) }
        .sort_by { |model| -model[:reported_tokens] },
      totals: token_totals(rows),
      row_count: rows.size,
      complete_rows: rows.count { |row| row[:telemetry_state] == "complete" },
      incomplete_rows: rows.count { |row| row[:telemetry_state] != "complete" },
      instrumentation_complete: rows.any? && rows.all? { |row| row[:telemetry_state] == "complete" },
      instrumentation_note: instrumentation_note(rows)
    }
  end

  private

  attr_reader :chat

  def message_rows
    chat.messages
      .where(role: "assistant")
      .includes(:agent)
      .filter_map do |message|
        next if message.agent&.externally_hosted?

        tokens = {
          uncached_input_tokens: message.input_tokens,
          cache_creation_input_tokens: message.cache_creation_tokens,
          cache_read_input_tokens: message.cached_tokens,
          output_tokens: message.output_tokens,
          reasoning_output_tokens: message.thinking_tokens
        }

        {
          source: "message",
          provider: provider_from(message.model_id_string),
          model: message.model_id_string.presence || chat.model_id,
          telemetry_state: tokens.values.all?(&:present?) ? "complete" : "incomplete",
          tokens: tokens
        }
      end
  end

  def runtime_rows
    chat.agent_runtime_interactions.includes(:agent).map do |interaction|
      local_usage = interaction.local_usage?

      {
        source: "runtime",
        provider: interaction.provider.presence || provider_from(interaction.agent.model_id),
        model: interaction.model.presence || interaction.agent.model_id,
        telemetry_state: interaction.telemetry_state,
        tokens: TOKEN_FIELDS.to_h do |field|
          [ field, local_usage ? interaction.public_send(field) : nil ]
        end
      }
    end
  end

  def model_json(provider, model, rows)
    {
      provider: provider,
      model: model.presence || "Unknown model",
      row_count: rows.size,
      sources: rows.map { |row| row[:source] }.uniq,
      complete_rows: rows.count { |row| row[:telemetry_state] == "complete" },
      incomplete_rows: rows.count { |row| row[:telemetry_state] != "complete" },
      tokens: token_totals(rows),
      reported_tokens: TOKEN_FIELDS.sum { |field| sum_known(rows, field).to_i }
    }
  end

  def token_totals(rows)
    TOKEN_FIELDS.to_h do |field|
      values = rows.filter_map { |row| row.dig(:tokens, field) }
      [ field, values.any? ? values.sum : nil ]
    end
  end

  def sum_known(rows, field)
    rows.filter_map { |row| row.dig(:tokens, field) }.sum
  end

  def provider_from(model)
    model.to_s.split("/", 2).first.presence
  end

  def instrumentation_note(rows)
    return "No instrumented model interactions have been recorded for this conversation yet." if rows.empty?
    return "All recorded rows include complete token-category instrumentation." if rows.all? { |row| row[:telemetry_state] == "complete" }

    "Some recorded rows do not include every token category. Unknown values are shown as unavailable rather than zero."
  end

end
