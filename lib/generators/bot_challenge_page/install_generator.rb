module BotChallengePage
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :'rack_attack', type: :boolean, default: true, desc: "Support rate-limit allowance configuration"
    class_option :redirect_for_challenge, type: :boolean, default: false, desc: "Redirect to separate challenge page instead of inline challenge"

    def generate_routes
      route 'post "/challenge", to: "bot_challenge_page/bot_challenge_page#verify_challenge", as: :bot_detect_challenge'

      if options[:redirect_for_challenge]
        route 'get "/challenge", to: "bot_challenge_page/bot_challenge_page#challenge"'
      end
    end

    def add_before_filter_enforcement
      # make the user do this themselves if they aren't using rack-attack, as it should
      # only be on protected filters
      return unless options[:rack_attack]

      inject_into_class "app/controllers/application_controller.rb", "ApplicationController" do
        filter_code = "BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller)"

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

    def suggest_filter
      unless options[:rack_attack]
        instructions = <<~EOS
        You must add before_action to protect controllers

        Add, eg:

            before_action only: :index do |controller|
              BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller, immediate: true)
            end

        To desired controllers and/or ApplicationController
        EOS

        say_status("advise", instructions, :green)
      end
    end

  end
end
