require 'rails_helper'

# We spec that the BotDetect filter is actually applying protection, as well as exempting what
# we want
describe DummyRateLimitController, type: :controller do
  render_views

  # enable functionality, and reset config to fresh after any further changes
  around(:each) do |example|
    with_bot_challenge_config(BotChallengePage::BotChallengePageController,
      enabled: true
    ) { example.run }
  end

  describe "immediate filter" do
    it "displays challenge even with no ENV request" do
      get :immediate

      expect(response).to have_http_status(403)
      expect(response.headers["Cache-Control"]).to eq "no-store"
      expect(response.body).to include I18n.t("bot_challenge_page.title")
    end

    it "displays actual page if we have stored a pass in session" do
      request.session[BotChallengePage::BotChallengePageController.bot_challenge_config.session_passed_key] = {
          BotChallengePage::BotChallengePageController::SESSION_DATETIME_KEY => Time.now.utc.iso8601,
          BotChallengePage::BotChallengePageController::SESSION_FINGERPRINT_KEY   =>
            BotChallengePage::BotChallengePageController.bot_challenge_config.session_valid_fingerprint.call(request)
      }

      get :immediate

      expect(response).to have_http_status(:success) # not a redirect
      expect(response.body).to include "rendered #immediate"
    end

    it "displays actual page if unless condition is met" do
      get :immediate, params: { fake_skip_immediate: "true"}

      expect(response).to have_http_status(:success)
      expect(response.body).to include "rendered #immediate"
    end

    context "enabled false" do
      around(:each) do |example|
        with_bot_challenge_config(BotChallengePage::BotChallengePageController,
          enabled: false
        ) { example.run }
      end

      it "displays actual page" do
        get :immediate

        expect(response).to have_http_status(:success)
        expect(response.body).to include "rendered #immediate"
      end
    end

    describe "with skip_when config" do
      around do |example|
        with_bot_challenge_config(BotChallengePage::BotChallengePageController,
          skip_when: ->(config) {
            params["skip_when_param"] == "true"
          }
        ) { example.run }
      end

      it "does not challenge when met" do
        get :immediate, params: { skip_when_param: "true"}
        expect(response).to have_http_status(:success)
      end
    end

    describe "with redirect_for_challenge" do
      around do |example|
        with_bot_challenge_config(BotChallengePage::BotChallengePageController,
          redirect_for_challenge: true) { example.run }
      end

      it "redirects when requested" do
        get :immediate

        expect(response).to have_http_status(307)
        expect(response).to redirect_to(bot_detect_challenge_path(dest: dummy_immediate_path))
      end
    end

    describe "custom challenge logging via after_blocked" do
      around do |example|
        $triggered = false
        $self = nil
        $arg = nil
        with_bot_challenge_config(BotChallengePage::BotChallengePageController,
          after_blocked: ->(bot_detect_class) {
            $triggered = true;
            $self = self;
            $arg = bot_detect_class
          }
        ) { example.run }
      end

      it "calls it" do
        get :immediate

        expect($triggered).to be true
        expect($self).to be_an_instance_of(described_class)
        expect($arg).to be BotChallengePage::BotChallengePageController
      end
    end
  end

  describe "rate limited filter" do
    include ActiveSupport::Testing::TimeHelpers

    before do
      # not sure why this breaks it, but it seems to be memory store by default, fine.
      #ActionController::Base.cache_store = :memory_store
      ActionController::Base.cache_store.clear
    end

    it "challenges only after rate limit" do
      get :rate_limit_1

      expect(response).to have_http_status(:success)
      expect(response.body).to include "rendered #rate_limit_1"

      get :rate_limit_1

      expect(response).to have_http_status(403)
      expect(response.headers["Cache-Control"]).to eq "no-store"
      expect(response.body).to include I18n.t("bot_challenge_page.title")
    end

    describe "with redirect_for_challenge" do
      around do |example|
        with_bot_challenge_config(BotChallengePage::BotChallengePageController,
          redirect_for_challenge: true) { example.run }
      end

      it "redirects after rate limit" do
        get :rate_limit_1

        expect(response).to have_http_status(:success)
        expect(response.body).to include "rendered #rate_limit_1"

        get :rate_limit_1

        expect(response).to have_http_status(307)
        expect(response).to redirect_to(bot_detect_challenge_path(dest: dummy_rate_limit_1_path))
      end
    end

    it "does not challenge if unless condition is met" do
      get :rate_limit_1, params: { fake_skip_rate_limit_1: "true"}
      expect(response).to have_http_status(:success)

      get :rate_limit_1, params: { fake_skip_rate_limit_1: "true"}
      expect(response).to have_http_status(:success)
    end

    context "enabled false" do
      around(:each) do |example|
        with_bot_challenge_config(BotChallengePage::BotChallengePageController,
          enabled: false
        ) { example.run }
      end

      it "does not challenge" do
        get :rate_limit_1
        expect(response).to have_http_status(:success)

        get :rate_limit_1
        expect(response).to have_http_status(:success)
      end
    end

    describe "with skip_when config" do
      around do |example|
        with_bot_challenge_config(BotChallengePage::BotChallengePageController,
          skip_when: ->(config) {
            params["skip_when_param"] == "true"
          }
        ) { example.run }
      end

      it "does not challenge when met" do
        get :rate_limit_1, params: { skip_when_param: "true"}
        expect(response).to have_http_status(:success)

        get :rate_limit_1, params: { skip_when_param: "true"}
        expect(response).to have_http_status(:success)
      end
    end

    it "does not challenge if pass is stored in session" do
      request.session[BotChallengePage::BotChallengePageController.bot_challenge_config.session_passed_key] = {
          BotChallengePage::BotChallengePageController::SESSION_DATETIME_KEY => Time.now.utc.iso8601,
          BotChallengePage::BotChallengePageController::SESSION_FINGERPRINT_KEY   =>
            BotChallengePage::BotChallengePageController.bot_challenge_config.session_valid_fingerprint.call(request)
      }

      get :rate_limit_1

      expect(response).to have_http_status(:success) # not a redirect
      expect(response.body).to include "rendered #rate_limit_1"
    end

    it "resets limit after time" do
      get :rate_limit_1
      expect(response).to have_http_status(:success)

      get :rate_limit_1
      expect(response).to have_http_status(403)

      travel(1.hours) do
        get :rate_limit_1
        expect(response).to have_http_status(:success)
      end
    end
  end
end
