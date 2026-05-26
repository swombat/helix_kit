require "test_helper"

module Agents
  class FilesystemDumpTest < ActiveSupport::TestCase

    test "builds a bounded identity filesystem dump" do
      agent = agents(:research_assistant)
      agent.update!(uuid: SecureRandom.uuid_v7)
      dump = Agents::FilesystemDump.new(agent)

      responses = lambda do |*args|
        case args
        when [ "info", "--format", "{{.ServerVersion}}" ]
          ok("27.0.0")
        when [ "volume", "inspect", "hk-agent-#{agent.uuid}-identity" ]
          ok("[]")
        when [ "run", "--rm", "-v", "hk-agent-#{agent.uuid}-identity:/identity:ro", "-w", "/identity", "busybox", "find", ".", "-maxdepth", "6", "-print" ]
          ok(".\n./memory\n./soul.md\n")
        when [ "run", "--rm", "-v", "hk-agent-#{agent.uuid}-identity:/identity:ro", "-w", "/identity", "busybox", "test", "-d", "./memory" ]
          ok("")
        when [ "run", "--rm", "-v", "hk-agent-#{agent.uuid}-identity:/identity:ro", "-w", "/identity", "busybox", "test", "-d", "./soul.md" ]
          fail_result
        when [ "run", "--rm", "-v", "hk-agent-#{agent.uuid}-identity:/identity:ro", "-w", "/identity", "busybox", "wc", "-c", "./soul.md" ]
          ok("12 ./soul.md\n")
        when [ "run", "--rm", "-v", "hk-agent-#{agent.uuid}-identity:/identity:ro", "-w", "/identity", "busybox", "head", "-c", "4000", "./soul.md" ]
          ok("# Test Soul\n")
        else
          flunk "unexpected docker args: #{args.inspect}"
        end
      end

      dump.stub(:docker_capture, responses) do
        json = dump.as_json
        assert_nil json[:error]
        assert_equal "/home/agent/identity", json[:root]
        assert_equal "hk-agent-#{agent.uuid}-identity", json[:volume_name]
        assert_equal 2, json[:entries].length
        assert_equal({ path: "memory", name: "memory", type: "directory", depth: 0 }, json[:entries].first)
        assert_equal "soul.md", json[:entries].second[:path]
        assert_equal "# Test Soul\n", json[:entries].second[:content]
      end
    end

    test "builds a bounded container home filesystem dump" do
      agent = agents(:research_assistant)
      agent.update!(
        uuid: SecureRandom.uuid_v7,
        container_name: "hk-agent-#{SecureRandom.hex(4)}"
      )
      dump = Agents::FilesystemDump.new(agent, target: :container_home)

      responses = lambda do |*args|
        case args
        when [ "info", "--format", "{{.ServerVersion}}" ]
          ok("27.0.0")
        when [ "container", "inspect", "--format", "{{.State.Running}}", agent.container_name ]
          ok("true\n")
        when [ "exec", agent.container_name, "sh", "-c", "cd /home/agent && find . -maxdepth 6 \\( -path './.chaos' -o -path './.chaos/*' \\) -prune -o -print" ]
          ok(".\n./agent_write_test.txt\n./identity\n")
        when [ "exec", agent.container_name, "sh", "-c", "cd /home/agent && test -d ./agent_write_test.txt" ]
          fail_result
        when [ "exec", agent.container_name, "sh", "-c", "cd /home/agent && wc -c ./agent_write_test.txt" ]
          ok("14 ./agent_write_test.txt\n")
        when [ "exec", agent.container_name, "sh", "-c", "cd /home/agent && head -c 4000 ./agent_write_test.txt" ]
          ok("write worked\n")
        when [ "exec", agent.container_name, "sh", "-c", "cd /home/agent && test -d ./identity" ]
          ok("")
        else
          flunk "unexpected docker args: #{args.inspect}"
        end
      end

      dump.stub(:docker_capture, responses) do
        json = dump.as_json
        assert_nil json[:error]
        assert_equal "/home/agent", json[:root]
        assert_equal :container_home, json[:target]
        assert_equal agent.container_name, json[:container_name]
        assert_equal 2, json[:entries].length
        assert_equal "agent_write_test.txt", json[:entries].first[:path]
        assert_equal "write worked\n", json[:entries].first[:content]
        assert_equal({ path: "identity", name: "identity", type: "directory", depth: 0 }, json[:entries].second)
      end
    end

    private

    def ok(stdout)
      { stdout: stdout, stderr: "", ok: true }
    end

    def fail_result
      { stdout: "", stderr: "", ok: false }
    end

  end
end
