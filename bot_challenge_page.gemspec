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

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0.1"
end
