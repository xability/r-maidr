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
    deps <- maidr:::maidr_html_dependencies(use_cdn = use_cdn)
    for (dep in deps) {
      testthat::expect_null(dep$stylesheet)
    }
    bundle <- Filter(function(dep) identical(dep$name, "maidr"), deps)
    testthat::expect_length(bundle, 1)
    testthat::expect_identical(bundle[[1]]$script, "maidr.js")
  }
})

test_that("the widget declares nothing on every page but its binding", {
  # A copy of the bundle on every widget's page is 1.7 MB that a widget whose
  # frame carries the bundle inline never reads, so maidr_widget() declares
  # it per widget, only when its frame falls back to it. An htmlwidgets yaml
  # would put it on every page again.
  testthat::expect_identical(
    system.file("htmlwidgets/maidr.yaml", package = "maidr"),
    ""
  )
  deps <- htmlwidgets:::getDependency("maidr", "maidr")
  names <- vapply(
    Filter(function(d) identical(d$package, "maidr"), deps),
    function(d) d$name,
    character(1)
  )
  testthat::expect_identical(names, "maidr-binding")
})

# ==============================================================================
# Dependencies the document tooling copies
# ==============================================================================

# Quarto copies every dependency of a document with
# htmltools::copyDependencyToDir() at its default `mustWork = TRUE`, which
# stops at one with no directory on disk. The DotPad and locale settings were
# such dependencies, so no .qmd showing a maidr_htmlwidget() chart rendered:
# "Dependency maidr-locale-config 1.0.0 is not disk-based". R Markdown and
# save_html() copy with `mustWork = FALSE` and so never noticed. Each setting
# below adds or drops one of those dependencies.
page_settings <- list(
  "nothing configured" = list(),
  "a DotPad SDK" = list(
    maidr.dotpad_sdk_url = "/vendor/DotPadSDK-3.0.3.js",
    maidr.dotpad_asset_base_url = "/vendor/lib/"
  ),
  "a locale pack location" = list(maidr.locale_base_url = "https://example.org/maidr/"),
  "no locale packs" = list(maidr.locale_base_url = ""),
  "both, named" = list(
    maidr.dotpad_sdk_url = "/vendor/DotPadSDK-3.0.3.js",
    maidr.locale_base_url = "https://example.org/maidr/"
  )
)

# Only the settings asked for, whatever the session running the tests has.
local_page_settings <- function(settings, env = parent.frame()) {
  withr::local_envvar(
    MAIDR_DOTPAD_SDK_URL = NA,
    MAIDR_DOTPAD_ASSET_BASE_URL = NA,
    MAIDR_LOCALE_BASE_URL = NA,
    .local_envir = env
  )
  withr::local_options(
    maidr.dotpad_sdk_url = NULL,
    maidr.dotpad_asset_base_url = NULL,
    maidr.locale_base_url = NULL,
    .local_envir = env
  )
  withr::local_options(settings, .local_envir = env)
}

head_only <- function(deps) {
  Filter(function(dep) !identical(dep$name, "maidr"), deps)
}

test_that("every dependency of a bundled document can be copied as Quarto copies it", {
  for (setting in names(page_settings)) {
    local({
      local_page_settings(page_settings[[setting]])
      deps <- maidr:::maidr_html_dependencies(use_cdn = FALSE)
      lib <- withr::local_tempdir()

      testthat::expect_no_error(
        copied <- lapply(deps, htmltools::copyDependencyToDir, outputDir = lib)
      )

      # The bundle is copied; the settings have no file, so nothing is
      # copied for them, and each still renders as its `head` alone.
      testthat::expect_identical(
        list.files(lib),
        sprintf("maidr-%s", maidr:::MAIDR_VERSION),
        info = setting
      )
      for (dep in head_only(copied)) {
        testthat::expect_identical(
          as.character(htmltools::renderDependencies(list(dep), "file")),
          dep$head,
          info = setting
        )
      }

      # In the order Quarto writes them: the declarations ahead of the bundle.
      rendered <- as.character(htmltools::renderDependencies(copied, "file"))
      bundle_at <- regexpr("maidr.js", rendered, fixed = TRUE)
      testthat::expect_true(bundle_at > 0, info = setting)
      for (dep in head_only(deps)) {
        declared_at <- regexpr(dep$head, rendered, fixed = TRUE)
        testthat::expect_true(declared_at > 0 && declared_at < bundle_at, info = setting)
      }
    })
  }
})

