# Configure separate logging for SolidCable, SolidQueue and related database operations
if Rails.env.development? || Rails.env.production?
  # Create a dedicated logger for SolidCable and SolidQueue
  log_file = Rails.root.join("log", "solid_services_#{Rails.env}.log")
  solid_services_logger = ActiveSupport::Logger.new(log_file)
  solid_services_logger.level = Logger::INFO  # Reduce verbosity
  solid_services_logger = ActiveSupport::TaggedLogging.new(solid_services_logger)

  # Set ActionCable to use this logger
  Rails.application.config.action_cable.logger = solid_services_logger
  Rails.application.config.action_cable.log_tags = [ :action_cable, :uuid ]

  # Modify ActiveRecord logger to filter out SolidCable database operations
  original_ar_logger = ActiveRecord::Base.logger

  ActiveRecord::Base.logger = ActiveSupport::TaggedLogging.new(
    ActiveSupport::Logger.new(STDOUT).tap do |logger|
      # Preserve the original log level
      logger.level = original_ar_logger.level

      logger.formatter = proc do |severity, datetime, progname, msg|
        if msg.include?("solid_cable") || msg.include?("SolidCable") ||
          msg.include?("solid_queue") || msg.include?("SolidQueue")
          # Send SolidCable/SolidQueue database logs to the dedicated logger instead
          solid_services_logger.public_send(severity.downcase, msg)
          nil # Don't output to the main log
        else
          # Use the original formatter for non-SolidCable/SolidQueue logs
          original_ar_logger.formatter.call(severity, datetime, progname, msg)
        end
      end
    end
  )

  # Also filter ActiveJob logs for SolidCable jobs
  original_job_logger = ActiveJob::Base.logger

  ActiveJob::Base.logger = ActiveSupport::TaggedLogging.new(
    ActiveSupport::Logger.new(STDOUT).tap do |logger|
      # Preserve the original log level
      logger.level = original_job_logger.level

      logger.formatter = proc do |severity, datetime, progname, msg|
        if msg.include?("SolidCable") || msg.include?("SolidQueue") ||
          (msg.include?("job=") && (msg.include?("SolidCable%") || msg.include?("SolidQueue%")))
          # Send SolidCable/SolidQueue job logs to the dedicated logger instead
          solid_services_logger.public_send(severity.downcase, msg)
          nil # Don't output to the main log
        else
          # Use the original formatter for non-SolidCable/SolidQueue logs
          original_job_logger.formatter.call(severity, datetime, progname, msg)
        end
      end
    end
  )

  # Patch Rails logger to filter controller actions with SolidCable job tags
  original_rails_logger = Rails.logger

  Rails.logger = ActiveSupport::TaggedLogging.new(
    ActiveSupport::Logger.new(STDOUT).tap do |logger|
      # Preserve the original log level
      logger.level = original_rails_logger.level

      logger.formatter = proc do |severity, datetime, progname, msg|
        if msg.include?("SolidCable") || msg.include?("solid_cable") ||
          msg.include?("SolidQueue") || msg.include?("solid_queue") ||
          (msg.include?("job=") && (msg.include?("SolidCable%") || msg.include?("SolidQueue%")))
          # Send SolidCable/SolidQueue-related logs to the dedicated logger instead
          solid_services_logger.public_send(severity.downcase, msg)
          nil # Don't output to the main log
        else
          # Use the original formatter for non-SolidCable/SolidQueue logs
          original_rails_logger.formatter.call(severity, datetime, progname, msg)
        end
      end
    end
  )
end
