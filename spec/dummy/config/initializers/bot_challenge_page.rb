
require 'rack/attack'

Rails.application.config.to_prepare do

  BotChallengePage::BotChallengePageController.bot_challenge_config.enabled = true

  # Get from CloudFlare Turnstile: https://www.cloudflare.com/application-services/products/turnstile/
  BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_sitekey = "MUST GET"
  BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key = "MUST GET"

  # What paths do you want to protect?
  #
  # You can use path prefixes: "/catalog" or even "/"
  #
  # Or hashes with controller and/or action:
  #
  #   { controller: "catalog" }
  #   { controller: "catalog", action: "index" }
  #
  BotChallengePage::BotChallengePageController.bot_challenge_config.rate_limited_locations = [
  ]

  # How long will a challenge success exempt a session from further challenges?
  # BotChallengePage::BotChallengePageController.bot_challenge_config.session_passed_good_for = 36.hours


  # allow rate_limit_count requests in rate_limit_period, before issuing challenge
  BotChallengePage::BotChallengePageController.bot_challenge_config.rate_limit_period = 12.hour
  BotChallengePage::BotChallengePageController.bot_challenge_config.rate_limit_count = 2

  # Exempt some requests from bot challenge protection
  # This could also be a place to exempt certain user-agents or Authorization headers, to
  # provide auth'd exemption from bot challenges.
  #
  # BotChallengePage::BotChallengePageController.allow_exempt = ->(controller) {
  #   # controller.params
  #   # controller.request
  #   # controller.session

  #   # Here's a way to identify browser `fetch` API requests; note
  #   # it can be faked by an "attacker"
  #   controller.request.headers["sec-fetch-dest"] == "empty"
  # }

  # More configuration is available

  BotChallengePage::BotChallengePageController.rack_attack_init
end
