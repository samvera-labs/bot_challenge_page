# BotChallengePage

[![CI](https://github.com/samvera-labs/bot_challenge_page/actions/workflows/ci.yml/badge.svg)](https://github.com/samvera-labs/bot_challenge_page/actions/workflows/ci.yml) [![Gem Version](https://badge.fury.io/rb/bot_challenge_page.png)](http://badge.fury.io/rb/bot_challenge_page)

BotChallengePage lets you protect certain **GET** routes in your Rails app with [CloudFlare Turnstile](https://www.cloudflare.com/application-services/products/turnstile/) "CAPTHCA alternate" bot detector. Rather than the typical form submission use case for Turnstile, the user will be redirected to an interstitial challenge page, and automatically redirected back immediately on success.

The motivating use case is fairly dumb (probably AI-related) crawlers crawling search results pages, rather than targetted attacks, although we have tried to pay attention to security.  Many of our use cases were crawlers getting caught following every combination of voluminous facet values in search results in a near "infinite space", and causing us resource usage issues.

![challenge page screenshot](docs/challenge-page-example.png)

* Support both immediate bot challenge, or optionally a rate limit that will trigger a bot challenge.

* Once a challenge is passed, the pass is stored in a cookie, and a challenge won't be redisplayed for a configurable amount of time, so long as cookie is present, and client matches a configurable user-agent/IP address fingerprint.

* **Note:** User-agent does always need both cookies and javascript enabled to be able to pass challenge and get through!


## Installation and Configuration

* Get a [CloudFlare account and Turnstile widget set up](https://www.cloudflare.com/application-services/products/turnstile/), which should give you a turnstile `sitekey` and `secret_key` you will need later in configuration.

* `bundle add bot_challenge_page`, `bundle install`

* Run the installer
  * `rails g bot_challenge_page:install`
  * This will add a line to your ApplicationController to include a mixin to provide a `bot_challenge` configuration method in your controllers
  * And a template configuration page at `./config/initializers/bot_challenge_page.rb`



* Configure in the generated `./config/initializers/bot_challenge_page.rb`
  * At a minimum you need to configure your Cloudflare Turnstile keys

  * Some other configuration options are offered -- more advanced/specialized ones are available that are not mentioned in generated config file, see [Config class](./lib/bot_challenge_page/config.rb)

## Protect some paths

You can add `bot_challenge` to a controller to protect all actions in that controller with a bot challenge.

You can also use all the Rails `before_action` params to apply to only some actions or requests in that controller: `only` and `except` to specify actions; and `if` and `unless` to specify procs to filter individual requests.

  * Note that we can only protect GET paths, and also think about making sure you DON'T protect
    any path your front-end needs JS `fetch` access to, as this would block it (at least
    without custom front-end code we haven't really explored)

  * If you are tempted to just protect `/` that may work, but you may need to exclude hearbeat paths, front-end (AJAX) requestable paths, API endpoints, uptime checker requests, or other machine-access-desired paths. These may be good candidates for an `unless` parameter, or the `skip_when` configuration.

  * The author is a librarian who believes maintaining machine access in general is a public good, and tries to limit access with a bot challenge to the minimum paths necessary for app sustainability.

  * The default configuration only allows re-use of a 'pass' cookie from requests with same IP address subnet and user-agent-related headers. This can be customized.

```ruby
class WidgetController < ApplicationController
  bot_challenge only: :index, unless: -> { headers['x-secret-code'] == "i_am_uptime-checker" }
end
```

### Protect some paths with a rate limit

If you want to display a bot challenge only after some rate is reached, you will need some [Rails cache store configured](https://guides.rubyonrails.org/caching_with_rails.html#configuration) to keep track of rate.  You can configure `Rails.config.cache`, or for bot_challenge_page specifically in it's config.

* Redis or Memcached are typical, but the `memory_store` cache can work if you don't mind your rate limits being only approximate -- they will reset on every web server process restart, and if you have more than one web server process they will each have their own rate limit.

You use the `after` and `within` argument to `bot_challenge` to include a rate limit. `only`, `except`, `if`, and `unless` are still supported.

```ruby
class WidgetController < ApplicationController
  bot_challenge after: 2, within: 3.hours, only: :index, if: -> { request_has_facet_limits? }
end
```

#### rate limit counters

By default, all `bot_challenge` directives share a rate limit counter. So if two differnet controllers have a `bot_challenge`, requests to either one add to the same counter for rate limit checks.

Which also means if you have more than one `bot_challenge` that can apply to the _same request_, it might get double-counted (or more-counted).  (Also too many rate-limited bot_challenges applying to the same request could have performance implications).

To avoid this problem or achieve desired behavior, you can pass a `counter` string into `bot_challenge` to declare separate counteres and decide which `bot_challenge` should or should not share counters.

The `counter` arg has overlapping use but distinct effect from passing in a `by` argument or setting `config.default_limit_by`, which lets you determine how user-agents are identified to share a counter bucket, which by default buckets clients by IP subnet, not just individual IP.

If a given request does not apply to `bot_challenge` because of `only`, `except`, `if`, `unless` or `config.skip_when` -- it **does not count toward rate limit either**.

## Customize challenge page display

Some of the default challenge page html uses bootstrap alert classes. You may want to provide custom CSS if you aren't using bootstrap. You can see the default challenge page html at [challenge.html.erb](./app/views/bot_challenge_page/bot_challenge_page/challenge.html.erb). You may wish to CSS-style other parts too!

You can customize all text via I18n, see keys in [bot_challenge_page.en.yml](./config/locales/bot_challenge_page.en.yml)

The challenge page by default will be displayed in your app's default rails `layout`.

To customize the layout or challenge page HTML more further, you can use configuration to supply a `render` method for the controller pointing to your own templates or other layouts. You will probably want to re-use the partials we use in our default template, for standard functionality. And you'll want to provide `<template>` elements with the same id's for those elements, but can put whatever you want inside the templates!

```ruby
config.challenge_renderer = ()->  {
  render "my_local_view_folder/whatever", layout "another_layout"
}
```

## Logging

By default we log when a challenge result is submitted to the back-end; you can find challenge passes or failures by searching your logs for `BotChallengePage`.

We do not log when a challenge is issued -- experience shows challenge issues far outnumber challenge results, and can fill up the logs too fast.

If you'd like to log or observe challenge issues, you can configure a proc that is executed
in the context of the controller, and is called when a page is blocked by a challenge.

```ruby
config.after_blocked = (_bot_challenge_class)->  {
  logger.info("page blocked by challenge: #{request.uri}")
}
```

Or, here's how I managed to get it in [lograge](https://github.com/roidrage/lograge), so a page blocked results in a `bot_chlng=true` param in a lograge line.

```ruby
config.after_blocked =
  ->(bot_detect_class) {
    request.env["bot_detect.blocked_for_challenge"] = true
  }


# production.rb
config.lograge.custom_payload do |controller|
  {
    bot_chlng: controller.request.env["bot_detect.blocked_for_challenge"]
  }.compact
end
```

Later, however, using similar mechanism, I actually suppressed logging of actions that resulted in bot challenges altogether -- they were exhausting my log platform quota.

## Example possible Blacklight config

Many of us in my professional community use [blacklight](https://github.com/projectblacklight/blacklight).  Here's a possible sample blacklight config to:

* Protect default catalog controller, including search results and any other actions
* ONLY if the search includes a query string or facet limit -- allow unfiltered search, including pagination, without bot challenge.
* Even for queried or limite results, give an IP subnet 1 free searches in a 36 hour period before challenged
* For the action used for "facet… more" links and `blacklight_range_limit` that need to be XHR/JS-fetchable --  exempt from protection if the request is being made by a browser JS `fetch`, we just let those through. (Which means a determined attacker could do that on purpose, not defense against on purpose DDoS)
* Let's an uptime checker in based on secret code in headers



```ruby
# ./config/initializers/bot_challenge_page.rb
BotChanngePage.configure do
  config.enabled = true

  # Need to set store to a Rails cache store other than null store, if you want to track
  # rate limits.  We chooes to use a different store than Rails.cache.
  config.store = ActiveSupport::Cache::RedisCacheStore.new(url: $some_redis_url)

  # Get from CloudFlare Turnstile: https://www.cloudflare.com/application-services/products/turnstile/
  config.cf_turnstile_sitekey = "MUST GET"
  config.cf_turnstile_secret_key = "MUST GET"

  config.skip_when = ->(config) {
    # Exempt honeybadger token to allow HB uptime checker in
    # https://docs.honeybadger.io/guides/security/
    (
      ENV['HONEYBADGER_TOKEN'].present? &&
      controller.request.headers['Honeybadger-Token'] == ENV['HONEYBADGER_TOKEN']
    )
  }

end
```

```ruby
# ./app/controllers/catalog_controller.rb
class CatalogController < ApplicationController
  # from default blacklight first...
  include Blacklight::Catalog
  include BlacklightRangeLimit::ControllerOverride

   # This should apply to all CatalogController sub-classes too, which include CollectionShowController and
  # FeaturedTopicController. They all share a counter though.
  #
  # We let bots through if they have NO query params, we want let collection/focus sploash
  # pages be indexed -- this will actually let bot paginate through entire results with
  # no query/facets, which we seem to be able to tolerate.
  #
  bot_challenge after: 1, within: 12.hours,
    if: -> {
      has_search_parameters?
    },
    except: ["facet", "range_limit"]

  # facet and range_limit both get challenged immediately, unless they are JS fetch,
  # in which case they are let in freely.
  bot_challenge only: ["facet", "range_limit"], unless: -> {
    request.headers["sec-fetch-dest"] == "empty"
  }

end
```

## Development and automated testing

All logic and config hangs off a controller, with the idea that you could sub-class the controller to override any functionality -- or even have multiple sub-classes in your app with different configuration or customized config. But this hasn't really been tested/fleshed out yet.

Run tests with `bundle exec rspec`.

We test with a checked-into-repo dummy app at `./spec/dummy`, and use [Appraisal](https://github.com/thoughtbot/appraisal) to test under different rails versions.

Locally one way to test with a specific rails version appraisal is `bundle exec appraisal rails-7.2 rspec`

If you make any changes to `Gemfile` you may need to run `bundle exec appraisal install` and commit changes.

**One reason tests are slow** is I think we're running system tests with real turnstile proof-of-work bot detection JS code? (Or is it, when we are are using a CF turnstile testing key that always passes?).  There aren't many tests so it's no big deal, but this is something that could be investigated/optmized more potentially.

## Possible future features?

* We could support swap-in Turnstile-alternatives, like [hCAPTHCA](https://www.hcaptcha.com/), [Google reCAPTCHA v3](https://developers.google.com/recaptcha/docs/v3), or even open source proof of work implementations like [ALTCHA](https://altcha.org/docs/get-started/), [pow-bot-deterrent](https://github.com/sequentialread/pow-bot-deterrent), or [Friendly Captcha](https://github.com/FriendlyCaptcha/friendly-captcha-sdk).  But the (free) cost/benefit of Turnstile are pretty good, so I don't myself have a lot of motivation to add this complexity.

* Something to make it easier to switch the challenge on only based on signals that server/app is under some defined heavy load?

* Use the in-development [bot auth](https://developers.cloudflare.com/bots/concepts/bot/verified-bots/web-bot-auth/) standard, to support allow-listing of specified auth\'d bots.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## See also/Acknowledgements

* [Joe Corral's blog post](https://lehigh-university-libraries.github.io/blog/turnstile.html) about using this approach at Lehigh University Libraries with an islandora/drupal app.

* Joe's [similar plugin for drupal](https://drupal.org/project/turnstile_protect)

* Joe's [similar plugin for traefik reverse-proxy](https://github.com/libops/captcha-protect)

* [Similar feature built into PHP VuFind app](https://github.com/vufind-org/vufind/pull/4079)

* [My own blog post about this approach](https://bibwild.wordpress.com/2025/01/16/using-cloudflare-turnstile-to-protect-certain-pages-on-a-rails-app/).

* Wow only after I developed all this did I notice [rails-cloudflare-turnstile](https://github.com/instrumentl/rails-cloudflare-turnstile) which implements some pieces that could have been re-used here, but I feel good becuase we wanted these weird features. But if you want a much simpler more straightforward Turnstile implementation for more standard use cases or your own different use cases, I'd go here.

* And yet another implementation in Rails that perhaps makes more assumptions about use cases, [turnstile-captcha](https://github.com/pfeiffer/turnstile-captcha). Haven't looked at it much.


