require 'rails_helper'

# We spec that the BotDetect filter is actually applying protection, as well as exempting what
# we want
describe DummyImmediateController, type: :controller do

  before do
    # make sure we don't even have rack-attack configured to make sure it works without it
    BotChallengePage::BotChallengePageController._rack_attack_uninit
  end

  # enable functionality, and reset config to fresh after any further changes
  around(:each) do |example|
    orig_config = BotChallengePage::BotChallengePageController.bot_challenge_config.dup
    BotChallengePage::BotChallengePageController.bot_challenge_config.enabled = true

    example.run

    # reset config and  rack-attack back to orig config
    BotChallengePage::BotChallengePageController.bot_challenge_config = orig_config
    BotChallengePage::BotChallengePageController.rack_attack_init
  end

  describe "when rack key requests bot challenge on protected controller" do
    render_views

    it "displays challenge even with no ENV request" do
      get :index

      expect(response).to have_http_status(403)
      expect(response.body).to include I18n.t("bot_challenge_page.title")
    end

    it "displays actual page if we have stored a pass in session" do
      request.session[BotChallengePage::BotChallengePageController.bot_challenge_config.session_passed_key] = {
          BotChallengePage::BotChallengePageController::SESSION_DATETIME_KEY => Time.now.utc.iso8601,
          BotChallengePage::BotChallengePageController::SESSION_IP_KEY   => request.remote_ip
      }

      get :index

      expect(response).to have_http_status(:success) # not a redirect
      expect(response.body).to include "rendered action"
    end
  end
end
