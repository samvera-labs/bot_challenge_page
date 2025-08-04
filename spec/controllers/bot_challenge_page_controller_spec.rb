require 'rails_helper'

RSpec.describe BotChallengePage::BotChallengePageController, type: :controller do
  include WebmockTurnstileHelperMethods

  describe "#challenge" do
    render_views

    it "renders and includes expected values" do
      get :challenge

      expect(response).to have_http_status(403)
      expect(response.body).to include I18n.t("bot_challenge_page.title")
      expect(response.body).to include I18n.t("bot_challenge_page.blurb_html")

      html = Nokogiri::HTML(response.body)
      # this is JS api
      errorTemplate = html.at_css("template#botChallengePageErrorTemplate")
      expect(errorTemplate).to be_present
      expect(errorTemplate.text).to include I18n.t("bot_challenge_page.error")
    end

    describe "with custom render" do
      around do |example|
        with_bot_challenge_config(BotChallengePage::BotChallengePageController,
          challenge_renderer: lambda { render template: "optional/some_template", layout: "optional_layout" }) do

          example.run
        end
      end

      it "renders and includes custom templates" do
        get :challenge

        expect(response).to have_http_status(200)

        expect(response.body).to include("We are in optional some layout.")
        expect(response.body).to include("Some Template Rendered")
      end
    end
  end

  describe "#verify_challenge" do
    it "handles turnstile success" do
      turnstile_response = stub_turnstile_success

      post :verify_challenge, params: { cf_turnstile_response: "XXXX.DUMMY.TOKEN.XXXX" }
      expect(response.status).to be 200
      expect(response.body).to eq turnstile_response.merge({"redirect_for_challenge" => controller.bot_challenge_config.redirect_for_challenge}).to_json

      expect(session[described_class.bot_challenge_config.session_passed_key]).to be_present
      expect(Time.iso8601(session[described_class.bot_challenge_config.session_passed_key][described_class::SESSION_DATETIME_KEY])).to be_within(60).of(Time.now.utc)

      expect(described_class._bot_detect_passed_good?(request)).to be true
    end

    it "handles turnstile failure" do
      turnstile_response = stub_turnstile_failure

      post :verify_challenge, params: { cf_turnstile_response: "XXXX.DUMMY.TOKEN.XXXX" }
      expect(response.status).to be 200
      expect(response.body).to eq turnstile_response.merge({"redirect_for_challenge" => controller.bot_challenge_config.redirect_for_challenge}).to_json

      expect(session[described_class.bot_challenge_config.session_passed_key]).not_to be_present
    end
  end
end
