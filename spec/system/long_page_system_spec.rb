require 'rails_helper'

describe "Challenge page stays around persistently", type: :system do
  include WebmockTurnstileHelperMethods

  around do |example|
    # shorten up the delay to make the test faster
    with_bot_challenge_config(BotChallengePage::BotChallengePageController,
      still_around_delay_ms: 1,
      # auto-pass-key
      cf_turnstile_sitekey: "1x00000000000000000000AA",
      cf_turnstile_secret_key: "1x0000000000000000000000000000000AA"
    ) { example.run }
  end

  before do
    stub_turnstile_success(request_body: {
        "secret"=>BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key,
        "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"
      })
  end

  it "shows appropriate message" do
    visit dummy_download_path

    # this is protected with immediate challenge, inline, so first they should see the challenge page
    expect(page).to have_content(I18n.t("bot_challenge_page.title"))

    # and eventually theys hould see the still-around message we show when there
    # was no nav after challenge success
    expect(page).to have_text(I18n.t('bot_challenge_page.still_around'), wait: 7) # not sure why we need to wait so long to see it
  end

  describe "with redirect" do
    around do |example|
      with_bot_challenge_config(BotChallengePage::BotChallengePageController,
        redirect_for_challenge: true
      ) { example.run }
    end

    it "shows appropriate message" do
      # our destination is a forced download, so they never naviagate anywhere else
      visit "/challenge?dest=#{dummy_download_path}"

      expect(page).to have_content(I18n.t("bot_challenge_page.title"))

      # show it eventually should show them the message we show in that case
      expect(page).to have_text(I18n.t('bot_challenge_page.still_around'), wait: 7) # it takes a while sorry not sure why
    end
  end
end
