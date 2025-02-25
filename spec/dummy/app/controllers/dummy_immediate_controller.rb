class DummyImmediateController < ApplicationController
  # with immediate:true
  before_action { |controller| BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller, immediate: true) }

  def index
    render plain: "rendered action dummy"
  end
end
