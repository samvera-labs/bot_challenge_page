module BotChallengePage
  # To be included in app controllers to make `bot_challenge` class method macro available.
  module Controller
    extend ActiveSupport::Concern

    class_methods do
      def bot_challenge(challenge_controller: BotChallengePage::BotChallengePageController,
                        after:nil,
                        within:nil,
                        by: ->{
                          instance_exec(challenge_controller.bot_challenge_config, &challenge_controller.bot_challenge_config.default_limit_by)
                        },
                        store: challenge_controller.bot_challenge_config.store || cache_store,
                        counter: nil,
                        **before_action_options)



        unless_arg = before_action_options.delete(:unless)
        generated_unless = -> {
          (unless_arg && instance_exec(&unless_arg)) ||
          instance_exec(challenge_controller.bot_challenge_config, &challenge_controller.bot_challenge_config.skip_when)
        }

        if after
          unless within
            raise ArgumentError.new("either both or neither of `after` and `within` must be speciied")
          end

          self._bot_challenge_rate_limit_with_context(to: after, within: within, by: by,  store: store,
            context: ["bot_challenge", counter].compact.join('.'),
            with: ->{
              challenge_controller.bot_challenge_guard_action(self)
            },
            unless: generated_unless,
            **before_action_options)
        else
          before_action(unless: generated_unless, **before_action_options) do
            ActiveSupport::Notifications.instrument("before_action.bot_challenge_page", request: request) do
              challenge_controller.bot_challenge_guard_action(self)
            end
          end
        end
      end


      # Copied from https://github.com/rails/rails/pull/55299, it's just rails rate_limit with added
      # `context` arg which we need
      #
      # https://github.com/rails/rails/pull/55299/commits/b9b7a7a8ab6e50c654619ae42e2b342ab7617f91
      #
      # If this is merged into rails in future, we can use plain old rate_limit
      #
      def _bot_challenge_rate_limit_with_context(to:, within:, by: -> { request.remote_ip }, with: -> { head :too_many_requests }, store: cache_store, name: nil, context: nil, **options)
        before_action -> { _bot_challenge_rate_limiting_with_context(to: to, within: within, by: by, with: with, store: store, name: name, context: context) }, **options
      end
    end

    private

    # Copied from https://github.com/rails/rails/pull/55299, it's just rails rate_limit with added
    # `context` arg which we need
    #
    # https://github.com/rails/rails/pull/55299/commits/b9b7a7a8ab6e50c654619ae42e2b342ab7617f91
    #
    # If this is merged into rails in future, we can use plain old rate_limit
    #
    def _bot_challenge_rate_limiting_with_context(to:, within:, by:, with:, store:, name:, context:)
      by = instance_exec(&by)
      cache_key = ["rate-limit", context || controller_path, name, by].compact.join(":")
      count = store.increment(cache_key, 1, expires_in: within)
      if count && count > to
        ActiveSupport::Notifications.instrument("rate_limit.action_controller",
            request: request,
            count: count,
            to: to,
            within: within,
            by: by,
            name: name,
            context: context,
            cache_key: cache_key) do
          instance_exec(&with)
        end
      end
    end
  end
end
