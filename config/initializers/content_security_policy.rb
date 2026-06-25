# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :data, :https
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https
    # connect-src doit autoriser l'envoi des hits vers Google Analytics / Tag Manager
    # (GA4 poste sur *.google-analytics.com via fetch/beacon) + le pixel Meta.
    policy.connect_src :self,
                       "https://*.google-analytics.com",
                       "https://*.analytics.google.com",
                       "https://*.googletagmanager.com",
                       "https://www.facebook.com"
    policy.frame_src   :self, "https://cal.com", "https://*.cal.com"
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Nonces auto-injectés par javascript_importmap_tags et stylesheet_link_tag.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w(script-src style-src)

  # En dev/test : report-only pour ne pas bloquer pendant l'itération.
  config.content_security_policy_report_only = !Rails.env.production?
end
