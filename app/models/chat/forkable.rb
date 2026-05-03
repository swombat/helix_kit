module Chat::Forkable

  extend ActiveSupport::Concern

  def fork_with_title!(new_title)
    transaction do
      forked = account.chats.new(
        title: new_title,
        model_id: model_id,
        web_access: web_access,
        manual_responses: manual_responses
      )

      forked.agent_ids = agent_ids if manual_responses?
      forked.save!

      messages.includes(:user, :agent, :tool_calls, attachments_attachments: :blob).order(:created_at).each do |message|
        copy_message_to_fork(message, forked)
      end

      forked
    end
  end

  private

  def copy_message_to_fork(message, forked)
    new_message = forked.messages.create!(
      content: message.content,
      role: message.role,
      user_id: message.user_id,
      agent_id: message.agent_id,
      input_tokens: message.input_tokens,
      output_tokens: message.output_tokens,
      cached_tokens: message.cached_tokens,
      cache_creation_tokens: message.cache_creation_tokens,
      thinking_text: message.thinking_text,
      thinking_tokens: message.thinking_tokens,
      replay_payload: message.replay_payload,
      reasoning_skip_reason: message[:reasoning_skip_reason],
      tools_used: message.tools_used,
      skip_content_validation: message.content.blank?
    )

    copy_tool_calls_to_fork(message, new_message)
    copy_attachments_to_fork(message, new_message)
    copy_audio_recording_to_fork(message, new_message)
  end

  def copy_tool_calls_to_fork(message, new_message)
    message.tool_calls.each do |tool_call|
      new_message.tool_calls.create!(
        tool_call_id: tool_call.tool_call_id,
        name: tool_call.name,
        arguments: tool_call.arguments,
        replay_payload: tool_call.replay_payload
      )
    end
  end

  def copy_attachments_to_fork(message, new_message)
    message.attachments.each do |attachment|
      new_message.attachments.attach(
        io: StringIO.new(attachment.download),
        filename: attachment.filename.to_s,
        content_type: attachment.content_type
      )
    end
  end

  def copy_audio_recording_to_fork(message, new_message)
    return unless message.audio_recording.attached?

    new_message.audio_recording.attach(message.audio_recording.blob)
    new_message.update_column(:audio_source, true)
  end

end
