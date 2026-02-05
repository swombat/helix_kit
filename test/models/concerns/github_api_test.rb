require "test_helper"

class GithubApiTest < ActiveSupport::TestCase

  test "GithubApi module is defined" do
    assert defined?(GithubApi)
    assert_kind_of Module, GithubApi
  end

  test "GithubApi::Error is defined" do
    assert defined?(GithubApi::Error)
    assert GithubApi::Error < StandardError
  end

  test "defines expected constants" do
    assert_equal "https://github.com/login/oauth/authorize", GithubApi::GITHUB_AUTHORIZE_URL
    assert_equal "https://github.com/login/oauth/access_token", GithubApi::GITHUB_TOKEN_URL
    assert_equal "https://api.github.com", GithubApi::GITHUB_API_BASE
    assert_equal "2022-11-28", GithubApi::API_VERSION
  end

  test "defines expected public instance methods" do
    methods = GithubApi.instance_methods(false)
    assert_includes methods, :authorization_url
    assert_includes methods, :exchange_code!
    assert_includes methods, :connected?
    assert_includes methods, :fetch_repos
    assert_includes methods, :fetch_recent_commits
  end

  test "defines expected private instance methods" do
    methods = GithubApi.private_instance_methods(false)
    assert_includes methods, :github_credentials
    assert_includes methods, :fetch_user
    assert_includes methods, :get
  end

end
