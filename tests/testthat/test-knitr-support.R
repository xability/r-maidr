# Tests for the knitr integration in R/knitr_support.R

# ==============================================================================
# Setup and Teardown
# ==============================================================================

# maidr_on()/maidr_off() mutate global state (options, Base R patching, knitr
# hooks). Snapshot everything we touch so the rest of the suite is unaffected.
save_knitr_env <- function() {
  knitr_state <- maidr:::.maidr_knitr_state

  state <- list(
    options = options("maidr.auto_show", "maidr.base_r", "maidr.ggplot2"),
    patching_active = maidr:::is_patching_active(),
    plot_hook = NULL,
    original_plot_hook = knitr_state$original_plot_hook,
    enabled = knitr_state$enabled
  )

  if (requireNamespace("knitr", quietly = TRUE)) {
    state$plot_hook <- knitr::knit_hooks$get("plot")
  }

  state
}

restore_knitr_env <- function(state) {
  # Go back through maidr_on()/maidr_off() rather than writing the flag
  # directly: they install and remove the Base R wrappers as well as setting
  # it, and a flag that disagrees with which wrappers are installed is worse
  # than either state on its own.
  if (isTRUE(state$patching_active)) {
    maidr::maidr_on()
  } else {
    maidr::maidr_off()
  }

  if (requireNamespace("knitr", quietly = TRUE) && !is.null(state$plot_hook)) {
    knitr::knit_hooks$set(plot = state$plot_hook)
  }

  knitr_state <- maidr:::.maidr_knitr_state
  knitr_state$original_plot_hook <- state$original_plot_hook
  knitr_state$enabled <- state$enabled
  # Last, so the saved values win over whatever maidr_on()/maidr_off() set.
  options(state$options)
  maidr:::clear_all_device_storage()

  invisible(NULL)
}

# ==============================================================================
# maidr_plot_hook Tests
# ==============================================================================

test_that("maidr_plot_hook clears device storage when interception is off", {
  testthat::skip_if_not_installed("knitr")

  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)

  maidr::maidr_on()
  maidr:::clear_all_device_storage()

  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    tryCatch(grDevices::dev.off(device_id), error = function(e) NULL),
    add = TRUE
  )

  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
  testthat::expect_true(maidr:::has_device_calls(device_id))

  # maidr_off() disables interception; the hook must behave like the original
  # hook AND drop what was already recorded, rather than leaving it behind.
  maidr::maidr_off()
  testthat::expect_false(maidr:::is_base_r_enabled())

  maidr:::maidr_plot_hook("figure-1.png", list())

  testthat::expect_false(maidr:::has_device_calls(device_id))
  testthat::expect_length(maidr:::get_device_calls(device_id), 0)
})

test_that("toggling maidr_off()/maidr_on() does not leak phantom layers", {
  testthat::skip_if_not_installed("knitr")

  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)

  maidr::maidr_on()
  maidr:::clear_all_device_storage()

  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    tryCatch(grDevices::dev.off(device_id), error = function(e) NULL),
    add = TRUE
  )

  # Chunk 1: recorded while interception is on.
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))

  # Chunk 2: rendered after maidr_off() - the stale barplot must not survive.
  maidr::maidr_off()
  maidr:::maidr_plot_hook("figure-1.png", list())

  # Chunk 3: interception back on, a brand new plot.
  maidr::maidr_on()
  hist(c(1, 2, 2, 3, 3, 3, 4, 4, 5))

  calls <- maidr:::get_device_calls(device_id)
  recorded <- vapply(calls, function(entry) entry$function_name, character(1))

  testthat::expect_false("barplot" %in% recorded)
  testthat::expect_true("hist" %in% recorded)
})

test_that("the test helpers leave global patching state as they found it", {
  testthat::skip_if_not_installed("knitr")

  # These tests call maidr_on()/maidr_off(), which install and remove the Base
  # R wrappers globally. Without this the first test above -- which ends with
  # interception off -- would leave it off for whatever runs next, making the
  # suite quietly order-dependent.
  for (start_on in c(TRUE, FALSE)) {
    if (start_on) maidr::maidr_on() else maidr::maidr_off()
    before <- maidr:::is_patching_active()

    env_state <- save_knitr_env()
    if (start_on) maidr::maidr_off() else maidr::maidr_on()
    restore_knitr_env(env_state)

    testthat::expect_identical(maidr:::is_patching_active(), before)
  }

  maidr::maidr_on()
})

# ==============================================================================
# Self-contained documents
# ==============================================================================

# A chart frame's document lives in a `srcdoc` attribute, where R Markdown's
# `self_contained` and Quarto's `embed-resources` cannot see its `<script src>`.
# Online, the knitr paths therefore give the document its own copy of the
# bundle for the frame to fall back on, which those options do embed.

