# Tests for the knitr integration in R/knitr_support.R

# ==============================================================================
# Setup and Teardown
# ==============================================================================

# maidr_on()/maidr_off() mutate global state (options, Base R patching, knitr
# hooks). Snapshot everything we touch so the rest of the suite is unaffected.
save_knitr_env <- function() {
  knitr_state <- maidr:::.maidr_knitr_state

  state <- list(
    options = options(
      "maidr.auto_show", "maidr.base_r", "maidr.ggplot2", "maidr.lattice"
    ),
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

# ==============================================================================
# lattice (trellis) charts
# ==============================================================================

# A trellis object a chunk returns reaches knit_print(), for which maidr_on()
# registers knit_print.trellis(). Each test knits a real document whose setup
# chunk calls maidr_on(), as a document does, for the output format it
# names. knitr puts its own options back when the knit ends, and
# save_knitr_env() puts back what maidr_on() changed.
#
# Where lattice draws the chart itself, the figure knitr records is checked
# against a control chunk that draws the same chart with plot.trellis(),
# which no print hook reaches: knitr records both on the same device with
# the same settings, so the same drawing is the same bytes.

lattice_control_chunk <- paste(
  "invisible(utils::getS3method('plot', 'trellis')(",
  "lattice::xyplot(mpg ~ wt, data = mtcars)))"
)

#' Knit a document made of a setup chunk and the chunks given
#'
#' @param chunks Named list of chunk code, named by chunk label.
#' @param dir Where knitr writes the figures it records.
#' @param to The pandoc output format the document is knitted for.
#' @param off Whether the setup chunk turns MAIDR off again after
#'   `maidr_on()`.
#' @return The knitted Markdown, as one string.
knit_lattice <- function(chunks, dir, to = "html", off = FALSE) {
  # knitr sets up its Markdown hooks only when every hook is still its
  # default, and the plot hook an earlier maidr_on() set is not: the
  # figures then came out as bare file names. The knit starts from the
  # defaults, as it does in a new session, and the document's own
  # maidr_on() sets the plot hook over knitr's Markdown one. A device's
  # recorded Base R calls would be read by that hook as the figure.
  hooks <- knitr::knit_hooks$get()
  knitr::knit_hooks$restore()
  on.exit(knitr::knit_hooks$set(hooks), add = TRUE)
  maidr:::clear_all_device_storage()

  document <- c(
    "```{r setup, include = FALSE}",
    sprintf("knitr::opts_knit$set(rmarkdown.pandoc.to = %s)", deparse(to)),
    sprintf("knitr::opts_chunk$set(fig.path = %s)", deparse(file.path(dir, "figure-"))),
    "maidr::maidr_on()",
    if (off) "maidr::maidr_off()",
    "```"
  )
  for (label in names(chunks)) {
    document <- c(document, "", sprintf("```{r %s, echo = FALSE}", label), chunks[[label]], "```")
  }
  paste(knitr::knit(text = document, quiet = TRUE, envir = new.env()), collapse = "\n")
}

#' The figures a knitted page includes as Markdown images, as file paths
knitted_figures <- function(page) {
  images <- regmatches(page, gregexpr("!\\[[^]]*\\]\\([^)]+\\)", page))[[1]]
  sub("^!\\[[^]]*\\]\\(([^)]+)\\)$", "\\1", images)
}

#' Expect the one frame of a page to hold the mtcars scatter, read back
#'
#' One point layer, holding the data frame's values in row order, whose
#' selector finds the 32 points drawn and nothing else.
expect_framed_scatter <- function(page) {
  frames <- xml2::xml_find_all(xml2::read_html(page, encoding = "UTF-8"), "//iframe")
  testthat::expect_length(frames, 1L)
  srcdoc <- xml2::xml_attr(frames[[1]], "srcdoc")
  svg <- xml2::read_xml(regmatches(
    srcdoc,
    regexpr("<svg[^>]*maidr-data=[\\s\\S]*?</svg>", srcdoc, perl = TRUE)
  ))
  schema <- jsonlite::fromJSON(xml2::xml_attr(svg, "maidr-data"), simplifyVector = FALSE)
  layers <- schema$subplots[[1]][[1]]$layers
  testthat::expect_length(layers, 1L)
  testthat::expect_identical(layers[[1]]$type, "point")
  values <- function(axis) {
    vapply(layers[[1]]$data, function(point) as.numeric(point[[axis]]), numeric(1))
  }
  testthat::expect_equal(values("x"), datasets::mtcars$wt)
  testthat::expect_equal(values("y"), datasets::mtcars$mpg)
  testthat::expect_identical(lattice_selector_counts(svg, layers[[1]]$selectors), 32L)
}

test_that("a trellis object a chunk returns is a MAIDR chart in HTML output", {
  testthat::skip_on_cran()
  skip_if_no_lattice()
  testthat::skip_if_not_installed("knitr")
  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  on.exit(knitr::knit_meta(clean = TRUE), add = TRUE)
  testthat::local_mocked_bindings(maidr_internet_available = function() TRUE, .package = "maidr")
  dir <- tempfile("maidr-knit-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  page <- knit_lattice(list(chart = "lattice::xyplot(mpg ~ wt, data = mtcars)"), dir)

  expect_framed_scatter(page)
  # In place of the figure knitr would have recorded, not beside it.
  testthat::expect_length(knitted_figures(page), 0L)
  testthat::expect_length(list.files(dir), 0L)
})

test_that("in any other output format a returned trellis object is lattice's figure", {
  testthat::skip_on_cran()
  skip_if_no_lattice()
  testthat::skip_if_not_installed("knitr")
  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  dir <- tempfile("maidr-knit-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  page <- knit_lattice(
    list(chart = "lattice::xyplot(mpg ~ wt, data = mtcars)", control = lattice_control_chunk),
    dir,
    to = "latex"
  )

  testthat::expect_false(grepl("<iframe", page, fixed = TRUE))
  figures <- knitted_figures(page)
  testthat::expect_identical(basename(figures), c("figure-chart-1.png", "figure-control-1.png"))
  testthat::expect_true(all(file.exists(figures)))
  testthat::expect_identical(unname(tools::md5sum(figures[1])), unname(tools::md5sum(figures[2])))
})

test_that("after maidr_off() a returned trellis object is lattice's figure in HTML output too", {
  testthat::skip_on_cran()
  skip_if_no_lattice()
  testthat::skip_if_not_installed("knitr")
  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  dir <- tempfile("maidr-knit-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  # registerS3method() cannot be undone, so the method has to honour
  # maidr_off() itself.
  page <- knit_lattice(
    list(chart = "lattice::xyplot(mpg ~ wt, data = mtcars)", control = lattice_control_chunk),
    dir,
    off = TRUE
  )

  testthat::expect_false(grepl("<iframe", page, fixed = TRUE))
  figures <- knitted_figures(page)
  testthat::expect_identical(basename(figures), c("figure-chart-1.png", "figure-control-1.png"))
  testthat::expect_identical(unname(tools::md5sum(figures[1])), unname(tools::md5sum(figures[2])))
})

test_that("a trellis object a chunk prints itself is lattice's figure", {
  testthat::skip_on_cran()
  skip_if_no_lattice()
  testthat::skip_if_not_installed("knitr")
  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  dir <- tempfile("maidr-knit-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  # knitr does not route an explicit print() through knit_print(), and the
  # print hook leaves a print while knitr runs to lattice, so the figure is
  # recorded as it would be without MAIDR -- and no viewer opens.
  opened <- 0L
  testthat::local_mocked_bindings(
    session_is_interactive = function() TRUE,
    display_html = function(html_doc) opened <<- opened + 1L,
    .package = "maidr"
  )
  page <- knit_lattice(
    list(
      printed = "print(lattice::xyplot(mpg ~ wt, data = mtcars))",
      control = lattice_control_chunk
    ),
    dir
  )

  testthat::expect_identical(opened, 0L)
  testthat::expect_false(grepl("<iframe", page, fixed = TRUE))
  figures <- knitted_figures(page)
  testthat::expect_identical(basename(figures), c("figure-printed-1.png", "figure-control-1.png"))
  testthat::expect_identical(unname(tools::md5sum(figures[1])), unname(tools::md5sum(figures[2])))
})

test_that("a trellis object the reading does not cover is an inline picture of it", {
  testthat::skip_on_cran()
  skip_if_no_lattice()
  testthat::skip_if_not_installed("knitr")
  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  dir <- tempfile("maidr-knit-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  page <- knit_lattice(list(chart = "lattice::cloud(mpg ~ wt * hp, data = mtcars)"), dir)

  testthat::expect_false(grepl("<iframe", page, fixed = TRUE))
  images <- regmatches(
    page,
    gregexpr('<img src="data:image/png;base64,[A-Za-z0-9+/=]+"', page)
  )[[1]]
  testthat::expect_length(images, 1L)

  # lattice's own drawing of the chart, on the device and at the size the
  # picture is made with.
  file <- tempfile(fileext = ".png")
  on.exit(unlink(file), add = TRUE)
  grDevices::png(file, width = 7 * 150, height = 5 * 150, res = 150)
  device <- grDevices::dev.cur()
  tryCatch(
    utils::getS3method("plot", "trellis")(lattice::cloud(mpg ~ wt * hp, data = mtcars)),
    finally = grDevices::dev.off(device)
  )
  drawn <- sprintf('<img src="data:image/png;base64,%s"', base64enc::base64encode(file))
  testthat::expect_identical(images, drawn)
})

test_that("R Markdown renders a lattice chunk as a MAIDR chart", {
  testthat::skip_on_cran()
  skip_if_no_lattice()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")

  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  testthat::local_mocked_bindings(maidr_internet_available = function() TRUE, .package = "maidr")

  dir <- tempfile("maidr-rmd-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  rmd <- file.path(dir, "lattice.Rmd")
  writeLines(c(
    "---",
    "title: lattice",
    "output: html_document",
    "---",
    "```{r, echo = FALSE}",
    "maidr::maidr_on()",
    "lattice::xyplot(mpg ~ wt, data = mtcars)",
    "```"
  ), rmd)

  out <- rmarkdown::render(rmd, quiet = TRUE, envir = new.env())
  page <- paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expect_framed_scatter(page)
  # And no picture of it besides: a figure is embedded as a PNG.
  testthat::expect_false(grepl('<img src="data:image/png', page, fixed = TRUE))
})

test_that("maidr_off() puts lattice's print function back, and maidr_on() sets MAIDR's again", {
  skip_if_no_lattice()
  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  loadNamespace("lattice")
  state <- maidr:::.maidr_lattice_state
  saved <- list(
    option = lattice::lattice.getOption("print.function"),
    previous = state$previous_print_function,
    registered = state$registered
  )
  on.exit(
    {
      lattice::lattice.options(print.function = saved$option)
      state$previous_print_function <- saved$previous
      state$registered <- saved$registered
    },
    add = TRUE
  )

  mine <- function(x, ...) utils::getS3method("plot", "trellis")(x, ...)
  maidr::maidr_off()
  lattice::lattice.options(print.function = mine)

  for (cycle in 1:2) {
    maidr::maidr_on()
    testthat::expect_identical(
      lattice::lattice.getOption("print.function"), maidr:::maidr_print_trellis
    )
    maidr::maidr_off()
    testthat::expect_identical(lattice::lattice.getOption("print.function"), mine)
  }
})
