module BotChallengePage
  class Config
    # meh let's do a little accessor definition to make this value class more legible

    # default can be a proc, in which case it really is a proc as a value for default,
    # the value is the proc!
    def self.attribute(name, default:nil)
      attr_defaults[name] = default
      self.attr_accessor name
    end

    class_attribute :attr_defaults, default: {}, instance_accessor: false

    def initialize(**values)
      self.class.attr_defaults.merge(values).each_pair do |key, value|
        # super hacky way to execute any procs in the context of this config,
        # so they can access other config values easily.
        if value.kind_of?(Proc)
          newval = lambda do |*args|
            self.instance_exec(*args, &value)
          end
        else
          newval = value
        end

        send("#{key}=", newval)
      end
    end

    # Should we redirect to a challenge page (true) or just display it inline
    # with a 403 status (false)
    attribute :redirect_for_challenge, default: false

    attribute :enabled, default: false # Must set to true to turn on at all

    attribute :cf_turnstile_sitekey, default: "1x00000000000000000000AA" # a testing key that always passes
    attribute :cf_turnstile_secret_key, default: "1x0000000000000000000000000000000AA" # a testing key always passes
    # Turnstile testing keys: https://developers.cloudflare.com/turnstile/troubleshooting/testing/

    # up to rate_limit_count requests in rate_limit_period before challenged
    attribute :rate_limit_period,  default: 12.hour
    attribute :rate_limit_count,  default: 10

    # how long is a challenge pass good for before re-challenge?
    attribute :session_passed_good_for,  default: 24.hours

    # An array, can be:
    #   * a string, path prefix
    #   * a hash of rails route-decoded params, like `{ controller: "something" }`,
    #     or `{ controller: "something", action: "index" }
    #     The hash is more expensive to check and uses some not-technically-public
    #     Rails api, but it's just so convenient.
    #
    # Used by default :location_matcher, if set custom may not be used
    attribute :rate_limited_locations, default: []

    # Executed at the _controller_ filter level, to last minute exempt certain
    # actions from protection.
    attribute :allow_exempt, default: ->(controller, config) { false }

    # replace with say `->() { render layout: 'something' }`, or `render "somedir/some_template"`
    attribute :challenge_renderer, default: ->() {
      render "bot_challenge_page/bot_challenge_page/challenge", status: 403
    }


    # rate limit per subnet, following lehigh's lead, although we use a smaller
    # subnet: /24 for IPv4, and /72 for IPv6
    # https://git.drupalcode.org/project/turnstile_protect/-/blob/0dae9f95d48f9d8cae5a8e61e767c69f64490983/src/EventSubscriber/Challenge.php#L140-151
    attribute :rate_limit_discriminator, default: (lambda do |req, config|
      if req.ip.index(":") # ipv6
        IPAddr.new("#{req.ip}/24").to_string
      else
        IPAddr.new("#{req.ip}/72").to_string
      end
    rescue IPAddr::InvalidAddressError
      req.ip
    end)

    attribute :location_matcher, default: ->(rack_req, config) {
      parsed_route = nil
      config.rate_limited_locations.any? do |val|
        case val
        when Hash
          begin
            # #recognize_path may e not techinically public API, and may be expensive, but
            # no other way to do this, and it's mentioned in rack-attack:
            # https://github.com/rack/rack-attack/blob/86650c4f7ea1af24fe4a89d3040e1309ee8a88bc/docs/advanced_configuration.md#match-actions-in-rails
            # We do it lazily only if needed so if you don't want that don't use it.
            parsed_route ||= rack_req.env["action_dispatch.routes"].recognize_path(rack_req.url, method: rack_req.request_method)
            parsed_route && parsed_route >= val
          rescue ActionController::RoutingError
            false
          end
        when String
          # string complete path at beginning, must end in ?, or end of string
          /\A#{Regexp.escape val}(\/|\?|\Z)/ =~ rack_req.path
        end
      end
    }
    attribute :cf_turnstile_js_url, default: "https://challenges.cloudflare.com/turnstile/v0/api.js"
    attribute :cf_turnstile_validation_url, default:  "https://challenges.cloudflare.com/turnstile/v0/siteverify"
    attribute :cf_timeout, default: 3 # max timeout seconds waiting on Cloudfront Turnstile api


    # key stored in Rails session object with channge passed confirmed
    attribute :session_passed_key, default: "bot_detection-passed"

    # key in rack env that says challenge is required
    attribute :env_challenge_trigger_key, default: "bot_detect.should_challenge"

    attribute :still_around_delay_ms, default: 1200

    # make sure dup dups all attributes please
    def initialize_dup(source)
      self.class.attr_defaults.keys.each do |attr_key|
        instance_variable_set("@#{attr_key}", instance_variable_get("@#{attr_key}").deep_dup)
        super
      end
    end
  end
end
