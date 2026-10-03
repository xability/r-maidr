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
    hooks = NULL,
    opts_hooks = NULL,
    enabled = knitr_state$enabled
  )

  if (requireNamespace("knitr", quietly = TRUE)) {
    state$hooks <- knitr::knit_hooks$get()
    state$opts_hooks <- knitr::opts_hooks$get()
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

  if (requireNamespace("knitr", quietly = TRUE) && !is.null(state$hooks)) {
    knitr::knit_hooks$restore(state$hooks)
    knitr::opts_hooks$restore(state$opts_hooks)
  }

  knitr_state <- maidr:::.maidr_knitr_state
  knitr_state$enabled <- state$enabled
  # Last, so the saved values win over whatever maidr_on()/maidr_off() set.
  options(state$options)
  maidr:::clear_all_device_storage()
  figures <- maidr:::.maidr_knit_figures
  figures$objects <- list()
  maidr:::forget_replayed_tokens()

  invisible(NULL)
}

# ==============================================================================
# maidr_plot_hook Tests
# ==============================================================================

test_that("maidr_plot_hook leaves a figure no chart marked to the hook it replaced", {
  testthat::skip_if_not_installed("knitr")

  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)

  maidr::maidr_on()
  maidr:::clear_all_device_storage()

  # The session's own device, holding a chart drawn before the render and
  # never shown. It is current when the hook runs for a chunk that drew
  # only grid graphics: knitr has closed the chunk's devices by then.
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    tryCatch(grDevices::dev.off(device_id), error = function(e) NULL),
    add = TRUE
  )
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
  testthat::expect_null(maidr:::get_device_calls(device_id)[[1]]$uid)

  original <- function(x, options) paste("original hook:", x)
  testthat::expect_identical(
    maidr:::maidr_plot_hook("figure-1.png", list(), original),
    "original hook: figure-1.png"
  )
  # Left for the session, whose show() is still to come.
  testthat::expect_true(maidr:::has_device_calls(device_id))
})

test_that("maidr_plot_hook shows a figure only for the one chart its tokens name", {
  testthat::skip_if_not_installed("knitr")

  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  maidr::maidr_on()
  maidr:::clear_all_device_storage()
  figures <- maidr:::.maidr_knit_figures
  figures$objects <- list(
    o1 = list(content = "<svg/>", device = 2L),
    o2 = list(content = NULL, device = 2L)
  )
  maidr:::log_plot_call_to_device("barplot", NULL, list(1:3), 2L)
  session <- maidr:::.maidr_base_r_session
  storage <- session$devices[["2"]]
  storage$calls[[1]]$uid <- "b1"
  session$devices[["2"]] <- storage

  resolve <- maidr:::resolve_figure_chart
  testthat::expect_identical(resolve("o1")$content, "<svg/>")
  testthat::expect_identical(resolve("b1")$calls, storage$calls)
  testthat::expect_identical(resolve("b1")$device, 2L)
  # A chart maidr could not read, two charts on a page, a chart drawn over,
  # one spanning pages, a token no chart has: none.
  testthat::expect_null(resolve("o2"))
  testthat::expect_null(resolve(c("o1", "b1")))
  testthat::expect_null(resolve("xo1"))
  testthat::expect_null(resolve(NA_character_))
  testthat::expect_null(resolve(c("b1", "b2")))
  testthat::expect_null(resolve(character()))
})

test_that("a figure takes the tokens of the page replayed last, and none spanning pages", {
  figures <- maidr:::.maidr_knit_figures
  on.exit(maidr:::forget_replayed_tokens(), add = TRUE)

  figures$seen <- c("b1", "b2", "b1", "o3")
  figures$seen_page <- c(4L, 4L, 4L, 5L)
  testthat::expect_identical(maidr:::take_replayed_tokens(), "o3")
  testthat::expect_identical(maidr:::take_replayed_tokens(), character())

  figures$seen <- c("b1", "b2", "b2")
  figures$seen_page <- c(4L, 4L, 4L)
  testthat::expect_identical(maidr:::take_replayed_tokens(), c("b1", "b2"))

  figures$seen <- c("b1", "b2")
  figures$seen_page <- c(NA, 4L)
  testthat::expect_identical(maidr:::take_replayed_tokens(), NA_character_)
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

test_that("a self-contained R Markdown document embeds maidr.js once for its inline charts", {
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
  testthat::expect_false(grepl("<iframe", html, fixed = TRUE))
  page <- xml2::read_html(out)
  testthat::expect_length(xml2::xml_find_all(page, "//svg[@data-maidr-knitr]"), 2L)
  # The page's own copy, embedded once; the frames' fallback copy is gone.
  testthat::expect_identical(
    lengths(regmatches(html, gregexpr("window.maidrLive={", html, fixed = TRUE))),
    1L
  )
  testthat::expect_false(grepl(maidr:::MAIDR_PAGE_JS_TYPE, html, fixed = TRUE))
  bundle <- readLines(maidr:::maidr_local_assets()$js, n = 1L, warn = FALSE)
  testthat::expect_true(grepl(substr(bundle, 1L, 200L), html, fixed = TRUE))
})

# ==============================================================================
# lattice (trellis) charts
# ==============================================================================

# A trellis object a chunk returns reaches knit_print(), for which maidr
# registers knit_print.trellis() when it loads. Each test knits a real
# document whose setup chunk calls maidr_on(), as a document may, for the
# output format it names. knitr puts its own options back when the knit
# ends, and save_knitr_env() puts back what maidr_on() changed.
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

#' Expect the one inline chart of a page to be the mtcars scatter, read back
#'
#' One point layer, holding the data frame's values in row order, whose
#' selector finds the 32 points drawn and nothing else -- in the chart's own
#' svg, whose ids carry the chart's prefix.
expect_inline_scatter <- function(page) {
  doc <- xml2::read_html(page, encoding = "UTF-8")
  testthat::expect_length(xml2::xml_find_all(doc, "//iframe"), 0L)
  charts <- xml2::xml_find_all(doc, "//svg[@data-maidr-knitr]")
  testthat::expect_length(charts, 1L)
  svg <- xml2::read_xml(as.character(charts[[1]]))
  schema <- jsonlite::fromJSON(xml2::xml_attr(svg, "data-maidr-knitr"), simplifyVector = FALSE)
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

  expect_inline_scatter(page)
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

test_that("a trellis object a chunk prints itself is a MAIDR chart in place of its figure", {
  testthat::skip_on_cran()
  skip_if_no_lattice()
  testthat::skip_if_not_installed("knitr")
  env_state <- save_knitr_env()
  on.exit(restore_knitr_env(env_state), add = TRUE)
  dir <- tempfile("maidr-knit-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  # knitr does not route an explicit print() through knit_print(): lattice
  # draws the chart on knitr's device, where knitr records it as a figure,
  # and the plot hook shows the chart in its place -- and no viewer opens.
  # The control chunk's figure is an svg, as every figure of an HTML
  # document maidr is knitting: knitr's default device, png, is replaced.
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
  expect_inline_scatter(page)
  figures <- knitted_figures(page)
  testthat::expect_identical(basename(figures), "figure-control-1.svg")
  # Drawn as lattice draws it, as the figure no hook replaced.
  printed <- file.path(dirname(figures), "figure-printed-1.svg")
  testthat::expect_identical(unname(tools::md5sum(printed)), unname(tools::md5sum(figures)))
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

  expect_inline_scatter(page)
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
