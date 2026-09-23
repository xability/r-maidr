# Tests for R/cdn_version.R: which maidr.js a CDN document loads.
#
# Nothing here reaches the network. setup-cdn.R makes every lookup fail for
# the whole suite, and each test below replaces the one function that makes
# the request with the answers it needs, counting what was asked.

jsdelivr_url <- maidr:::MAIDR_CDN_RESOLVERS[[1]]$url
npm_url <- maidr:::MAIDR_CDN_RESOLVERS[[2]]$url

cdn_base <- function(version) {
  sprintf("https://cdn.jsdelivr.net/npm/maidr@%s/dist", version)
}

# Run `code` with the CDN settings given and nothing else: the options and
# environment variables are restored afterwards, and the session's lookup
# cache and warnings are cleared before and after.
with_cdn_settings <- function(code, version = NULL, env_version = NULL,
                              timeout = NULL, env_timeout = NULL) {
  previous <- options(maidr.cdn_version = version, maidr.cdn_timeout = timeout)
  on.exit(options(previous), add = TRUE)

  names <- c("MAIDR_CDN_VERSION", "MAIDR_CDN_TIMEOUT")
  old_env <- Sys.getenv(names, unset = NA)
  restore_env <- function() {
    for (name in names(old_env)) {
      if (is.na(old_env[[name]])) {
        Sys.unsetenv(name)
      } else {
        do.call(Sys.setenv, as.list(old_env[name]))
      }
    }
  }
  on.exit(restore_env(), add = TRUE)
  Sys.unsetenv(names)
  vars <- c(MAIDR_CDN_VERSION = env_version, MAIDR_CDN_TIMEOUT = env_timeout)
  if (length(vars) > 0) do.call(Sys.setenv, as.list(vars))

  maidr:::maidr_reset_cdn_cache()
  on.exit(maidr:::maidr_reset_cdn_cache(), add = TRUE)

  force(code)
}

# Replace the resolver request with `respond(url)`, recording every URL asked
# and the time it was given. Returns the record.
mock_resolvers <- function(respond, env = parent.frame()) {
  record <- new.env(parent = emptyenv())
  record$urls <- character(0)
  record$timeouts <- numeric(0)
  testthat::local_mocked_bindings(
    maidr_cdn_resolver_request = function(url, timeout) {
      record$urls <- c(record$urls, url)
      record$timeouts <- c(record$timeouts, timeout)
      respond(url)
    },
    .package = "maidr",
    .env = env
  )
  record
}

jsdelivr_answers <- function(version) {
  function(url) {
    if (identical(url, jsdelivr_url)) {
      sprintf('{"type":"npm","name":"maidr","version":"%s","links":{}}', version)
    } else {
      sprintf('{"latest":"%s"}', version)
    }
  }
}

only_npm_answers <- function(version) {
  function(url) {
    if (identical(url, jsdelivr_url)) {
      stop("HTTP 503 from jsDelivr", call. = FALSE)
    }
    sprintf('{"latest":"%s","next":"99.0.0-beta.1"}', version)
  }
}

nobody_answers <- function(url) {
  stop("Could not resolve host", call. = FALSE)
}

svg_fixture_cdn <- function() {
  c(
    '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">',
    '<rect x="10" y="10" width="80" height="80"/>',
    "</svg>"
  )
}

# ==============================================================================
# The latest version, looked up
# ==============================================================================

test_that("the CDN URL names the version jsDelivr resolves latest to", {
  with_cdn_settings({
    record <- mock_resolvers(jsdelivr_answers("9.8.7"))

    testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.7")
    testthat::expect_identical(maidr:::maidr_cdn_url(), cdn_base("9.8.7"))
    testthat::expect_identical(record$urls, jsdelivr_url)
  })
})

