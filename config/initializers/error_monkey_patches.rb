class StandardError

  def body_error_message
    error_message = self.try(:response)
    error_message = error_message.is_a?(Hash) && error_message[:body] ? error_message[:body] : error_message
    error_message = error_message.is_a?(Hash) && error_message["error"] ? error_message["error"] : error_message
    error_message
  end

end
