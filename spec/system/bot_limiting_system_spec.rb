require 'rails_helper'

describe "Turnstile bot limiting", type: :system do
  include WebmockTurnstileHelperMethods

  before do
    # not sure why this breaks it, but it seems to be memory store by default, fine.
    #ActionController::Base.cache_store = :memory_store
    ActionController::Base.cache_store.clear
  end


  let(:cf_turnstile_sitekey_pass) { "1x00000000000000000000AA" } # a test key
  let(:cf_turnstile_secret_key_pass) { "1x0000000000000000000000000000000AA" } # a testing key always passes
  let(:cf_turnstile_secret_key_fail) { "2x0000000000000000000000000000000AA" } # a testing key that produces failure

  # Temporarily change desired mocked config
  # Kinda hacky because we need to keep re-registering the tracks
  around(:each) do |example|
    with_bot_challenge_config(BotChallengePage::BotChallengePageController,
      enabled: true,
      cf_turnstile_sitekey: cf_turnstile_sitekey,
      cf_turnstile_secret_key:  cf_turnstile_secret_key,
    ) { example.run }
  end

  describe "succesful challenge" do
    let(:cf_turnstile_sitekey) { cf_turnstile_sitekey_pass }
    let(:cf_turnstile_secret_key) { cf_turnstile_secret_key_pass }

    before do
      allow(Rails.logger).to receive(:info)
      stub_turnstile_success(request_body: {
        "secret"=>BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key,
        "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"
      })
    end

    it "smoke tests" do
      visit dummy_rate_limit_1_path
      expect(page).to have_content(/rendered #rate_limit_1/)

      # on second try, we're gonna get a challenge page instead
      visit dummy_rate_limit_1_path
      expect(page).to have_content(I18n.t("bot_challenge_page.title"))

      # which eventually will reload and display original desired page page
      expect(page).to have_content(/rendered #rate_limit_1/, wait: 4)
    end

    describe "with redirect_for_challenge" do
      around do |example|
        with_bot_challenge_config(BotChallengePage::BotChallengePageController,
          redirect_for_challenge: true
        ) { example.run }
      end

      it "smoke tests" do
        visit dummy_rate_limit_1_path
        expect(page).to have_content(/rendered #rate_limit_1/)

        # on second try, we're gonna get redirected to bot check page
        visit dummy_rate_limit_1_path
        expect(page).to have_content(I18n.t("bot_challenge_page.title"))

        # which eventually will redirect back to original page
        expect(page).to have_content(/rendered #rate_limit_1/, wait: 4)
      end
    end
  end

  describe "failed challenge" do
    let(:cf_turnstile_sitekey) { cf_turnstile_sitekey_pass }
    let(:cf_turnstile_secret_key) { cf_turnstile_secret_key_fail }

    before do
      allow(Rails.logger).to receive(:warn)
      stub_turnstile_failure(request_body: {
        "secret"=>BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key,
        "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"
      })
    end

    it "stays on page with failure" do
      visit dummy_rate_limit_1_path
      expect(page).to have_content(/rendered #rate_limit_1/)

      # on second try, we're gonna get redirected to bot check page
      visit dummy_rate_limit_1_path
      expect(page).to have_content(I18n.t("bot_challenge_page.title"))

      # which is going to get a failure message
      expect(page).to have_content(I18n.t("bot_challenge_page.error"), wait: 4)
      expect(Rails.logger).to have_received(:warn).with(/BotChallengePage::BotChallengePageController: Cloudflare Turnstile validation failed/)
    end
  end
end