test_that("every CDN path emits the resolved version, with no integrity hash", {
  with_cdn_settings({
    mock_resolvers(jsdelivr_answers("9.8.7"))
    script <- sprintf('<script src="%s/maidr.js"></script>', cdn_base("9.8.7"))

    html <- maidr:::create_standalone_html(svg_fixture_cdn(), use_cdn = TRUE)
    testthat::expect_true(grepl(script, html, fixed = TRUE))
    # A hash of the bundled bytes would block any other version from loading.
    testthat::expect_false(grepl("integrity", html, fixed = TRUE))

    deps <- maidr:::maidr_html_dependencies(use_cdn = TRUE)
    maidr_dep <- deps[[length(deps)]]
    testthat::expect_identical(maidr_dep$src$href, cdn_base("9.8.7"))
    rendered <- as.character(htmltools::renderDependencies(deps))
    testthat::expect_true(
      grepl(paste0(cdn_base("9.8.7"), "/maidr.js"), rendered, fixed = TRUE)
    )
    testthat::expect_false(grepl("integrity", rendered, fixed = TRUE))

    # The iframe the widget, knitr and Shiny paths embed carries it escaped.
    iframe <- maidr:::create_maidr_iframe(
      svg_fixture_cdn(),
      use_cdn = TRUE,
      plot_id = "cdn"
    )
    testthat::expect_true(
      grepl(paste0(cdn_base("9.8.7"), "/maidr.js"), iframe, fixed = TRUE)
    )
  })
})

test_that("save_html(use_cdn = TRUE) writes the resolved version", {
  p <- create_test_ggplot_bar()
  with_cdn_settings({
    mock_resolvers(jsdelivr_answers("9.8.7"))
    file <- tempfile(fileext = ".html")
    on.exit(unlink(file), add = TRUE)

    save_html(p, file, use_cdn = TRUE)

    html <- paste(readLines(file, warn = FALSE), collapse = "\n")
    testthat::expect_true(
      grepl(paste0(cdn_base("9.8.7"), "/maidr.js"), html, fixed = TRUE)
    )
    testthat::expect_false(grepl("maidr@latest", html, fixed = TRUE))
  })
})

test_that("the npm registry answers when jsDelivr fails", {
  with_cdn_settings({
    record <- mock_resolvers(only_npm_answers("9.8.6"))

    testthat::expect_identical(maidr:::maidr_cdn_url(), cdn_base("9.8.6"))
    testthat::expect_identical(record$urls, c(jsdelivr_url, npm_url))
  })
})

test_that("an answer that is not a version is passed over for the next one", {
  with_cdn_settings({
    record <- mock_resolvers(function(url) {
      if (identical(url, jsdelivr_url)) {
        '{"version":"4.9.0\\n<script>"}'
      } else {
        '{"latest":"9.8.5"}'
      }
    })

    testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.5")
    testthat::expect_identical(record$urls, c(jsdelivr_url, npm_url))
  })
})

test_that("answers that are not JSON, or lack the field, count as failures", {
  with_cdn_settings({
    record <- mock_resolvers(function(url) {
      if (identical(url, jsdelivr_url)) "<html>Bad gateway</html>" else "[]"
    })

    testthat::expect_no_warning(
      testthat::expect_identical(maidr:::maidr_cdn_version(), maidr:::MAIDR_VERSION)
    )
    testthat::expect_identical(record$urls, c(jsdelivr_url, npm_url))
  })
})

test_that("when neither resolver answers, the URL names the bundled version without an error", {
  with_cdn_settings({
    record <- mock_resolvers(nobody_answers)

    testthat::expect_no_warning(testthat::expect_no_error(
      url <- maidr:::maidr_cdn_url()
    ))
    # Not the mutable @latest tag, which jsDelivr caches for up to a week.
    testthat::expect_identical(url, cdn_base(maidr:::MAIDR_VERSION))
    testthat::expect_identical(record$urls, c(jsdelivr_url, npm_url))

    html <- maidr:::create_standalone_html(svg_fixture_cdn(), use_cdn = TRUE)
    testthat::expect_true(grepl(
      paste0(cdn_base(maidr:::MAIDR_VERSION), "/maidr.js"),
      html,
      fixed = TRUE
    ))
    testthat::expect_false(grepl("maidr@latest", html, fixed = TRUE))
  })
})

# ==============================================================================
# An answer older than the bundled version
# ==============================================================================

