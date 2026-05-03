module Agent::Tools

  extend ActiveSupport::Concern

  included do
    before_validation :clean_enabled_tools
    validate :enabled_tools_must_be_valid
  end

  class_methods do
    def available_tools
      Dir[Rails.root.join("app/tools/*_tool.rb")].filter_map do |file|
        File.basename(file, ".rb").camelize.constantize
      rescue NameError => e
        Rails.logger.warn("Agent.available_tools: Failed to load #{file} - #{e.message}")
        nil
      end
    end
  end

  def tools
    return [] if enabled_tools.blank?

    enabled_tools.filter_map do |name|
      name.constantize
    rescue NameError => e
      Rails.logger.warn("Agent##{id}: Tool #{name} not found - #{e.message}")
      nil
    end
  end

  private

  def clean_enabled_tools
    self.enabled_tools = enabled_tools.reject(&:blank?) if enabled_tools.present?
  end

  def enabled_tools_must_be_valid
    return if enabled_tools.blank?
    available = self.class.available_tools.map(&:name)
    invalid = enabled_tools - available
    errors.add(:enabled_tools, "contains invalid tools: #{invalid.join(', ')}") if invalid.any?
  end

end
