##

## 1.0.0

No change from 0.11.0, decided to call it a 1.0 release.

## 0.11.0

* provide HTTP link header to preload turnstile script src, for page speed performance of challenge page https://github.com/samvera-labs/bot_challenge_page/pull/15

## 0.10.0

* Large rewrite of how configuration is done, very backwards compatible
  * Sorry, this is pre-1.0 -- but we are on the right track now, and expect to go 1.0 soon
    with little or no subsequent backwards incompat!
  * It should not be too hard to rewrite your config and directives, and hopefully should
    be much simpler as well as more flexible -- different rate limits on different paths or other request criteria are now possible. Please consult new README
  * You may need to remove much of your previous code -- if it's broken it should raise, don't
    worry about it doing the wrong thing or anything like that.

* rack-attack is no longer a dependency or used for rate limits -- you still need a stateful cache store of some kind for rate limits.


## 0.4.0

* Expand default buckets for rate limits to  /16 for IPv4 (x.y.*.*), and /64 for IPv6. https://github.com/samvera-labs/bot_challenge_page/pull/11

## 0.3.1

* Fix proper calculations of subnet for rate-limiting. Wasn't working properly before,
  only single IP address was being used for IPv4. https://github.com/samvera-labs/bot_challenge_page/pull/8

## 0.3.0

* New direct inline challenge (instead of redirect) available and is default.
  Opt into old behavior with config `redirect_for_challenge = true`. https://github.com/samvera-labs/bot_challenge_page/pull/2

* To implement that, the way of passing data into challenge templates has changed, and
  if you've done customization of templates you will have to re-do it new way, based
  on new templates. (i18n overrides are still fine and backwards compat). Sorry,
  we are pre-1.0 because we are still figuring out the API patterns we need!

* Also means challenge pages are delivered with HTTP status 403 now. And headers for no http
  caching.

* fix `allow_exempt` example in comment in generated initializer. Thanks @lfarrell, https://github.com/samvera-labs/bot_challenge_page/pull/5

* No longer by default logs when a page is blocked for challenge, but can log how you want with config `after_blocked`. https://github.com/samvera-labs/bot_challenge_page/pull/7
