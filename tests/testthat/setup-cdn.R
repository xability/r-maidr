# No test asks the network which maidr.js is the latest. Every CDN document
# rendered in this suite would otherwise make the lookup on its first render,
# and a test must not need the network (CRAN policy) or wait on it. The one
# function that makes the request is replaced for the whole run, so a lookup
# fails at once and documents name the bundled version; the tests of the lookup
# itself (test-cdn-version.R) replace it again with the answers they need,
# and the unmocked original is kept for the test of the request itself.
cdn_resolver_request_unmocked <- maidr:::maidr_cdn_resolver_request
testthat::local_mocked_bindings(
  maidr_cdn_resolver_request = function(url, timeout) {
    stop("the network is not used in tests", call. = FALSE)
  },
  .package = "maidr",
  .env = testthat::teardown_env()
)
maidr:::maidr_reset_cdn_cache()
