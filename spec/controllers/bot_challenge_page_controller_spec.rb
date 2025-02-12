require 'rails_helper'

RSpec.describe BotChallengePage::BotChallengePageController, type: :controller do
  include WebmockTurnstileHelperMethods

  describe "#verify_challenge" do
    it "handles turnstile success" do
      turnstile_response = stub_turnstile_success

      post :verify_challenge, params: { cf_turnstile_response: "XXXX.DUMMY.TOKEN.XXXX" }
      expect(response.status).to be 200
      expect(response.body).to eq turnstile_response.to_json

      expect(session[described_class.session_passed_key]).to be_present
      expect(Time.new(session[described_class.session_passed_key][described_class::SESSION_DATETIME_KEY])).to be_within(60).of(Time.now.utc)

      expect(described_class._bot_detect_passed_good?(controller.request)).to be true
    end

    it "handles turnstile failure" do
      turnstile_response = stub_turnstile_failure

      post :verify_challenge, params: { cf_turnstile_response: "XXXX.DUMMY.TOKEN.XXXX" }
      expect(response.status).to be 200
      expect(response.body).to eq turnstile_response.to_json

      expect(session[described_class.session_passed_key]).not_to be_present
    end
  end
end