test_that("the settings render as their head alone wherever the bundle comes from", {
  # What show(), save_html() and the widgets write is unchanged by giving the
  # settings a directory: htmltools renders a dependency without files as its
  # `head`, from either kind of source.
  local_page_settings(page_settings[["both, named"]])
  for (use_cdn in list(FALSE, TRUE)) {
    settings <- head_only(maidr:::maidr_html_dependencies(use_cdn = use_cdn))
    testthat::expect_identical(
      vapply(settings, function(dep) dep$name, character(1)),
      c("maidr-dotpad-config", "maidr-locale-config")
    )
    for (dep in settings) {
      testthat::expect_null(dep$script)
      testthat::expect_null(dep$stylesheet)
      testthat::expect_null(dep$attachment)
      testthat::expect_false(dep$all_files)
      testthat::expect_identical(
        as.character(htmltools::renderDependencies(list(dep))),
        dep$head
      )
    }
  }
})

test_that("a Quarto document showing a maidr_htmlwidget() chart renders", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not_installed("plotly")
  quarto <- Sys.which("quarto")
  testthat::skip_if(!nzchar(quarto), "Quarto is not installed")

  # Quarto knits in an R session of its own, which has to load this maidr:
  # the source tree when the tests run from it, the installed package under
  # R CMD check.
  root <- normalizePath(testthat::test_path("..", ".."), mustWork = FALSE)
  from_source <- requireNamespace("pkgload", quietly = TRUE) &&
    file.exists(file.path(root, "DESCRIPTION")) &&
    file.exists(file.path(root, "R", "maidr.R"))
  loader <- if (from_source) {
    sprintf("pkgload::load_all(%s, quiet = TRUE)", deparse(root))
  } else {
    "library(maidr)"
  }

  local_page_settings(list())
  withr::local_envvar(QUARTO_R = R.home("bin"))
  dir <- withr::local_tempdir("maidr-qmd-")
  qmd <- file.path(dir, "chart.qmd")
  writeLines(c(
    "---",
    "title: chart",
    "format: html",
    "---",
    "```{r}",
    "#| echo: false",
    "#| message: false",
    sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
    loader,
    "options(maidr.dotpad_sdk_url = '/vendor/DotPadSDK-3.0.3.js')",
    "p <- plotly::plot_ly(x = c('a', 'b'), y = c(3, 1), type = 'bar')",
    "maidr::maidr_htmlwidget(p)",
    "```"
  ), qmd)

  out <- suppressWarnings(system2(
    quarto,
    c("render", shQuote(qmd), "--quiet"),
    stdout = TRUE,
    stderr = TRUE,
    timeout = 300
  ))
  status <- attr(out, "status")
  testthat::expect_identical(
    if (is.null(status)) 0L else status,
    0L,
    info = paste(out, collapse = "\n")
  )

  page <- file.path(dir, "chart.html")
  html <- if (file.exists(page)) {
    paste(readLines(page, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  bundle_at <- regexpr(
    sprintf('<script src="chart_files/libs/maidr-%s/maidr.js">', maidr:::MAIDR_VERSION),
    html,
    fixed = TRUE
  )
  dotpad_at <- regexpr("window.MAIDR_DOTPAD_SDK_URL = ", html, fixed = TRUE)
  locale_at <- regexpr("window.maidrLocaleBaseUrl = ", html, fixed = TRUE)
  testthat::expect_true(bundle_at > 0)
  testthat::expect_true(dotpad_at > 0 && dotpad_at < bundle_at)
  testthat::expect_true(locale_at > 0 && locale_at < bundle_at)

  libs <- list.files(file.path(dir, "chart_files", "libs"))
  testthat::expect_true(sprintf("maidr-%s", maidr:::MAIDR_VERSION) %in% libs)
  testthat::expect_false(any(grepl("-config-", libs, fixed = TRUE)))
})
