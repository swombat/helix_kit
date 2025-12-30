# frozen_string_literal: true

# Broadcasts debug messages to the chat's sync channel for site admins
# Uses the existing SyncChannel mechanism with action: "debug_log"
# Include this in jobs that need to send debug info to site admins
module BroadcastsDebug

  extend ActiveSupport::Concern

  private

  # Broadcast a debug message via the chat's existing sync channel
  # @param level [Symbol] :info, :warn, or :error
  # @param message [String] The debug message
  def broadcast_debug(level, message)
    return unless @chat

    # Broadcast to the chat's sync channel (same channel used for streaming updates)
    ActionCable.server.broadcast(
      "Chat:#{@chat.obfuscated_id}",
      {
        action: "debug_log",
        level: level.to_s,
        message: message,
        time: Time.current.strftime("%H:%M:%S.%L")
      }
    )

    # Also log to Rails logger
    case level
    when :error
      Rails.logger.error "[ChatDebug #{@chat.id}] #{message}"
    when :warn
      Rails.logger.warn "[ChatDebug #{@chat.id}] #{message}"
    else
      Rails.logger.info "[ChatDebug #{@chat.id}] #{message}"
    end
  end

  def debug_info(message)
    broadcast_debug(:info, message)
  end

  def debug_warn(message)
    broadcast_debug(:warn, message)
  end

  def debug_error(message)
    broadcast_debug(:error, message)
  end

end
