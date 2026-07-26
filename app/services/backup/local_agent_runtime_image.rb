module Backup
  class LocalAgentRuntimeImage

    class BuildError < StandardError; end

    VERSION_PATTERN = /\Achaos-cli\s+(\d+(?:\.\d+)+)\z/

    def self.ensure_current!
      new.ensure_current!
    end

    def initialize(
      image: Agents::Config.default_image,
      runtime_dir: Rails.root.join("agent-runtime"),
      production_version: nil,
      capture3: Open3.method(:capture3),
      system: Kernel.method(:system)
    )
      @image = image
      @runtime_dir = runtime_dir
      @production_version = production_version || method(:latest_recorded_chaos_version)
      @capture3 = capture3
      @system = system
    end

    def ensure_current!
      expected_version = production_version.call
      current_version = local_version

      if current_version.present? && expected_version.blank?
        puts "Could not determine the production Chaos version; keeping local runtime #{current_version}."
        return false
      end

      if current_version.present? && version_at_least?(current_version, expected_version)
        comparison = current_version == expected_version ? "matches" : "is newer than"
        puts "Local agent runtime #{current_version} #{comparison} production #{expected_version}."
        return false
      end

      reason = current_version.present? ? "#{current_version} is older than production #{expected_version}" : "the image is missing"
      puts "Rebuilding #{image} because #{reason}..."
      build!

      rebuilt_version = local_version
      raise BuildError, "Built #{image}, but could not read its Chaos version" if rebuilt_version.blank?
      if expected_version.present? && !version_at_least?(rebuilt_version, expected_version)
        raise BuildError, "Built #{image} with #{rebuilt_version}, older than production #{expected_version}"
      end

      puts "Built #{image} with #{rebuilt_version}."
      true
    end

    private

    attr_reader :image, :runtime_dir, :production_version, :capture3, :system

    def latest_recorded_chaos_version
      AgentRuntimeInteraction
        .where.not(chaos_version: [ nil, "" ])
        .order(finished_at: :desc, id: :desc)
        .pick(:chaos_version)
    end

    def local_version
      stdout, _stderr, status = capture3.call(
        "docker", "run", "--rm", "--entrypoint", "chaos", image, "--version"
      )
      status.success? ? stdout.strip.presence : nil
    end

    def version_at_least?(candidate, expected)
      return true if expected.blank?
      return candidate == expected unless candidate.match?(VERSION_PATTERN) && expected.match?(VERSION_PATTERN)

      Gem::Version.new(candidate.match(VERSION_PATTERN)[1]) >=
        Gem::Version.new(expected.match(VERSION_PATTERN)[1])
    end

    def build!
      success = system.call(
        "docker", "build", "-t", image, runtime_dir.to_s
      )
      raise BuildError, "Could not build #{image}" unless success
    end

  end
end