test_that("a resolver answer older than the bundled version gives the bundled one", {
  bundled <- maidr:::MAIDR_VERSION
  parts <- as.integer(strsplit(bundled, ".", fixed = TRUE)[[1]])
  older <- if (parts[[3]] > 0L) {
    sprintf("%d.%d.%d", parts[[1]], parts[[2]], parts[[3]] - 1L)
  } else {
    sprintf("%d.%d.0", parts[[1]] - 1L, 99L)
  }

  for (answer in c(older, "0.0.1", paste0(bundled, "-rc.1"))) {
    with_cdn_settings({
      record <- mock_resolvers(jsdelivr_answers(answer))
      testthat::expect_identical(maidr:::maidr_cdn_url(), cdn_base(bundled))
      testthat::expect_length(record$urls, 1)
    })
  }
})

test_that("a resolver answer as new as the bundled version, or newer, is used as-is", {
  bundled <- maidr:::MAIDR_VERSION
  parts <- as.integer(strsplit(bundled, ".", fixed = TRUE)[[1]])
  newer <- c(
    bundled,
    sprintf("%d.%d.%d", parts[[1]], parts[[2]], parts[[3]] + 1L),
    sprintf("%d.%d.0", parts[[1]], parts[[2]] + 1L),
    sprintf("%d.0.0", parts[[1]] + 1L),
    sprintf("%d.0.0-beta.1", parts[[1]] + 1L),
    paste0(bundled, "+build.7")
  )

  for (answer in newer) {
    with_cdn_settings({
      mock_resolvers(jsdelivr_answers(answer))
      testthat::expect_identical(maidr:::maidr_cdn_url(), cdn_base(answer))
    })
  }
})

test_that("versions are ordered by semantic version precedence", {
  older <- function(a, b) maidr:::maidr_is_older_than_bundled(a, bundled = b)

  # MAJOR.MINOR.PATCH numerically, not as text.
  testthat::expect_true(older("4.9.0", "4.10.0"))
  testthat::expect_false(older("4.10.0", "4.9.0"))
  testthat::expect_true(older("4.9.9", "5.0.0"))
  testthat::expect_false(older("4.9.0", "4.9.0"))

  # A pre-release sorts below its release, and above the one before.
  testthat::expect_true(older("4.9.0-rc.1", "4.9.0"))
  testthat::expect_false(older("4.9.0", "4.9.0-rc.1"))
  testthat::expect_false(older("4.9.0-rc.1", "4.8.9"))

  # Two pre-releases, identifier by identifier.
  testthat::expect_true(older("4.9.0-rc.1", "4.9.0-rc.2"))
  testthat::expect_true(older("4.9.0-rc.2", "4.9.0-rc.10"))
  testthat::expect_true(older("4.9.0-1", "4.9.0-alpha"))
  testthat::expect_true(older("4.9.0-alpha", "4.9.0-beta"))
  testthat::expect_true(older("4.9.0-Beta", "4.9.0-alpha"))
  testthat::expect_true(older("4.9.0-alpha", "4.9.0-alpha.1"))
  testthat::expect_false(older("4.9.0-alpha.1", "4.9.0-alpha"))
  testthat::expect_false(older("4.9.0-rc.1", "4.9.0-rc.1"))

  # Build metadata carries no precedence.
  testthat::expect_false(older("4.9.0+build.1", "4.9.0"))
  testthat::expect_false(older("4.9.0", "4.9.0+build.1"))
})

# ==============================================================================
# Once per session
# ==============================================================================

test_that("the lookup runs once per session, however many documents render", {
  with_cdn_settings({
    record <- mock_resolvers(jsdelivr_answers("9.8.7"))

    for (i in 1:3) {
      maidr:::create_standalone_html(svg_fixture_cdn(), use_cdn = TRUE)
      maidr:::maidr_html_dependencies(use_cdn = TRUE)
    }

    testthat::expect_identical(record$urls, jsdelivr_url)
    testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.7")
    testthat::expect_length(record$urls, 1)
  })
})

test_that("a failed lookup is cached too, and not retried on every render", {
  with_cdn_settings({
    record <- mock_resolvers(nobody_answers)

    testthat::expect_identical(maidr:::maidr_cdn_version(), maidr:::MAIDR_VERSION)
    testthat::expect_identical(maidr:::maidr_cdn_version(), maidr:::MAIDR_VERSION)
    maidr:::create_standalone_html(svg_fixture_cdn(), use_cdn = TRUE)

    # Two endpoints asked once each, then never again.
    testthat::expect_identical(record$urls, c(jsdelivr_url, npm_url))
  })
})

