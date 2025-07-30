module BotChallengePage
  # To be included in app controllers to make `bot_challenge` class method macro available.
  module Controller
    extend ActiveSupport::Concern

    class_methods do
      def bot_challenge(challenge_controller: BotChallengePage::BotChallengePageController,
                        after:nil,
                        within:nil,
                        by: ->{
                          challenge_controller.bot_challenge_config.rate_limit_discriminator.call(request, challenge_controller.bot_challenge_config)
                        },
                        store: challenge_controller.bot_challenge_config.store || cache_store,
                        name: nil,
                        **before_action_options)



        unless_arg = before_action_options.delete(:unless)
        generated_unless = -> {
          (unless_arg && instance_exec(&unless_arg)) ||
          (challenge_controller.bot_challenge_config.allow_exempt.call(self, challenge_controller.bot_challenge_config))
        }

        if after
          unless within
            raise ArgumentError.new("either both or neither of `after` and `within` must be speciied")
          end

          rate_limit(to: after, within: within, by: by,  store: store, name: name,
            with: ->{
              challenge_controller.bot_challenge_enforce_filter(self)
            },
            unless: generated_unless,
            **before_action_options)
        else
          before_action(unless: generated_unless, **before_action_options) do
            ActiveSupport::Notifications.instrument("bot_challenge_page.action_controller", request: request) do
              challenge_controller.bot_challenge_enforce_filter(self)
            end
          end
        end
      end
    end
  end
end
