module BotChallengePage
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :'rack_attack', type: :boolean, default: true, desc: "Support rate-limit allowance configuration"

    def generate_routes
      route 'get "/challenge", to: "bot_challenge_page/bot_challenge_page#challenge", as: :bot_detect_challenge'
      route 'post "/challenge", to: "bot_challenge_page/bot_challenge_page#verify_challenge"'
    end

    def add_before_filter_enforcement
      inject_into_class "app/controllers/application_controller.rb", "ApplicationController" do
        filter_code = if options[:rack_attack]
          "BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller)"
        else
          "BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller, immediate: true)"
        end

        <<-EOS
  # This will only protect CONFIGURED routes, but also could be put on just certain
  # controllers, it does not need to be in ApplicationController
  before_action do |controller|
    #{filter_code}
  end

        EOS
      end
    end

    def add_rack_attack_require_if_needed
      if options[:rack_attack]
        # since it's an intermediate dependency, we need to require it after rails
        # so it will load it's rails stuff
        inject_into_file "config/application.rb", "\nrequire 'rack/attack'\n", after: /require.*rails\/[^\n]+\n/m

      end
    end

    def copy_initializer_file
      template "initializer.rb.erb", "config/initializers/bot_challenge_page.rb"
    end

  end
end
