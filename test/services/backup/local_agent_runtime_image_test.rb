require "test_helper"

class Backup::LocalAgentRuntimeImageTest < ActiveSupport::TestCase

  test "keeps a local image matching the latest recorded production version" do
    builds = []
    service = build_service(
      production_version: "chaos-cli 47.0.0.200",
      local_versions: [ "chaos-cli 47.0.0.200" ],
      builds: builds
    )

    assert_equal false, service.ensure_current!
    assert_empty builds
  end

  test "keeps a local image newer than the latest recorded production version" do
    builds = []
    service = build_service(
      production_version: "chaos-cli 47.0.0.200",
      local_versions: [ "chaos-cli 47.0.0.201" ],
      builds: builds
    )

    assert_equal false, service.ensure_current!
    assert_empty builds
  end

  test "rebuilds an older local image and verifies the result" do
    builds = []
    service = build_service(
      production_version: "chaos-cli 47.0.0.200",
      local_versions: [ "chaos-cli 47.0.0.100", "chaos-cli 47.0.0.200" ],
      builds: builds
    )

    assert_equal true, service.ensure_current!
    assert_equal [ [ "docker", "build", "-t", "helixkit-agent-runtime:local", "/tmp/agent-runtime" ] ], builds
  end

  test "rebuilds a missing local image" do
    builds = []
    service = build_service(
      production_version: "chaos-cli 47.0.0.200",
      local_versions: [ nil, "chaos-cli 47.0.0.200" ],
      builds: builds
    )

    assert_equal true, service.ensure_current!
    assert_equal 1, builds.length
  end

  test "fails when the rebuilt image is still older than production" do
    service = build_service(
      production_version: "chaos-cli 47.0.0.200",
      local_versions: [ "chaos-cli 47.0.0.100", "chaos-cli 47.0.0.150" ],
      builds: []
    )

    error = assert_raises(Backup::LocalAgentRuntimeImage::BuildError) do
      service.ensure_current!
    end
    assert_match(/older than production/, error.message)
  end

  private

  def build_service(production_version:, local_versions:, builds:)
    versions = local_versions.dup
    successful_status = Object.new
    successful_status.define_singleton_method(:success?) { true }
    missing_status = Object.new
    missing_status.define_singleton_method(:success?) { false }

    capture3 = lambda do |*command|
      assert_equal(
        [ "docker", "run", "--rm", "--entrypoint", "chaos", "helixkit-agent-runtime:local", "--version" ],
        command
      )
      version = versions.shift
      [ version.to_s, "", version ? successful_status : missing_status ]
    end
    system = lambda do |*command|
      builds << command
      true
    end

    Backup::LocalAgentRuntimeImage.new(
      image: "helixkit-agent-runtime:local",
      runtime_dir: Pathname("/tmp/agent-runtime"),
      production_version: -> { production_version },
      capture3: capture3,
      system: system
    )
  end

end
