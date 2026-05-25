require "test_helper"

module Agents
  class ConfigTest < ActiveSupport::TestCase

    test "development internal url follows PORT when explicit url is not configured" do
      old_internal_url = ENV["HELIXKIT_AGENT_INTERNAL_URL"]
      old_dev_web_port = ENV["HELIXKIT_DEV_WEB_PORT"]
      old_port = ENV["PORT"]
      ENV.delete("HELIXKIT_AGENT_INTERNAL_URL")
      ENV.delete("HELIXKIT_DEV_WEB_PORT")
      ENV["PORT"] = "3200"

      assert_equal "http://host.docker.internal:3200", Agents::Config.internal_url
    ensure
      ENV["HELIXKIT_AGENT_INTERNAL_URL"] = old_internal_url
      ENV["HELIXKIT_DEV_WEB_PORT"] = old_dev_web_port
      ENV["PORT"] = old_port
    end

    test "development internal url prefers the shared dev web port over process port" do
      old_internal_url = ENV["HELIXKIT_AGENT_INTERNAL_URL"]
      old_dev_web_port = ENV["HELIXKIT_DEV_WEB_PORT"]
      old_port = ENV["PORT"]
      ENV.delete("HELIXKIT_AGENT_INTERNAL_URL")
      ENV["HELIXKIT_DEV_WEB_PORT"] = "3100"
      ENV["PORT"] = "3300"

      assert_equal "http://host.docker.internal:3100", Agents::Config.internal_url
    ensure
      ENV["HELIXKIT_AGENT_INTERNAL_URL"] = old_internal_url
      ENV["HELIXKIT_DEV_WEB_PORT"] = old_dev_web_port
      ENV["PORT"] = old_port
    end

  end
end
