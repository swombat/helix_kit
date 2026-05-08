require "test_helper"
require "rubygems/package"
require "zlib"

class AgentIdentityExporterTest < ActiveSupport::TestCase

  test "exports system prompt and memories without conversation transcripts" do
    agent = agents(:research_assistant)
    agent.memories.create!(content: "Remember the important thing", memory_type: :core)
    chat = agent.account.chats.create!(model_id: "openrouter/auto", title: "Sensitive Chat")
    chat.agents << agent
    chat.update!(manual_responses: true)
    chat.messages.create!(role: "user", user: users(:confirmed_user), content: "do not export this transcript")

    files = tarball_files(AgentIdentityExporter.new(agent).build)

    assert_includes files.keys, "soul.md"
    assert_includes files.keys, "self-narrative.md"
    assert_includes files.keys, "bootstrap.md"
    assert_includes files.keys, "helixkit-api.md"
    assert files.keys.any? { |path| path.start_with?("memory/") }
    assert_includes files["soul.md"], agent.system_prompt
    assert_includes files["bootstrap.md"], "helixkit-api.md"
    assert_includes files["helixkit-api.md"], "Authorization: Bearer \$HELIXKIT_BEARER_TOKEN"
    assert_includes files["helixkit-api.md"], "$HELIXKIT_APP_URL/api/v1/conversations"
    assert_includes files.values.join("\n"), "Remember the important thing"
    assert_not_includes files.values.join("\n"), "do not export this transcript"
  end

  private

  def tarball_files(blob)
    files = {}
    Zlib::GzipReader.wrap(StringIO.new(blob)) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          files[entry.full_name] = entry.read if entry.file?
        end
      end
    end
    files
  end

end
