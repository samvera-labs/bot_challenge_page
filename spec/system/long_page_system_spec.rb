require 'rails_helper'

describe "Challenge page stays around persistently", type: :system do
  include WebmockTurnstileHelperMethods

  before do
    stub_turnstile_success(request_body: {
        "secret"=>BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key,
        "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"
      })
  end

  it "shows appropriate message" do
    # our destination is a forced download, so they never naviagate anywhere else
    visit "/challenge?dest=#{dummy_download_path}"

    # show it eventually should show them the message we show in that case
    expect(page).to have_text(I18n.t('bot_challenge_page.still_around'), wait: 4)
  end
end
