class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

   before_action do |controller|
     BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller, immediate: true)
   end
end
