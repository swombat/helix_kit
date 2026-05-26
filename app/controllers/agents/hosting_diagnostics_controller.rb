class Agents::HostingDiagnosticsController < ApplicationController

  include AgentScoped

  def show
    render json: {
      sandbox_status: Agents::Sandbox.new(@agent).status,
      filesystem_dump: Agents::FilesystemDump.new(@agent).as_json,
      container_filesystem_dump: Agents::FilesystemDump.new(@agent, target: :container_home).as_json
    }
  end

end
