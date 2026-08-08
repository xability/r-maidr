# Tests for R/html_dependencies.R
#
# The internet probe must never actually reach the network here: every test
# below mocks curl::has_internet() and counts how often it is consulted.

# ==============================================================================
# Helpers
# ==============================================================================

# Put the shared asset cache into a known state. Passing nothing empties the
# internet entry, which is how each test leaves it for the next one.
set_internet_cache <- function(internet = NULL, checked_at = NULL) {
  cache <- maidr:::.maidr_asset_cache
  cache$internet <- internet
  cache$internet_checked_at <- checked_at

  invisible(NULL)
}

ttl_seconds <- function() {
  maidr:::MAIDR_INTERNET_CACHE_TTL
}

# ==============================================================================
# maidr_internet_available Tests
# ==============================================================================

test_that("a cold cache probes once and records the answer plus a timestamp", {
  on.exit(set_internet_cache(), add = TRUE)
  set_internet_cache()

  probes <- 0L
  testthat::local_mocked_bindings(
    has_internet = function(...) {
      probes <<- probes + 1L
      TRUE
    },
    .package = "curl"
  )

  before <- Sys.time()
  testthat::expect_true(maidr:::maidr_internet_available())
  after <- Sys.time()

  testthat::expect_identical(probes, 1L)
  testthat::expect_true(maidr:::.maidr_asset_cache$internet)

  stamp <- maidr:::.maidr_asset_cache$internet_checked_at
  testthat::expect_s3_class(stamp, "POSIXct")
  testthat::expect_gte(as.numeric(stamp), as.numeric(before))
  testthat::expect_lte(as.numeric(stamp), as.numeric(after))
})

test_that("a cached probe inside the TTL window is reused without re-probing", {
  on.exit(set_internet_cache(), add = TRUE)

  probes <- 0L
  testthat::local_mocked_bindings(
    has_internet = function(...) {
      probes <<- probes + 1L
      TRUE
    },
    .package = "curl"
  )

  # Cached FALSE, probed one second ago: still inside the window.
  set_internet_cache(internet = FALSE, checked_at = Sys.time() - 1)

  testthat::expect_false(maidr:::maidr_internet_available())
  testthat::expect_false(maidr:::maidr_internet_available())

  # The whole point of the cache: no probe, however many plots render.
  testthat::expect_identical(probes, 0L)
})

test_that("a cached probe outside the TTL window is re-probed", {
  on.exit(set_internet_cache(), add = TRUE)

  probes <- 0L
  testthat::local_mocked_bindings(
    has_internet = function(...) {
      probes <<- probes + 1L
      TRUE
    },
    .package = "curl"
  )

  # A transient failure from just over the TTL ago must not pin the session.
  stale_at <- Sys.time() - (ttl_seconds() + 1)
  set_internet_cache(internet = FALSE, checked_at = stale_at)

  testthat::expect_true(maidr:::maidr_internet_available())
  testthat::expect_identical(probes, 1L)

  # The refreshed answer is cached again, so the next plot does not probe.
  testthat::expect_true(maidr:::maidr_internet_available())
  testthat::expect_identical(probes, 1L)
  testthat::expect_gt(
    as.numeric(maidr:::.maidr_asset_cache$internet_checked_at),
    as.numeric(stale_at)
  )
})

test_that("a stale success self-heals to FALSE once the machine is offline", {
  on.exit(set_internet_cache(), add = TRUE)

  testthat::local_mocked_bindings(
    has_internet = function(...) FALSE,
    .package = "curl"
  )

  set_internet_cache(
    internet = TRUE,
    checked_at = Sys.time() - (ttl_seconds() + 1)
  )

  # Otherwise every later render points at a CDN this machine cannot reach.
  testthat::expect_false(maidr:::maidr_internet_available())
})

test_that("a cache entry without a timestamp is re-probed", {
  on.exit(set_internet_cache(), add = TRUE)

  probes <- 0L
  testthat::local_mocked_bindings(
    has_internet = function(...) {
      probes <<- probes + 1L
      TRUE
    },
    .package = "curl"
  )

  # Shape written by the previous, untimed cache implementation.
  set_internet_cache(internet = FALSE, checked_at = NULL)

  testthat::expect_true(maidr:::maidr_internet_available())
  testthat::expect_identical(probes, 1L)
})