test_that("the page bundle is the packaged bundle, in scripts no browser runs", {
  dep <- maidr:::maidr_page_bundle_dependency()

  testthat::expect_s3_class(dep, "html_dependency")
  testthat::expect_identical(dep$version, maidr:::MAIDR_VERSION)

  srcs <- vapply(dep$script, function(s) s$src, character(1))
  types <- vapply(dep$script, function(s) s$type, character(1))
  testthat::expect_identical(srcs, c("maidr.js", "maidr-math.css"))
  testthat::expect_identical(
    types,
    c(maidr:::MAIDR_PAGE_JS_TYPE, maidr:::MAIDR_PAGE_MATH_CSS_TYPE)
  )
  testthat::expect_false(any(types %in% c("text/javascript", "module")))

  dir <- system.file(dep$src$file, package = dep$package)
  testthat::expect_true(all(file.exists(file.path(dir, srcs))))
})

test_that("an online frame falls back to the page's copy only when asked to", {
  content <- '<svg maidr-data="{}"></svg>'
  cdn_js <- paste0(maidr:::maidr_cdn_url(), "/maidr.js")

  plain <- maidr:::create_standalone_html(content, use_cdn = TRUE)
  testthat::expect_true(grepl(sprintf('<script src="%s">', cdn_js), plain, fixed = TRUE))
  testthat::expect_false(grepl(maidr:::MAIDR_PAGE_JS_TYPE, plain, fixed = TRUE))

  loader <- maidr:::create_standalone_html(content, use_cdn = TRUE, page_fallback = TRUE)
  testthat::expect_false(grepl(sprintf('<script src="%s">', cdn_js), loader, fixed = TRUE))
  testthat::expect_true(grepl(sprintf('s.src = "%s";', cdn_js), loader, fixed = TRUE))
  testthat::expect_true(grepl("s.onerror = fromPage;", loader, fixed = TRUE))
  testthat::expect_true(grepl(maidr:::MAIDR_PAGE_JS_TYPE, loader, fixed = TRUE))
  testthat::expect_true(grepl(maidr:::MAIDR_PAGE_MATH_CSS_TYPE, loader, fixed = TRUE))

  # Offline, the bundle travels inline and there is nothing to fall back to.
  inline <- maidr:::create_standalone_html(content, use_cdn = FALSE, page_fallback = TRUE)
  testthat::expect_false(grepl("fromPage", inline, fixed = TRUE))
})

test_that("a knitted chart adds the page bundle online, and only online", {
  testthat::skip_if_not_installed("knitr")
  content <- '<svg maidr-data="{}"></svg>'
  page_bundles <- function() {
    Filter(
      function(d) inherits(d, "html_dependency") && identical(d$name, "maidr-page-bundle"),
      knitr::knit_meta(clean = TRUE)
    )
  }

  knitr::knit_meta(clean = TRUE)
  testthat::local_mocked_bindings(maidr_internet_available = function() TRUE, .package = "maidr")
  online <- maidr:::create_knitr_iframe(content)
  testthat::expect_length(page_bundles(), 1)
  testthat::expect_true(grepl("fromPage", online, fixed = TRUE))

  testthat::local_mocked_bindings(maidr_internet_available = function() FALSE, .package = "maidr")
  offline <- maidr:::create_knitr_iframe(content)
  testthat::expect_length(page_bundles(), 0)
  testthat::expect_false(grepl("fromPage", offline, fixed = TRUE))
})

test_that("a self-contained R Markdown document carries the bundle once", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")

  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  testthat::local_mocked_bindings(maidr_internet_available = function() TRUE, .package = "maidr")

  dir <- tempfile("maidr-rmd-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  rmd <- file.path(dir, "charts.Rmd")
  writeLines(c(
    "---",
    "title: charts",
    "output:",
    "  html_document:",
    "    self_contained: true",
    "---",
    "```{r, echo = FALSE}",
    "library(ggplot2)",
    "maidr::maidr_on()",
    "ggplot(mtcars, aes(factor(cyl))) + geom_bar()",
    "ggplot(mtcars, aes(factor(gear))) + geom_bar()",
    "```"
  ), rmd)

  out <- rmarkdown::render(rmd, quiet = TRUE, envir = new.env())
  html <- paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  testthat::expect_false(dir.exists(file.path(dir, "charts_files")))
  testthat::expect_identical(lengths(regmatches(html, gregexpr("<iframe", html, fixed = TRUE))), 2L)
  pattern <- sprintf('<script[^>]*type="%s"', maidr:::MAIDR_PAGE_JS_TYPE)
  testthat::expect_identical(lengths(regmatches(html, gregexpr(pattern, html))), 1L)

  # Embedded, not linked: the copy is in the file itself.
  bundle <- readLines(maidr:::maidr_local_assets()$js, n = 1L, warn = FALSE)
  testthat::expect_true(grepl(substr(bundle, 1L, 200L), html, fixed = TRUE))
})
