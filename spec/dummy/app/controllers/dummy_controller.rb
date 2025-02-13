class DummyController < ApplicationController
  before_action { |controller| BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller) }

  def index
    render plain: "rendered action"
  end
end
