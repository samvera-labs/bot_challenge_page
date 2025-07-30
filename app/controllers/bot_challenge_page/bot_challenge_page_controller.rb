require 'http'

# This controller has actions for issuing a challenge page for CloudFlare Turnstile product,
# and then redirecting back to desired page.
#
# It also includes logic for configuring rack attack and a Rails controller filter to enforce
# redirection to these actions. All the logic related to bot detection with turnstile is
# mostly in this file -- with very flexible configuration in class_attributes -- to faciliate
# future extraction to a re-usable gem if desired.
#
#
module BotChallengePage
  class BotChallengePageController < ::ApplicationController
    include BotChallengePage::EnforceFilter

    # Config for bot detection is held in class object here -- idea is
    # to support different controllers with different config protecting
    # different paths in your app if you like, is why config is with controller
    class_attribute :bot_challenge_config, default: ::BotChallengePage::Config.new

    SESSION_DATETIME_KEY = "t"
    SESSION_IP_KEY = "i"

    # only used if config.redirect_for_challenge is true
    def challenge
      # possible custom render to choose layouts or templates, but
      # default is what would be default template for this action
      #
      # We put it in instancevar as a hacky way of passing to template that can be fulfilled
      # both here and in arbitrary controllers for direct render.
      @bot_challenge_config = bot_challenge_config
      instance_exec &self.bot_challenge_config.challenge_renderer
    end

    def verify_challenge
      body = {
        secret: self.bot_challenge_config.cf_turnstile_secret_key,
        response: params["cf_turnstile_response"],
        remoteip: request.remote_ip,
      }

      http = HTTP.timeout(self.bot_challenge_config.cf_timeout)
      response = http.post(self.bot_challenge_config.cf_turnstile_validation_url,
        json: body)

      result = response.parse
      # {"success"=>true, "error-codes"=>[], "challenge_ts"=>"2025-01-06T17:44:28.544Z", "hostname"=>"example.com", "metadata"=>{"result_with_testing_key"=>true}}
      # {"success"=>false, "error-codes"=>["invalid-input-response"], "messages"=>[], "metadata"=>{"result_with_testing_key"=>true}}

      if result["success"]
        # mark it as succesful in session, and record time. They do need a session/cookies
        # to get through the challenge.
        Rails.logger.info("#{self.class.name}: Cloudflare Turnstile validation passed api (#{request.remote_ip}, #{request.user_agent}): #{params["dest"]}")
        session[self.bot_challenge_config.session_passed_key] = {
          SESSION_DATETIME_KEY => Time.now.utc.iso8601,
          SESSION_IP_KEY   => request.remote_ip
        }
      else
        Rails.logger.warn("#{self.class.name}: Cloudflare Turnstile validation failed (#{request.remote_ip}, #{request.user_agent}): #{result}: #{params["dest"]}")
      end

      # add config needed by JS to result
      result["redirect_for_challenge"] = self.bot_challenge_config.redirect_for_challenge

      # and let's just return the whole thing to client? Is there anything confidential there?
      render json: result
    rescue HTTP::Error, JSON::ParserError => e
      # probably an http timeout? or something weird.
      Rails.logger.warn("#{self.class.name}: Cloudflare turnstile validation error (#{request.remote_ip}, #{request.user_agent}): #{e}: #{response&.body}")
      render json: {
        success: false,
        http_exception: e
      }
    end
  end
end
