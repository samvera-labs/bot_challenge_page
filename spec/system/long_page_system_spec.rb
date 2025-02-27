require 'rails_helper'

describe "Challenge page stays around persistently", type: :system do
  include WebmockTurnstileHelperMethods

  around do |example|
    # shorten up the delay to make the test faster
    orig = BotChallengePage::BotChallengePageController.bot_challenge_config.dup
    BotChallengePage::BotChallengePageController.bot_challenge_config.still_around_delay_ms = 1
    # auto-pass-key
    BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_sitekey = "1x00000000000000000000AA"
    BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key = "1x0000000000000000000000000000000AA"


    example.run

    BotChallengePage::BotChallengePageController.bot_challenge_config = orig
  end



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
    expect(page).to have_text(I18n.t('bot_challenge_page.still_around'), wait: 7) # it takes a while sorry not sure why
  end
end
