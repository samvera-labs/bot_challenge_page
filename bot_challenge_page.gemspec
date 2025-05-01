require_relative "lib/bot_challenge_page/version"

Gem::Specification.new do |spec|
  spec.name        = "bot_challenge_page"
  spec.version     = BotChallengePage::VERSION
  spec.authors     = [ "Jonathan Rochkind" ]
  spec.email       = [ "jonathan@dnil.net" ]
  spec.homepage    = "https://github.com/samvera-labs/bot_challenge_page"
  spec.summary     = "Show a bot challenge interstitial for Rails, usually using Cloudflare Turnstile"
  # spec.description = "TODO: Description of BotChallengePage."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/samvera-labs/bot_challenge_page"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "rspec-rails", "~> 8.0"
  spec.add_development_dependency "capybara", "~> 3.40"
  spec.add_development_dependency 'selenium-webdriver'
  spec.add_development_dependency "webmock", "~> 3.5"
  spec.add_development_dependency "nokogiri"

  spec.add_dependency "rails", ">= 7.1", "< 8.1"
  spec.add_dependency "rack-attack", "~> 6.7"
  spec.add_dependency "http", "~> 5.2"
end
