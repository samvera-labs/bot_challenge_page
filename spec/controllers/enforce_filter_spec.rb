require 'rails_helper'

# We spec that the BotDetect filter is actually applying protection, as well as exempting what
# we want
describe DummyController, type: :controller do

  # enable functionality, and reset config to fresh after any further changes
  around(:each) do |example|
    orig_config = BotChallengePage::BotChallengePageController.bot_challenge_config.dup

    BotChallengePage::BotChallengePageController.bot_challenge_config.enabled = true
    BotChallengePage::BotChallengePageController.rack_attack_init

    example.run

    # reset config and  rack-attack back to orig config
    BotChallengePage::BotChallengePageController.bot_challenge_config = orig_config
    BotChallengePage::BotChallengePageController.rack_attack_init
  end

  describe "when rack key requests bot challenge on protected controller" do
    render_views

    before do
      request.env[BotChallengePage::BotChallengePageController.bot_challenge_config.env_challenge_trigger_key] = "true"

      # config an exemption to test
      BotChallengePage::BotChallengePageController.bot_challenge_config.allow_exempt = ->(controller, _config) {
        controller.request.headers["sec-fetch-dest"] == "empty"
      }
    end

    it "challenges when requested" do
      get :index

      expect(response).to have_http_status(403)
      expect(response.headers["Cache-Control"]).to eq "no-store"
      expect(response.body).to include I18n.t("bot_challenge_page.title")
      expect(response.body).to include I18n.t("bot_challenge_page.blurb_html")
    end

    describe "with redirect_for_challenge" do
      around do |example|
        orig_config = BotChallengePage::BotChallengePageController.bot_challenge_config.dup
        BotChallengePage::BotChallengePageController.bot_challenge_config.redirect_for_challenge = true
        BotChallengePage::BotChallengePageController.rack_attack_init

        example.run

        BotChallengePage::BotChallengePageController.bot_challenge_config = orig_config
      end

      it "redirects when requested" do
        get :index

        expect(response).to have_http_status(307)
        expect(response).to redirect_to(bot_detect_challenge_path(dest: dummy_path))
      end
    end

    # we configured this to try to exempt fetch/ajax to #facet
    it "does not redirect from exempted action and request state" do
      request.headers["sec-fetch-dest"] = "empty"
      get :index

      expect(response).to have_http_status(:success) # not a redirect
      expect(response.body).to include "rendered action"
    end
  end
end