test_that("resetting the cache makes the next document look again", {
  with_cdn_settings({
    answer <- "9.8.7"
    record <- mock_resolvers(function(url) {
      sprintf('{"version":"%s"}', answer)
    })

    testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.7")
    answer <- "9.9.0"
    testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.7")

    maidr:::maidr_reset_cdn_cache()
    testthat::expect_identical(maidr:::maidr_cdn_version(), "9.9.0")
    testthat::expect_length(record$urls, 2)
  })
})

# ==============================================================================
# Pinning a version
# ==============================================================================

test_that("the option pins a version, and no lookup is made", {
  with_cdn_settings(version = "4.8.1", {
    record <- mock_resolvers(jsdelivr_answers("9.8.7"))

    testthat::expect_identical(maidr:::maidr_cdn_url(), cdn_base("4.8.1"))
    testthat::expect_length(record$urls, 0)
  })
})

test_that("a v-prefixed or padded version is accepted", {
  with_cdn_settings(version = " v4.8.1 ", {
    mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::expect_identical(maidr:::maidr_cdn_version(), "4.8.1")
  })
  with_cdn_settings(version = "5.0.0-beta.2+build.7", {
    mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::expect_identical(maidr:::maidr_cdn_version(), "5.0.0-beta.2+build.7")
  })
})

test_that("the environment variable pins a version when the option is unset", {
  with_cdn_settings(env_version = "4.7.0", {
    record <- mock_resolvers(jsdelivr_answers("9.8.7"))

    testthat::expect_identical(maidr:::maidr_cdn_url(), cdn_base("4.7.0"))
    testthat::expect_length(record$urls, 0)
  })
})

test_that("the option wins over the environment variable", {
  with_cdn_settings(version = "4.8.1", env_version = "4.7.0", {
    mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::expect_identical(maidr:::maidr_cdn_version(), "4.8.1")
  })
})

test_that("a blank option falls through to the environment variable", {
  with_cdn_settings(version = "", env_version = "4.7.0", {
    mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::expect_identical(maidr:::maidr_cdn_version(), "4.7.0")
  })
})

test_that("\"bundled\" names the bundled version without a lookup", {
  for (setting in c("bundled", "Bundled")) {
    with_cdn_settings(version = setting, {
      record <- mock_resolvers(jsdelivr_answers("9.8.7"))
      testthat::expect_identical(
        maidr:::maidr_cdn_url(),
        cdn_base(maidr:::MAIDR_VERSION)
      )
      testthat::expect_length(record$urls, 0)
    })
  }
  with_cdn_settings(env_version = "bundled", {
    record <- mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::expect_identical(maidr:::maidr_cdn_version(), maidr:::MAIDR_VERSION)
    testthat::expect_length(record$urls, 0)
  })
})

test_that("\"latest\" names the @latest tag without a lookup", {
  for (setting in c("latest", "LATEST")) {
    with_cdn_settings(version = setting, {
      record <- mock_resolvers(jsdelivr_answers("9.8.7"))
      testthat::expect_identical(maidr:::maidr_cdn_url(), cdn_base("latest"))
      testthat::expect_length(record$urls, 0)
    })
  }
  with_cdn_settings(env_version = "latest", {
    record <- mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::expect_identical(maidr:::maidr_cdn_version(), "latest")
    testthat::expect_length(record$urls, 0)
  })
})

test_that("an invalid option warns once and the latest version is looked up", {
  with_cdn_settings(version = "4.9", {
    record <- mock_resolvers(jsdelivr_answers("9.8.7"))

    testthat::expect_warning(
      version <- maidr:::maidr_cdn_version(),
      "maidr.cdn_version"
    )
    testthat::expect_identical(version, "9.8.7")
    testthat::expect_length(record$urls, 1)

    # Read again on every render, but said once.
    testthat::expect_no_warning(maidr:::maidr_cdn_version())
    testthat::expect_no_warning(
      maidr:::create_standalone_html(svg_fixture_cdn(), use_cdn = TRUE)
    )
  })
})

test_that("an invalid option is ignored rather than falling back to the variable", {
  with_cdn_settings(version = "not a version", env_version = "4.7.0", {
    mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::expect_warning(
      testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.7"),
      "is ignored"
    )
  })
})

