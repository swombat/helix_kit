require "test_helper"
require "base64"
require "openssl"
require "yaml"

class AgentCredentialsEncryptorTest < ActiveSupport::TestCase

  test "encrypts credentials in python-compatible aes-gcm shape" do
    agent = agents(:research_assistant)
    agent.update!(uuid: SecureRandom.uuid_v7, trigger_bearer_token: "tr_test")
    master_key = SecureRandom.base64(32)

    encrypted = AgentCredentialsEncryptor.new(
      agent,
      master_key,
      outbound_token: "hx_test",
      github_deploy_key: "PRIVATE KEY",
      provider_keys: {
        "ANTHROPIC_API_KEY" => "sk-ant-test",
        "OPENROUTER_API_KEY" => "sk-or-test"
      }
    ).encrypt
    wrapper = YAML.safe_load(encrypted)

    plaintext = decrypt(wrapper, master_key)
    creds = YAML.safe_load(plaintext)

    assert_equal "aes-256-gcm", wrapper["algorithm"]
    assert_equal agent.uuid, creds["agent_uuid"]
    assert_equal "hx_test", creds.dig("helix_kit", "bearer_token")
    assert creds.dig("helix_kit", "app_url").present?
    assert_equal %w[app_url bearer_token], creds.fetch("helix_kit").keys.sort
    assert_equal "tr_test", creds.dig("trigger", "bearer_token")
    assert_equal "PRIVATE KEY", creds.dig("github", "deploy_key")
    assert_equal "sk-ant-test", creds.dig("llm_provider_keys", "ANTHROPIC_API_KEY")
    assert_equal "sk-or-test", creds.dig("llm_provider_keys", "OPENROUTER_API_KEY")
  end

  test "omits placeholder provider keys" do
    provider_keys = AgentCredentialsEncryptor.stub(
      :provider_key_value,
      ->(_method, _credentials_path, _env_name) { "<PLACEHOLDER>" }
    ) do
      AgentCredentialsEncryptor.provider_keys_from_helixkit
    end

    assert_empty provider_keys
  end

  private

  def decrypt(wrapper, master_key)
    key = Base64.strict_decode64(master_key)
    nonce = Base64.strict_decode64(wrapper.fetch("nonce"))
    ciphertext_with_tag = Base64.strict_decode64(wrapper.fetch("ciphertext"))
    ciphertext = ciphertext_with_tag[0...-16]
    tag = ciphertext_with_tag[-16..]

    cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
    cipher.key = key
    cipher.iv = nonce
    cipher.auth_tag = tag
    cipher.update(ciphertext) + cipher.final
  end

end
