BotChallengePage.configure do |config|
  config.enabled = true

  # Get from CloudFlare Turnstile: https://www.cloudflare.com/application-services/products/turnstile/
  config.cf_turnstile_sitekey = "1x00000000000000000000AA"
  config.cf_turnstile_secret_key = "1x0000000000000000000000000000000AA"


  # How long will a challenge success exempt a session from further challenges?
  # BotChallengePage.config.session_passed_good_for = 36.hours

  # More configuration is available
end