test_that("an invalid environment variable warns and is ignored", {
  with_cdn_settings(env_version = "4.9", {
    mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::expect_warning(
      testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.7"),
      "MAIDR_CDN_VERSION"
    )
  })
  with_cdn_settings(env_version = "../../evil", {
    mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::expect_warning(
      testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.7"),
      "MAIDR_CDN_VERSION"
    )
  })
})

test_that("an option that is not a string warns and is ignored", {
  for (setting in list(4.9, TRUE, c("4.9.0", "4.8.0"), NA_character_)) {
    with_cdn_settings(version = setting, {
      mock_resolvers(jsdelivr_answers("9.8.7"))
      testthat::expect_warning(
        testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.7"),
        "maidr.cdn_version"
      )
    })
  }
})

# ==============================================================================
# Version validation
# ==============================================================================

test_that("only a semantic version passes as one", {
  valid <- c("4.9.0", "0.0.1", "10.20.30", "5.0.0-beta.2", "5.0.0-rc.1+build.5")
  invalid <- c(
    "4.9", "4", "04.9.0", "4.9.0-", "4.9.0\n", " 4.9.0", "latest",
    "4.9.0/../../x", "4.9.0?x=1", paste0("4.9.0-", strrep("a", 200)), ""
  )
  for (version in valid) {
    testthat::expect_true(maidr:::maidr_is_semver(version), label = version)
  }
  for (version in invalid) {
    testthat::expect_false(maidr:::maidr_is_semver(version), label = version)
  }
  testthat::expect_false(maidr:::maidr_is_semver(NA_character_))
  testthat::expect_false(maidr:::maidr_is_semver(c("4.9.0", "4.9.1")))
  testthat::expect_false(maidr:::maidr_is_semver(490))
})

# ==============================================================================
# The time budget
# ==============================================================================

test_that("the lookup gets three seconds by default, shared by both endpoints", {
  with_cdn_settings({
    testthat::expect_identical(maidr:::maidr_cdn_timeout(), 3)

    record <- mock_resolvers(function(url) {
      if (identical(url, jsdelivr_url)) {
        Sys.sleep(0.2)
        stop("timed out", call. = FALSE)
      }
      '{"latest":"9.8.6"}'
    })

    testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.6")
    testthat::expect_lte(record$timeouts[[1]], 3)
    # The registry is given what jsDelivr left, not a fresh budget.
    testthat::expect_lt(record$timeouts[[2]], record$timeouts[[1]] - 0.1)
  })
})

test_that("a spent budget leaves the second endpoint unasked", {
  with_cdn_settings(timeout = 0.1, {
    record <- mock_resolvers(function(url) {
      Sys.sleep(0.2)
      stop("timed out", call. = FALSE)
    })

    testthat::expect_identical(maidr:::maidr_cdn_version(), maidr:::MAIDR_VERSION)
    testthat::expect_identical(record$urls, jsdelivr_url)
  })
})

test_that("the budget comes from the option, then the environment variable", {
  with_cdn_settings(env_timeout = "5", {
    testthat::expect_identical(maidr:::maidr_cdn_timeout(), 5)
  })
  with_cdn_settings(timeout = 1.5, env_timeout = "5", {
    testthat::expect_identical(maidr:::maidr_cdn_timeout(), 1.5)
  })
  with_cdn_settings(timeout = "2", {
    testthat::expect_identical(maidr:::maidr_cdn_timeout(), 2)
  })
})

test_that("a budget outside 0.1 to 30 seconds is clamped, with a warning", {
  with_cdn_settings(timeout = 0.01, {
    testthat::expect_warning(
      testthat::expect_identical(maidr:::maidr_cdn_timeout(), 0.1),
      "0.1"
    )
    # Once per session.
    testthat::expect_no_warning(maidr:::maidr_cdn_timeout())
  })
  with_cdn_settings(env_timeout = "3000", {
    testthat::expect_warning(
      testthat::expect_identical(maidr:::maidr_cdn_timeout(), 30),
      "MAIDR_CDN_TIMEOUT"
    )
  })
  with_cdn_settings(timeout = 0.1, {
    testthat::expect_no_warning(
      testthat::expect_identical(maidr:::maidr_cdn_timeout(), 0.1)
    )
  })
  with_cdn_settings(timeout = 30, {
    testthat::expect_no_warning(
      testthat::expect_identical(maidr:::maidr_cdn_timeout(), 30)
    )
  })
})

