require "bot_challenge_page/version"
require "bot_challenge_page/engine"
require "bot_challenge_page/config"

module BotChallengePage
  mattr_reader :config, default: ::BotChallengePage::Config.new
end