test_that("a timestamp from the future is not trusted", {
  on.exit(set_internet_cache(), add = TRUE)

  probes <- 0L
  testthat::local_mocked_bindings(
    has_internet = function(...) {
      probes <<- probes + 1L
      TRUE
    },
    .package = "curl"
  )

  # Clock moved backwards; the cache entry is unusable either way.
  set_internet_cache(internet = FALSE, checked_at = Sys.time() + 3600)

  testthat::expect_true(maidr:::maidr_internet_available())
  testthat::expect_identical(probes, 1L)
})

test_that("a failing probe is treated as offline and still cached", {
  on.exit(set_internet_cache(), add = TRUE)
  set_internet_cache()

  probes <- 0L
  testthat::local_mocked_bindings(
    has_internet = function(...) {
      probes <<- probes + 1L
      stop("no resolver")
    },
    .package = "curl"
  )

  testthat::expect_false(maidr:::maidr_internet_available())
  testthat::expect_false(maidr:::maidr_internet_available())
  testthat::expect_identical(probes, 1L)
})

test_that("the TTL is a positive finite number of seconds", {
  testthat::expect_true(is.numeric(ttl_seconds()))
  testthat::expect_length(ttl_seconds(), 1)
  testthat::expect_gt(ttl_seconds(), 0)
  testthat::expect_true(is.finite(ttl_seconds()))
})

# ==============================================================================
# Bundled asset Tests
# ==============================================================================

# maidr.js resolves maidr-math.css against the URL it was itself loaded from,
# so the bundled copy has to sit beside it in the lib directory. When it does
# not, the failure is silent and narrow: LaTeX in AI chat responses renders
# unstyled and nothing else changes, so only a reader who opened the chat
# would ever notice.

test_that("the bundled KaTeX stylesheet ships beside maidr.js", {
  assets <- maidr:::maidr_local_assets()

  testthat::expect_true(file.exists(assets$js))
  testthat::expect_true(file.exists(assets$math_css))
  testthat::expect_identical(basename(assets$math_css), "maidr-math.css")
  testthat::expect_identical(dirname(assets$math_css), dirname(assets$js))
})

test_that("the bundled KaTeX stylesheet is font-stripped but still styles maths", {
  css <- paste(
    readLines(maidr:::maidr_local_assets()$math_css, warn = FALSE),
    collapse = "\n"
  )

  # The web fonts are ~349 kB of base64 and would put the installed package
  # back over CRAN's size limit; the layout rules are the part that makes
  # mathematics render correctly, and they have to survive the strip.
  testthat::expect_false(grepl("@font-face", css, fixed = TRUE))
  testthat::expect_true(grepl(".katex", css, fixed = TRUE))
})

test_that("no dependency declares a stylesheet", {
  # Since maidr 3.75.1 the published maidr.css is a placeholder with no rules
  # in it, kept only so that pre-existing <link> tags resolve. Declaring it
  # would cost a request and change nothing on the page.
  for (use_cdn in list(TRUE, FALSE)) {
    dep <- maidr:::maidr_html_dependencies(use_cdn = use_cdn)[[1]]
    testthat::expect_null(dep$stylesheet)
    testthat::expect_identical(dep$script, "maidr.js")
  }
})

test_that("the htmlwidgets manifest matches the dependency it mirrors", {
  # Read as text rather than parsed YAML: this package does not depend on a
  # YAML reader, and the three facts worth pinning are all line-shaped.
  manifest <- readLines(
    system.file("htmlwidgets/maidr.yaml", package = "maidr"),
    warn = FALSE
  )

  testthat::expect_true(
    any(trimws(manifest) == sprintf("version: %s", maidr:::MAIDR_VERSION))
  )
  testthat::expect_true(
    any(trimws(manifest) == sprintf(
      "src: htmlwidgets/lib/maidr-%s", maidr:::MAIDR_VERSION
    ))
  )
  testthat::expect_true(any(trimws(manifest) == "script: maidr.js"))
  testthat::expect_false(any(grepl("stylesheet", manifest, fixed = TRUE)))
})
