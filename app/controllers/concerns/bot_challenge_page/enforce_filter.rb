module BotChallengePage

  # Extracted to concern in separate file mostly for readability, not expected to be used
  # anywehre but BotChallengePageController -- we hang all logic off controller to allow multiple
  # controllers in an app, and over-ride in sub-classes.
  module EnforceFilter
    extend ActiveSupport::Concern

    class_methods do
      # Usually in your ApplicationController, unless using `immediate`.
      #
      #     before_action { |controller| BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller) }
      #
      # @param immediate [Boolean] always force bot protection, ignore any allowed pre-challenge rate limit
      def bot_challenge_enforce_filter(controller, immediate: false)
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

          # Prevent caching of bot challenge page
          controller.response.headers["Cache-Control"] = "no-store"

          if self.bot_challenge_config.redirect_for_challenge
            # status code temporary
            controller.redirect_to controller.bot_detect_challenge_path(dest: controller.request.original_fullpath), status: 307
          else
            # hacky way to get config to view template in an arbitrary controller, good enough for now
            controller.instance_variable_set("@bot_challenge_config", self.bot_challenge_config) unless controller.instance_variable_get("@bot_challenge_config")
            controller.instance_exec &self.bot_challenge_config.challenge_renderer
          end
        end
      end

      # Does the session already contain a bot detect pass that is good for this request
      # Tie to IP address to prevent session replay shared among IPs
      def _bot_detect_passed_good?(request)
        session_data = request.session[self.bot_challenge_config.session_passed_key]

        return false unless session_data && session_data.kind_of?(Hash)

        datetime = session_data[BotChallengePageController::SESSION_DATETIME_KEY]
        ip   = session_data[BotChallengePageController::SESSION_IP_KEY]

        (ip == request.remote_ip) && (Time.now - Time.iso8601(datetime) < self.bot_challenge_config.session_passed_good_for )
      end
    end
  end
end
