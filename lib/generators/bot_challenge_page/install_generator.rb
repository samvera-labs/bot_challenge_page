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

    def add_controller_mixin
      inject_into_class "app/controllers/application_controller.rb", "ApplicationController", "  include BotChallengePage::Controller\n"
    end

    def copy_initializer_file
      template "initializer.rb.erb", "config/initializers/bot_challenge_page.rb"
    end
  end
end
