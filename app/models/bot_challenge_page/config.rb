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
        send("#{key}=", value)
      end
    end

    # Should we redirect to a challenge page (true) or just display it inline
    # with a 403 status (false)
    attribute :redirect_for_challenge, default: false

    attribute :enabled, default: false # Must set to true to turn on at all

    # ActiveSupport::Cache::Store to use for rate info, if nil will use Controller #cache_store
    attribute :store

    attribute :cf_turnstile_sitekey, default: "1x00000000000000000000AA" # a testing key that always passes
    attribute :cf_turnstile_secret_key, default: "1x0000000000000000000000000000000AA" # a testing key always passes
    # Turnstile testing keys: https://developers.cloudflare.com/turnstile/troubleshooting/testing/

    # how long is a challenge pass good for before re-challenge?
    attribute :session_passed_good_for,  default: 24.hours


    # Executed inside a controller instance, to omit a request from bot challenge.
    # Adds on to :unless arg.
    attribute :except_filter, default: ->(config) { false }

    # replace with say `->() { render layout: 'something' }`, or `render "somedir/some_template"`
    attribute :challenge_renderer, default: ->() {
      render "bot_challenge_page/bot_challenge_page/challenge", status: 403
    }

    attribute :after_blocked, default: ->(bot_detect_class) {}


    # rate limit per subnet, follow lehigh's lead with
    # subnet: /16 for IPv4 (x.y.*.*), and /64 for IPv6 (about the same size subnet for better or worse)
    # https://git.drupalcode.org/project/turnstile_protect/-/blob/0dae9f95d48f9d8cae5a8e61e767c69f64490983/src/EventSubscriber/Challenge.php#L140-151
    attribute :default_limit_by, default: (lambda do |config|
      if request.ip.index(":") # ipv6
        IPAddr.new("#{request.ip}/64").to_string
      else
        IPAddr.new("#{request.ip}/16").to_string
      end
    rescue IPAddr::InvalidAddressError
      req.ip
    end)

    # fingerprint is taken when "pass" is stored in session. client
    # fingerprint needs to be the same to use pass, or else it's rejected.
    #
    # Algorithm parts based on advice from Xe laso @ Anubis, with variations.
    #
    # Allow exact IP to change -- various IPv6 and NAT can make it -- but within limited
    # subnet.  But also force some other headers to match, which they should if it's the same
    # user-agent, which it should be if it's re-using a cookie.
    attribute :session_valid_fingerprint, default: ->(request) {
      ip_subnet_base = if request.remote_ip.index(":") #ipv6
        IPAddr.new("#{request.remote_ip}/64").to_string
      else
        IPAddr.new("#{request.remote_ip}/24").to_string
      end

      [
        request.user_agent,
        request.headers['sec-ch-ua-platform'],
        request.headers['accept-encoding'],
        ip_subnet_base
      ].join(":")
    }


    attribute :cf_turnstile_js_url, default: "https://challenges.cloudflare.com/turnstile/v0/api.js"
    attribute :cf_turnstile_validation_url, default:  "https://challenges.cloudflare.com/turnstile/v0/siteverify"
    attribute :cf_timeout, default: 3 # max timeout seconds waiting on Cloudfront Turnstile api

    # key stored in Rails session object with channge passed confirmed
    attribute :session_passed_key, default: "bot_detection-passed"

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
