# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.base_uri :self
    policy.font_src :self, :https, :data
    policy.img_src :self, :https, :data, :blob
    policy.object_src :none
    policy.script_src :self, :https
    policy.style_src :self, :https, :unsafe_inline
    policy.connect_src :self, :https
    policy.form_action :self, :https
    policy.frame_ancestors :none
    policy.worker_src :self, :blob

    if Rails.env.development?
      vite_http_origin = "http://#{ViteRuby.config.host_with_port}"
      vite_ws_origin = "ws://#{ViteRuby.config.host_with_port}"

      policy.script_src *policy.script_src, :unsafe_eval, vite_http_origin
      policy.connect_src *policy.connect_src, vite_http_origin, vite_ws_origin
    end

    policy.script_src *policy.script_src, :blob if Rails.env.test?
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  config.content_security_policy_report_only = true
end
