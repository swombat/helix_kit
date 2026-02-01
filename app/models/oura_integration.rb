class OuraIntegration < ApplicationRecord

  include OuraApi

  belongs_to :user

  validates :user_id, uniqueness: true

  scope :enabled, -> { where(enabled: true) }
  scope :needs_sync, -> { enabled.where("health_data_synced_at IS NULL OR health_data_synced_at < ?", 6.hours.ago) }
  scope :with_valid_tokens, -> { where("token_expires_at > ?", Time.current) }

  def sync_health_data!
    refresh_tokens! unless token_fresh?
    return unless connected?

    update!(
      health_data: fetch_health_data,
      health_data_synced_at: Time.current
    )
  end

  def health_context
    return unless enabled? && health_data.present?

    parts = [
      format_sleep_context,
      format_readiness_context,
      format_activity_context
    ].compact

    return if parts.empty?

    "# Health Data from Oura Ring\n\n#{parts.join("\n\n")}"
  end

  def disconnect!
    revoke_token
    update!(
      access_token: nil,
      refresh_token: nil,
      token_expires_at: nil,
      health_data: {},
      health_data_synced_at: nil
    )
  end

  private

  def format_sleep_context
    latest = health_data.dig("sleep")&.max_by { |d| d["day"] }
    return unless latest

    score = latest["score"]
    c = latest["contributors"] || {}

    lines = [ "## Last Night's Sleep", "- Sleep Score: #{score}/100" ]
    lines << "- Deep Sleep: #{c['deep_sleep']}/100" if c["deep_sleep"]
    lines << "- REM Sleep: #{c['rem_sleep']}/100" if c["rem_sleep"]
    lines << "- Efficiency: #{c['efficiency']}/100" if c["efficiency"]
    lines << "- Restfulness: #{c['restfulness']}/100" if c["restfulness"]
    lines.join("\n")
  end

  def format_readiness_context
    latest = health_data.dig("readiness")&.max_by { |d| d["day"] }
    return unless latest

    score = latest["score"]
    c = latest["contributors"] || {}

    lines = [ "## Today's Readiness", "- Readiness Score: #{score}/100" ]
    lines << "- HRV Balance: #{c['hrv_balance']}/100" if c["hrv_balance"]
    lines << "- Recovery Index: #{c['recovery_index']}/100" if c["recovery_index"]
    lines << "- Resting Heart Rate: #{c['resting_heart_rate']}/100" if c["resting_heart_rate"]

    if latest["temperature_deviation"]
      lines << "- Temperature Deviation: #{latest['temperature_deviation'].round(1)}C"
    end

    lines.join("\n")
  end

  def format_activity_context
    latest = health_data.dig("activity")&.max_by { |d| d["day"] }
    return unless latest

    lines = [ "## Yesterday's Activity", "- Activity Score: #{latest['score']}/100" ]
    lines << "- Steps: #{latest['steps'].to_i.to_fs(:delimited)}" if latest["steps"]
    lines << "- Active Calories: #{latest['active_calories'].to_i}" if latest["active_calories"]
    lines.join("\n")
  end

end
