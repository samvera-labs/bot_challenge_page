require 'rails_helper'

# We spec that the BotDetect filter is actually applying protection, as well as exempting what
# we want
describe DummyImmediateController, type: :controller do
  render_views

  before do
    # make sure we don't even have rack-attack configured to make sure it works without it
    BotChallengePage::BotChallengePageController._rack_attack_uninit
  end

  # enable functionality, and reset config to fresh after any further changes
  around(:each) do |example|
    with_bot_challenge_config(BotChallengePage::BotChallengePageController,
      enabled: true
    ) { example.run }
  end

  it "displays challenge even with no ENV request" do
    get :index

    expect(response).to have_http_status(403)
    expect(response.headers["Cache-Control"]).to eq "no-store"
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

  describe "custom challenge logging" do
    around do |example|
      $triggered = false
      $self = nil
      $arg = nil
      with_bot_challenge_config(BotChallengePage::BotChallengePageController,
        after_challenge: ->(bot_detect_class) {
          $triggered = true;
          $self = self;
          $arg = bot_detect_class
        }
      ) { example.run }
    end

    it "calls it" do
      get :index

      expect($triggered).to be true
      expect($self).to be_an_instance_of(DummyImmediateController)
      expect($arg).to be BotChallengePage::BotChallengePageController
    end
  end
end
