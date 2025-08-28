# Use these methods instead of Rails.logger.debug, Rails.logger.info, Rails.logger.error

# In particular, they enalbe easier debugging by printing to the console in development and test environment when requested.
#
# Usage (console):
# ```
# DEBUG_DEV=true bin/rails c
# > debug("Hello, world!")
# Hello, world!
# `
#
# Usage (testing):
# ```
# DEBUG=true rails test
# < prints to console >
# ```
#
# Use strings for quick debug statements, or blocks for more complex ones that should not be evaluated in production.
def debug(args, &block)
  if (Rails.env.test? && ENV["DEBUG"].present?) || ENV["DEBUG_DEV"].present?
    if block_given?
      puts block.call
    else
      puts args
    end
  else
    Rails.logger.debug(args, &block)
  end
end

def info(args, &block)
  if (Rails.env.test? && ENV["DEBUG"].present?) || ENV["DEBUG_DEV"].present?
    if block_given?
      puts block.call
    else
      puts args
    end
  else
    Rails.logger.info(args, &block)
  end
end

def error(args, &block)
  if (Rails.env.test? && ENV["DEBUG"].present?) || ENV["DEBUG_DEV"].present?
    if block_given?
      puts block.call
    else
      puts args
    end
  else
    Rails.logger.error(args, &block)
  end
end
