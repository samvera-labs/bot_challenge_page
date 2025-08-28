module BotChallengePage

  # Extracted to concern in separate file mostly for readability, not expected to be used
  # anywehre but BotChallengePageController -- we hang all logic off controller to allow multiple
  # controllers in an app, and over-ride in sub-classes.
  module GuardAction
    extend ActiveSupport::Concern

    class_methods do
      # All the logic for enforcing bot challenge protection, usually in a before_filter
      # of some kind, direct or rate_limit.
      #
      # Render challenge page when necessary, otherwise do nothing allowing ordinary rails render.
      def bot_challenge_guard_action(controller)
        if self.bot_challenge_config.enabled &&
            ! self._bot_detect_passed_good?(controller.request) &&
            ! controller.kind_of?(self) # don't ever guard ourself, that'd be a mess!

          # we can only do GET requests right now
          if !controller.request.get?
            Rails.logger.warn("#{self}: Asked to protect request we could not, unprotected: #{controller.request.method} #{controller.request.url}, (#{controller.request.remote_ip}, #{controller.request.user_agent})")
            return
          end

          # Prevent caching of bot challenge page
          controller.response.headers["Cache-Control"] = "no-store"

          if self.bot_challenge_config.redirect_for_challenge
            # status code temporary
            controller.redirect_to controller.bot_detect_challenge_path(dest: controller.request.original_fullpath), status: 307
          else
            # hacky way to get config to view template in an arbitrary controller, good enough for now
            controller.instance_variable_set("@bot_challenge_config", self.bot_challenge_config) unless controller.instance_variable_get("@bot_challenge_config")

            # set preload HTTP header with turnstile url for better page speed
            # May or may not be one there already, we can always add on
            preload_link_value = %Q{<#{self.bot_challenge_config.cf_turnstile_js_url}>; rel=preload; as=script}
            if controller.headers["link"].present?
              controller.headers["link"] += ",#{preload_link_value}"
            else
              controller.headers["link"] = "#{preload_link_value}"
            end

            controller.instance_exec &self.bot_challenge_config.challenge_renderer
          end

          # allow app to see and log if desired
          controller.instance_exec(self, &self.bot_challenge_config.after_blocked)
        end
      end

      # Does the session already contain a bot detect pass that is good for this request
      # Tie to IP address to prevent session replay shared among IPs
      def _bot_detect_passed_good?(request)
        session_data = request.session[self.bot_challenge_config.session_passed_key]

        return false unless session_data && session_data.kind_of?(Hash)

        datetime = session_data[self::SESSION_DATETIME_KEY]

        fingerprint   = session_data[self::SESSION_FINGERPRINT_KEY]

        (Time.now - Time.iso8601(datetime) < self.bot_challenge_config.session_passed_good_for ) &&
        fingerprint == self.bot_challenge_config.session_valid_fingerprint.call(request)
      end
    end
  end
end
