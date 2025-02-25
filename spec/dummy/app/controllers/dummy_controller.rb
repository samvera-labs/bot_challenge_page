class DummyController < ApplicationController
  before_action { |controller| BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller) }

  def index
    render plain: "rendered action dummy"
  end

  # just give us download content-disposition headers to test that
  def download
    headers['content-disposition'] = "attachment; filename=\"file.txt\""
    render plain: "something"
  end
end
