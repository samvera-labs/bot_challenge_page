class DummyController < ApplicationController
  # normal one for index
  before_action(only: :index) { |controller| BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller) }

  # immediate one for download please
  before_action(only: :download) { |controller| BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller, immediate: true) }

  def index
    render plain: "rendered action dummy#index"
  end

  # just give us download content-disposition headers to test that
  def download
    headers['content-disposition'] = "attachment; filename=\"file.txt\""
    render plain: "something"
  end
end
