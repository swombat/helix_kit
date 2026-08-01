module Notices
  class Renderer

    class << self

      def section_for(agent)
        items = Notice.for_agent(agent).filter_map { |notice| render(notice, agent) }
        return if items.empty?

        <<~TEXT.strip
          ## Notices from the house

          These are standing notices. They may appear again in later activations until their stated expiry.

          #{items.join("\n")}
        TEXT
      end

      private

      def render(notice, agent)
        text = case notice.notice_type
        when "model_changed"
          model_changed_text(notice, agent)
        when "site_renamed"
          "This platform, formerly HelixKit, is now called souls.house."
        when "announcement"
          notice.body.presence
        else
          Rails.logger.warn "[Notices::Renderer] Skipping unknown notice type #{notice.notice_type.inspect} (notice #{notice.id})"
          return
        end
        return if text.blank?

        "- [#{notice.scope} · until #{format_date(notice.expires_at)}] #{text}"
      rescue KeyError, ArgumentError, TypeError => e
        Rails.logger.warn "[Notices::Renderer] Skipping malformed notice #{notice.id}: #{e.class}: #{e.message}"
        nil
      end

      def model_changed_text(notice, agent)
        params = notice.params.to_h.stringify_keys
        changed_at = Time.iso8601(params.fetch("changed_at"))
        text = "On #{format_date(changed_at)}, #{params.fetch("agent_name")}'s configured model changed from " \
          "#{params.fetch("from")} to #{params.fetch("to")}."
        text += " This model change concerns you." if params.fetch("agent_id").to_s == agent.to_param
        text
      end

      def format_date(value)
        value.in_time_zone.to_date.strftime("%-d %B %Y")
      end

    end

  end
end
