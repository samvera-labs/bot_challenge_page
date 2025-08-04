require "bot_challenge_page/version"
require "bot_challenge_page/engine"
require "bot_challenge_page/config"

module BotChallengePage
  mattr_reader :config, default: ::BotChallengePage::Config.new

  # Just a convenience to allow
  #
  #     BotChallengePage.configure do |config|
  #       config.foo = "bar"
  #     end
  #
  def self.configure
    yield config
  end
end
