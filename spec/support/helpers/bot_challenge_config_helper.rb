module BotChallengeConfigHelper
  def with_bot_challenge_config(controller, **args)
    orig_config = controller.bot_challenge_config.dup

    args.each_pair do |key, value|
      controller.bot_challenge_config.send("#{key}=", value)
    end
    controller.rack_attack_init

    yield

    controller.bot_challenge_config = orig_config
    controller.rack_attack_init
  end
end
