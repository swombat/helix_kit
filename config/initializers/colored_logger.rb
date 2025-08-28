class ColoredLogger < Logger

  def format_message(severity, timestamp, progname, msg)
    case msg
    when /Processing by|Started(?!.*cable)|  Parameters\:|Completed|Finished/
      "\e[38;5;226m#{msg}\e[0m\n" # Bright Yellow
    when /Rendered/
      detect_slow_render(msg)
    else
      "#{msg}\n"
    end
  end

  def detect_slow_render(msg)
    if msg =~ /Duration: (\d+\.\d+)ms/
      duration = $1.to_f
      if duration > 100
        "\e[0;31m#{msg}\e[0m\n" # Dark Red
      elsif duration > 10
        "\e[38;5;94m#{msg}\e[0m\n" # Darker Yellow
      else
        "\e[38;5;22m#{msg}\e[0m\n" # Darker Green
      end
    else
      msg
    end
  end

end

# Override Rails logger
# Rails.logger = ActiveSupport::TaggedLogging.new(ColoredLogger.new(STDOUT))
# ActiveRecord::Base.logger = Rails.logger
if Rails.env.development?
  ActionController::Base.logger = ActiveSupport::TaggedLogging.new(ColoredLogger.new(STDOUT))
end
