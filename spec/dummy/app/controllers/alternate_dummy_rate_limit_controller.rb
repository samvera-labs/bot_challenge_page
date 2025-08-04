class AlternateDummyRateLimitController < ApplicationController
  include BotChallengePage::Controller

  bot_challenge after: 1, within: 1.minute, only: :rate_limit_1

  bot_challenge after: 1, within: 1.minute, counter: self.controller_path, only: :rate_limit_1_with_separate_counter

  def rate_limit_1
    render plain: "rendered #rate_limit_1"
  end

  def rate_limit_1_with_separate_counter
    render plain: "rendered #rate_limit_1_with_separate_counter"
  end

end
