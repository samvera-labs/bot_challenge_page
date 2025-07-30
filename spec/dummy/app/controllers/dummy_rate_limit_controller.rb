class DummyRateLimitController < ApplicationController
  include BotChallengePage::Controller

  bot_challenge only: :immediate, unless: -> { params[:fake_skip_immediate] == "true"}

  bot_challenge after: 1, within: 1.minute, only: :rate_limit_1, unless: -> { params[:fake_skip_rate_limit_1] == "true"}

  bot_challenge only: :download

  bot_challenge only: :double_limit, after: 2, within: 5.seconds, name: "short-term"
  bot_challenge only: :double_limit, after: 5, within: 1.minute, name: "long-term"

  def immediate
    render plain: "rendered #immediate"
  end

  def rate_limit_1
    render plain: "rendered #rate_limit_1"
  end

  # just give us download content-disposition headers to test that
  def download
    headers['content-disposition'] = "attachment; filename=\"file.txt\""
    render plain: "rendered #download"
  end

  def double_limit
    render plain: "#double_limit"
  end
end
