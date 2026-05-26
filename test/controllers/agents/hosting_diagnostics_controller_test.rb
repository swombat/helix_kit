require "test_helper"

class Agents::HostingDiagnosticsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)

    Setting.instance.update!(allow_agents: true)

    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "show returns sandbox and filesystem diagnostics as json" do
    sandbox = Struct.new(:status).new({ docker_available: true })
    dump_factory = lambda do |_agent, target: :identity|
      Struct.new(:as_json).new({
        target: target,
        root: target == :container_home ? "/home/agent" : "/home/agent/identity",
        entries: []
      })
    end

    Agents::Sandbox.stub(:new, ->(_agent) { sandbox }) do
      Agents::FilesystemDump.stub(:new, dump_factory) do
        get account_agent_hosting_diagnostics_path(@account, @agent), as: :json
      end
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body.dig("sandbox_status", "docker_available")
    assert_equal "/home/agent/identity", body.dig("filesystem_dump", "root")
    assert_equal "/home/agent", body.dig("container_filesystem_dump", "root")
  end

end
