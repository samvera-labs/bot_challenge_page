## 0.3.0

* New direct inline challenge (instead of redirect) available and is default.
  Opt into old behavior with config `redirect_for_challenge = true`. https://github.com/samvera-labs/bot_challenge_page/pull/2

* To implement that, the way of passing data into challenge templates has changed, and
  if you've done customization of templates you will have to re-do it new way, based
  on new templates. (i18n overrides are still fine and backwards compat). Sorry,
  we are pre-1.0 because we are still figuring out the API patterns we need!

* Also means challenge pages are delivered with HTTP status 403 now. And headers for no http
  caching.