test_that("a budget that is not a positive number warns and the default applies", {
  for (setting in list(0, -1, "abc", NA, Inf, NaN, c(1, 2))) {
    with_cdn_settings(timeout = setting, {
      testthat::expect_warning(
        testthat::expect_identical(maidr:::maidr_cdn_timeout(), 3),
        "maidr.cdn_timeout"
      )
    })
  }
  with_cdn_settings(env_timeout = "soon", {
    testthat::expect_warning(
      testthat::expect_identical(maidr:::maidr_cdn_timeout(), 3),
      "MAIDR_CDN_TIMEOUT"
    )
  })
})

test_that("the configured budget reaches the request", {
  with_cdn_settings(timeout = 1, {
    record <- mock_resolvers(jsdelivr_answers("9.8.7"))
    maidr:::maidr_cdn_version()
    testthat::expect_lte(record$timeouts[[1]], 1)
    testthat::expect_gt(record$timeouts[[1]], 0.5)
  })
})

# ==============================================================================
# The request itself
# ==============================================================================

test_that("the request returns the body of a 200 and fails on anything else", {
  with_cdn_settings({
    testthat::local_mocked_bindings(
      maidr_cdn_resolver_request = cdn_resolver_request_unmocked,
      .package = "maidr"
    )
    status <- 200L
    testthat::local_mocked_bindings(
      curl_fetch_memory = function(url, handle) {
        list(status_code = status, content = charToRaw('{"version":"9.8.7"}'))
      },
      .package = "curl"
    )

    testthat::expect_identical(
      maidr:::maidr_cdn_resolver_request(jsdelivr_url, 1),
      '{"version":"9.8.7"}'
    )
    testthat::expect_identical(maidr:::maidr_cdn_version(), "9.8.7")

    status <- 404L
    testthat::expect_error(
      maidr:::maidr_cdn_resolver_request(jsdelivr_url, 1),
      "HTTP 404"
    )
  })
})

# ==============================================================================
# Bundled documents make no request
# ==============================================================================

test_that("use_cdn = FALSE never looks the version up", {
  p <- create_test_ggplot_bar()
  with_cdn_settings({
    record <- mock_resolvers(function(url) {
      stop("a bundled document asked the network", call. = FALSE)
    })

    maidr:::create_standalone_html(svg_fixture_cdn(), use_cdn = FALSE)
    maidr:::maidr_html_dependencies(use_cdn = FALSE)
    maidr:::maidr_html_dependencies(use_cdn = NULL)
    maidr:::create_html_document(svg_fixture_cdn(), use_cdn = FALSE)
    maidr:::create_maidr_iframe(svg_fixture_cdn(), use_cdn = FALSE, plot_id = "b")

    dir <- tempfile()
    dir.create(dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    save_html(p, file.path(dir, "plot.html"), use_cdn = FALSE)

    testthat::expect_length(record$urls, 0)
    testthat::expect_null(maidr:::.maidr_cdn_state$attempted)
    # The bundled copy is still the bundled version.
    testthat::expect_true(dir.exists(
      file.path(dir, "lib", paste0("maidr-", maidr:::MAIDR_VERSION))
    ))
  })
})

test_that("an offline machine left to auto-detect inlines the bundle and never looks up", {
  with_cdn_settings({
    record <- mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::local_mocked_bindings(
      maidr_internet_available = function() FALSE,
      .package = "maidr"
    )

    html <- maidr:::create_standalone_html(svg_fixture_cdn(), use_cdn = NULL)

    testthat::expect_false(grepl("cdn.jsdelivr.net/npm/maidr", html, fixed = TRUE))
    testthat::expect_length(record$urls, 0)
  })
})

test_that("an online machine left to auto-detect loads the resolved version", {
  with_cdn_settings({
    mock_resolvers(jsdelivr_answers("9.8.7"))
    testthat::local_mocked_bindings(
      maidr_internet_available = function() TRUE,
      .package = "maidr"
    )

    html <- maidr:::create_standalone_html(svg_fixture_cdn(), use_cdn = NULL)

    testthat::expect_true(
      grepl(paste0(cdn_base("9.8.7"), "/maidr.js"), html, fixed = TRUE)
    )
  })
})
