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
    # Config for bot detection is held in class object here -- idea is
    # to support different controllers with different config protecting
    # different paths in your app if you like, is why config is with controller
    class_attribute :bot_challenge_config, default: ::BotChallengePage::Config.new

    delegate :cf_turnstile_js_url, :cf_turnstile_sitekey, :still_around_delay_ms, to: :bot_challenge_config
    helper_method :cf_turnstile_js_url, :cf_turnstile_sitekey, :still_around_delay_ms

    SESSION_DATETIME_KEY = "t"
    SESSION_IP_KEY = "i"

    # for allowing unsubscribe for testing
    class_attribute :_track_notification_subscription, instance_accessor: false

    # perhaps in an initializer, and after changing any config, run:
    #
    #     Rails.application.config.to_prepare do
    #       BotChallengePage::BotChallengePageController.rack_attack_init
    #     end
    #
    # Safe to call more than once if you change config and want to call again, say in testing.
    def self.rack_attack_init
      self._rack_attack_uninit # make it safe for calling multiple times

      ## Turnstile bot detection throttling
      #
      # for paths matched by `rate_limited_locations`, after over rate_limit count requests in rate_limit_period,
      # token will be stored in rack env instructing challenge is required.
      #
      # For actual challenge, need before_action in controller.
      #
      # You could rate limit detect on wider paths than you actually challenge on, or the same. You probably
      # don't want to rate-limit detect on narrower list of paths than you challenge on!
      Rack::Attack.track("bot_detect/rate_exceeded/#{self.name}",
          limit: self.bot_challenge_config.rate_limit_count,
          period: self.bot_challenge_config.rate_limit_period) do |req|
        if self.bot_challenge_config.enabled && self.bot_challenge_config.location_matcher.call(req, self.bot_challenge_config)
          self.bot_challenge_config.rate_limit_discriminator.call(req, self.bot_challenge_config)
        end
      end

      self._track_notification_subscription = ActiveSupport::Notifications.subscribe("track.rack_attack") do |_name, _start, _finish, request_id, payload|
        rack_request = payload[:request]
        rack_env     = rack_request.env
        match_name = rack_env["rack.attack.matched"]  # name of rack-attack rule
                                                      #
        if match_name == "bot_detect/rate_exceeded/#{self.name}"
          match_data   = rack_env["rack.attack.match_data"]
          match_data_formatted = match_data.slice(:count, :limit, :period).map { |k, v| "#{k}=#{v}"}.join(" ")
          discriminator = rack_env["rack.attack.match_discriminator"] # unique key for rate limit, usually includes ip

          rack_env[self.bot_challenge_config.env_challenge_trigger_key] = true
        end
      end
    end

    def self._rack_attack_uninit
      Rack::Attack.track("bot_detect/rate_exceeded/#{self.name}") {} # overwrite track name with empty proc
      ActiveSupport::Notifications.unsubscribe(self._track_notification_subscription) if self._track_notification_subscription
      self._track_notification_subscription = nil
    end

    # Usually in your ApplicationController,
    #
    #     before_action { |controller| BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller) }
    #
    # @param immediate [Boolean] always force bot protection, ignore any allowed pre-challenge rate limit
    def self.bot_challenge_enforce_filter(controller, immediate: false)
      if self.bot_challenge_config.enabled &&
          (controller.request.env[self.bot_challenge_config.env_challenge_trigger_key] || immediate) &&
          ! self._bot_detect_passed_good?(controller.request) &&
          ! controller.kind_of?(self) && # don't ever guard ourself, that'd be a mess!
          ! self.bot_challenge_config.allow_exempt.call(controller, self.bot_challenge_config)

        # we can only do GET requests right now
        if !controller.request.get?
          Rails.logger.warn("#{self}: Asked to protect request we could not, unprotected: #{controller.request.method} #{controller.request.url}, (#{controller.request.remote_ip}, #{controller.request.user_agent})")
          return
        end

        Rails.logger.info("#{self.name}: Cloudflare Turnstile challenge redirect: (#{controller.request.remote_ip}, #{controller.request.user_agent}): from #{controller.request.url}")
        # status code temporary
        controller.redirect_to controller.bot_detect_challenge_path(dest: controller.request.original_fullpath), status: 307
      end
    end

    # Does the session already contain a bot detect pass that is good for this request
    # Tie to IP address to prevent session replay shared among IPs
    def self._bot_detect_passed_good?(request)
      session_data = request.session[self.bot_challenge_config.session_passed_key]

      return false unless session_data && session_data.kind_of?(Hash)

      datetime = session_data[SESSION_DATETIME_KEY]
      ip   = session_data[SESSION_IP_KEY]

      (ip == request.remote_ip) && (Time.now - Time.iso8601(datetime) < self.bot_challenge_config.session_passed_good_for )
    end


    def challenge
      # possible custom render to choose layouts or templates, but normally
      # we just do default rails render and this proc is empty.
      if self.bot_challenge_config.challenge_renderer
        instance_exec &self.bot_challenge_config.challenge_renderer
      end
    end

    def verify_challenge
      body = {
        secret: self.bot_challenge_config.cf_turnstile_secret_key,
        response: params["cf_turnstile_response"],
        remoteip: request.remote_ip
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

      # let's just return the whole thing to client? Is there anything confidential there?
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
