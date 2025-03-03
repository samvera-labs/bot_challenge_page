module BotChallengePage

  # Extracted to concern in separate file mostly for readability, not expected to be used
  # anywehre but BotChallengePageController -- we hang all logic off controller to allow multiple
  # controllers in an app, and over-ride in sub-classes.
  module RackAttackInit
    extend ActiveSupport::Concern


    class_methods do
      # perhaps in an initializer, and after changing any config, run:
      #
      #     Rails.application.config.to_prepare do
      #       BotChallengePage::BotChallengePageController.rack_attack_init
      #     end
      #
      # Safe to call more than once if you change config and want to call again, say in testing.
      def rack_attack_init
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

      def _rack_attack_uninit
        Rack::Attack.track("bot_detect/rate_exceeded/#{self.name}") {} # overwrite track name with empty proc
        ActiveSupport::Notifications.unsubscribe(self._track_notification_subscription) if self._track_notification_subscription
        self._track_notification_subscription = nil
      end
    end
  end
end
