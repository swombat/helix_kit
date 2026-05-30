class Agents::HostingDiagnosticsController < ApplicationController

  include AgentScoped

  def show
    reconcile_orientation_from_journals!

    render json: {
      sandbox_status: Agents::Sandbox.new(@agent).status,
      filesystem_dump: Agents::FilesystemDump.new(@agent).as_json,
      container_filesystem_dump: Agents::FilesystemDump.new(@agent, target: :container_home).as_json
    }
  end

  def file_preview
    target = params[:target].presence || :identity
    render json: Agents::FilesystemDump.new(@agent, target: target).file_preview_json(params[:path])
  end


  private

  def reconcile_orientation_from_journals!
    return unless @agent.external? && @agent.oriented_at.blank?

    @agent.update!(oriented_at: Time.current) if Agents::DailyJournalStatus.new(@agent).entries?
  rescue StandardError => e
    Rails.logger.debug { "[HostingDiagnostics] orientation journal check skipped for agent #{@agent.id}: #{e.class}: #{e.message}" }
  end

end
