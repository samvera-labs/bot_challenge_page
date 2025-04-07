
require 'rack/attack'

Rails.application.config.to_prepare do

  BotChallengePage::BotChallengePageController.bot_challenge_config.enabled = true

  # Get from CloudFlare Turnstile: https://www.cloudflare.com/application-services/products/turnstile/
  BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_sitekey = "1x00000000000000000000AA"
  BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key = "1x0000000000000000000000000000000AA"


  BotChallengePage::BotChallengePageController.bot_challenge_config.allow_exempt = ->(controller, config) {
    controller.params[:action] == "index"
  }

end
