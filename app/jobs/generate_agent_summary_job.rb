# frozen_string_literal: true

class GenerateAgentSummaryJob < ApplicationJob

  include SelectsLlmProvider

  queue_as :default

  def perform(chat, agent)
    chat_agent = ChatAgent.find_by(chat: chat, agent: agent)
    return unless chat_agent
    return unless chat_agent.summary_stale?

    recent_messages = chat.messages
      .where(role: %w[user assistant])
      .order(created_at: :desc)
      .limit(10)
      .includes(:agent, :user)
      .reverse

    return if recent_messages.length < 2

    transcript = recent_messages.map do |m|
      author = m.agent&.name || m.user&.full_name || "User"
      "#{author}: #{m.content.to_s.truncate(500)}"
    end

    new_summary = generate_summary(agent, chat_agent, chat, transcript)

    if new_summary.present?
      chat_agent.update_columns(
        agent_summary: new_summary,
        agent_summary_generated_at: Time.current
      )
    end
  rescue Faraday::Error, RubyLLM::Error => e
    Rails.logger.error "Agent summary generation failed for chat=#{chat.id} agent=#{agent.id}: #{e.message}"
  end

  private

  def generate_summary(agent, chat_agent, chat, transcript)
    prompt = build_prompt(agent, chat_agent, chat, transcript)

    provider_config = llm_provider_for(Prompt::LIGHT_MODEL)
    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )

    response = llm.ask(prompt)
    response.content&.squish&.truncate(500)
  end

  def build_prompt(agent, chat_agent, chat, transcript)
    parts = []
    parts << "Your identity:\n#{agent.system_prompt.presence || "You are #{agent.name}."}"
    parts << agent.effective_summary_prompt

    if chat_agent.agent_summary.present?
      parts << "Your previous summary of this conversation:\n#{chat_agent.agent_summary}\n\nUpdate this summary based on the latest messages. Keep exactly 2 lines."
    end

    parts << "Respond with the summary text only. No labels, no bullet points, no prefixes."
    parts << "---\n\nConversation: \"#{chat.title_or_default}\"\n\nRecent messages:\n\n#{transcript.map { |l| "- #{l}" }.join("\n")}"
    parts.join("\n\n")
  end

end
