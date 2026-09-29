# Every way a lattice (trellis) chart reaches a reader: save_html(), show()
# in each of its forms, render_maidr() in Shiny, the picture a chart the
# reading does not cover falls back to, and printing it at the console,
# where lattice's own print hook hands the chart to MAIDR. knit_print(), the
# last entry point, is tested with the rest of the knitr support.
#
# A trellis object also has to stay out of the way of what it is not: the
# Base R chart recorded on the current device, the Base R call plot()
# otherwise records, and a print meant for a file, a grob or a shared page.
#
# What each entry point makes of a chart is checked against the chart
# itself: the values against the data frame it was drawn from, every
# selector against the exported SVG it has to find the marks in, a picture
# against lattice's own drawing of the chart, and a native print against
# what the device it was meant for holds afterwards.

skip_slow_file_on_cran()

# ==============================================================================
# Helpers
# ==============================================================================

#' The chart most of these tests hand an entry point
mtcars_scatter <- function(...) {
  lattice::xyplot(mpg ~ wt, data = datasets::mtcars, ...)
}

#' The grob-name pattern of the points lattice draws for that chart
scatter_points <- "\\.xyplot\\.points\\.panel\\.1\\.1$"

#' The chart's SVG in a page or a fragment of HTML, as an XML document
#'
#' The one `<svg>` that carries `maidr-data`, parsed as the XML svglite
#' writes, since an HTML parser does not keep `<use/>` elements empty.
chart_svg <- function(html) {
  html <- paste(as.character(html), collapse = "\n")
  svg <- regmatches(
    html,
    regexpr("<svg[^>]*maidr-data=[\\s\\S]*?</svg>", html, perl = TRUE)
  )
  if (length(svg) != 1L) {
    stop("The HTML holds no chart with maidr-data.", call. = FALSE)
  }
  xml2::read_xml(svg)
}

#' The chart inside a frame, as a widget or a knitted document carries it
frame_svg <- function(iframe_html) {
  page <- xml2::read_html(paste(iframe_html, collapse = "\n"), encoding = "UTF-8")
  frames <- xml2::xml_find_all(page, "//iframe")
  testthat::expect_length(frames, 1L)
  chart_svg(xml2::xml_attr(frames[[1]], "srcdoc"))
}

#' Expect an exported chart to be the mtcars scatter, read point by point
#'
#' The values are the data frame's own, row by row. The selector has to find
#' the 32 points lattice drew and nothing else, and the k-th element it
#' finds has to be row k: each point sits where one straight-line map of its
#' row's values puts it, to the rounding of the SVG's coordinates, which a
#' single pair of rows out of place would break.
expect_mtcars_scatter <- function(svg) {
  schema <- jsonlite::fromJSON(xml2::xml_attr(svg, "maidr-data"), simplifyVector = FALSE)
  testthat::expect_length(schema$subplots, 1L)
  testthat::expect_length(schema$subplots[[1]], 1L)
  layers <- schema$subplots[[1]][[1]]$layers
  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "point")

  x <- vapply(layer$data, function(point) as.numeric(point$x), numeric(1))
  y <- vapply(layer$data, function(point) as.numeric(point$y), numeric(1))
  testthat::expect_equal(x, datasets::mtcars$wt)
  testthat::expect_equal(y, datasets::mtcars$mpg)

  testthat::expect_identical(lattice_selector_counts(svg, layer$selectors), 32L)
  nodes <- lattice_selector_nodes(svg, layer$selectors)
  for (axis in c("x", "y")) {
    placed <- data.frame(
      drawn_at = as.numeric(xml2::xml_attr(nodes, axis)),
      value = if (axis == "x") datasets::mtcars$wt else datasets::mtcars$mpg
    )
    fit <- stats::lm(drawn_at ~ value, data = placed)
    testthat::expect_gt(abs(stats::coef(fit)[[2]]), 10)
    testthat::expect_lt(max(abs(stats::resid(fit))), 0.05)
  }
  invisible(layer)
}

#' Save a plot with save_html() and read the page back
saved_html <- function(plot) {
  dir <- tempfile("maidr-lattice-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  file <- file.path(dir, "chart.html")
  maidr::save_html(plot, file)
  paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

#' The one PNG data URI in a page
png_in <- function(html) {
  regmatches(html, regexpr("data:image/png;base64,[A-Za-z0-9+/=]+", html))
}

#' A PNG of what `draw` draws, as the data URI a fallback embeds
#'
#' The device, size and resolution `create_fallback_image()` uses, so the
#' same drawing gives the same bytes.
png_uri <- function(draw, width = 7, height = 5, res = 150) {
  file <- tempfile(fileext = ".png")
  on.exit(unlink(file), add = TRUE)
  previous <- grDevices::dev.cur()
  grDevices::png(file, width = width * res, height = height * res, res = res)
  device <- grDevices::dev.cur()
  tryCatch(draw(), finally = {
    grDevices::dev.off(device)
    if (previous > 1L && previous %in% grDevices::dev.list()) {
      grDevices::dev.set(previous)
    }
  })
  paste0("data:image/png;base64,", base64enc::base64encode(file))
}

#' lattice's own drawing of a chart, which no print hook reaches
draw_with_lattice <- function(plot) {
  utils::getS3method("plot", "trellis")(plot)
}

#' The picture drawn in place of one that could not be drawn
placeholder_uri <- function() {
  maidr:::create_fallback_image(structure(list(), class = "maidr_test_not_a_plot"))
}

#' Whether a PDF written with `compress = FALSE` draws a string
#'
#' The pdf device kerns a string by splitting it inside a `TJ` array --
#' `[(maidr-file-c) 10 (hart)] TJ` -- so the pieces are joined again. Read
#' as bytes: a PDF's second line is binary, which a UTF-8 session will not
#' take as text.
pdf_draws_text <- function(file, text) {
  lines <- readLines(file, warn = FALSE)
  joined <- gsub("\\)\\s*-?[0-9.]+\\s*\\(", "", lines, useBytes = TRUE)
  any(grepl(text, joined, fixed = TRUE, useBytes = TRUE))
}

#' Stand in for a reader at the console
#'
#' `interactive()` is FALSE under testthat, and the viewer is a browser; both
#' are replaced for the calling test, and each page the viewer is handed is
#' kept in `pages`.
local_console <- function(env = parent.frame()) {
  viewer <- new.env(parent = emptyenv())
  viewer$pages <- list()
  testthat::local_mocked_bindings(
    session_is_interactive = function() TRUE,
    display_html = function(html_doc) {
      viewer$pages[[length(viewer$pages) + 1L]] <- html_doc
      invisible(NULL)
    },
    .package = "maidr",
    .env = env
  )
  viewer
}

#' Set MAIDR's print hook; answers a function that puts back what was set
use_lattice_hook <- function() {
  # Read after lattice is loaded: loading it runs MAIDR's onLoad hook.
  loadNamespace("lattice")
  state <- maidr:::.maidr_lattice_state
  saved <- list(
    option = lattice::lattice.getOption("print.function"),
    previous = state$previous_print_function,
    registered = state$registered
  )
  maidr:::register_lattice_print_method()
  function() {
    lattice::lattice.options(print.function = saved$option)
    state$previous_print_function <- saved$previous
    state$registered <- saved$registered
    state$busy <- FALSE
    invisible(NULL)
  }
}

#' Make MAIDR's hidden device current, on a new page
#'
#' It is the device a console session draws on once Base R recording has
#' opened it, and the print hook counts it as a screen. The tests of the
#' hook print onto it, so that a chart lattice draws is drawn for the reason
#' the test names and not because the device is a file, and so that what
#' was drawn can be read back off it.
#'
#' @return A list: `device`, and `close`, which closes it unless it was open
#'   already and makes the device current before it current again.
use_hidden_device <- function() {
  previous <- grDevices::dev.cur()
  tracked <- maidr:::.maidr_patching_env$.temp_device_id
  was_open <- !is.null(tracked) && tracked %in% grDevices::dev.list()
  device <- maidr:::open_maidr_temp_device()
  grid::grid.newpage()
  list(
    device = device,
    close = function() {
      if (!was_open) {
        maidr:::close_maidr_temp_device()
      }
      if (previous > 1L && previous %in% grDevices::dev.list()) {
        grDevices::dev.set(previous)
      }
      invisible(NULL)
    }
  )
}

#' Catch the screen a native drawing opens in place of MAIDR's hidden device
#'
#' A chart the hook draws natively while MAIDR's hidden device is current
#' goes onto a new device -- the screen lattice would have drawn it on --
#' which here is an off-screen one. `opened()` lists the devices opened since;
#' `close()` closes them.
use_new_screen <- function() {
  old <- options(device = function(...) grDevices::pdf(NULL))
  before <- grDevices::dev.list()
  list(
    opened = function() setdiff(grDevices::dev.list(), before),
    close = function() {
      for (device in setdiff(grDevices::dev.list(), before)) {
        grDevices::dev.off(device)
      }
      options(old)
      invisible(NULL)
    }
  )
}

#' Make sure Base R calls are recorded; answers a function that undoes it
#'
#' Recording is on after maidr loads, and the tests that need a call
#' recorded -- or need one not to be -- say so rather than trusting that no
#' earlier file left it off.
use_base_r_recording <- function() {
  old <- options(maidr.auto_show = TRUE, maidr.base_r = TRUE)
  was_active <- maidr:::is_patching_active()
  if (!was_active) {
    maidr:::initialize_base_r_patching()
  }
  function() {
    if (!was_active) {
      maidr:::restore_original_functions()
    }
    options(old)
    invisible(NULL)
  }
}

#' The names of the grobs on a device's current page
drawn_on <- function(device) {
  current <- grDevices::dev.cur()
  on.exit(
    if (current > 1L && current %in% grDevices::dev.list()) grDevices::dev.set(current),
    add = TRUE
  )
  grDevices::dev.set(device)
  as.character(grid::grid.ls(print = FALSE)$name)
}

#' Whether lattice drew the scatter on a device's current page
has_scatter <- function(device) {
  any(grepl(scatter_points, drawn_on(device)))
}

#' Run lines of R in a fresh session
#'
#' The lines load maidr with `load_maidr()` when they are ready to -- from
#' the source tree when the tests run from it, installed under R CMD check --
#' unload it with `unload_maidr()`, and report with `emit(name, value)`.
#'
#' @return A list: `status`, the session's exit status; `results`, what was
#'   emitted, as a named character vector; `errors`, what it wrote to stderr.
in_fresh_session <- function(lines) {
  rscript <- file.path(R.home("bin"), "Rscript")
  root <- normalizePath(testthat::test_path("..", ".."), mustWork = FALSE)
  # The tests beside the source tree, not beside an installed package: covr
  # runs them from inside the installed package, whose R/ holds no sources,
  # and load_all() there would load an empty namespace.
  from_source <- requireNamespace("pkgload", quietly = TRUE) &&
    file.exists(file.path(root, "DESCRIPTION")) &&
    file.exists(file.path(root, "R", "maidr.R"))
  loader <- if (from_source) {
    c(
      sprintf(
        "load_maidr <- function() suppressMessages(pkgload::load_all(%s, quiet = TRUE))",
        deparse(root)
      ),
      "unload_maidr <- function() pkgload::unload('maidr')"
    )
  } else {
    c(
      "load_maidr <- function() suppressPackageStartupMessages(library(maidr))",
      "unload_maidr <- function() detach('package:maidr', unload = TRUE)"
    )
  }

  script <- tempfile(fileext = ".R")
  errors <- tempfile(fileext = ".txt")
  on.exit(unlink(c(script, errors)), add = TRUE)
  writeLines(
    c(
      sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
      loader,
      "emit <- function(name, value) cat('RESULT', name, format(value), '\\n')",
      lines
    ),
    script
  )

  # A session that hangs -- on a viewer the mocks failed to stop -- fails
  # the tests that read it rather than the whole run.
  out <- suppressWarnings(
    system2(rscript, script, stdout = TRUE, stderr = errors, timeout = 300)
  )
  status <- attr(out, "status")
  found <- regmatches(out, regexec("^RESULT (\\S+) (.*?) ?$", out, perl = TRUE))
  found <- found[lengths(found) == 3L]
  list(
    status = if (is.null(status)) 0L else status,
    results = stats::setNames(
      vapply(found, `[`, "", 3L),
      vapply(found, `[`, "", 2L)
    ),
    errors = paste(readLines(errors, warn = FALSE), collapse = "\n")
  )
}

#' Expect a fresh session to have run to the end and emitted a value
expect_emitted <- function(session, name, value) {
  testthat::expect_identical(session$status, 0L, info = session$errors)
  testthat::expect_identical(
    unname(session$results[name]), value,
    info = paste(name, "--", session$errors)
  )
}

# Two fresh sessions, run once each and read by several tests.
#
# The console of a session that has just started is the case these tests
# cannot set up inside the suite: no device open at all, which the suite
# cannot get back to without closing devices other files may hold, and
# lattice loaded after maidr rather than before.
fresh_console_session <- local({
  session <- NULL
  function() {
    if (is.null(session)) {
      session <<- in_fresh_session(c(
        "work <- tempfile('maidr-session-')",
        "dir.create(work)",
        "setwd(work)",
        "load_maidr()",
        "emit('lattice_loaded_with_maidr', isNamespaceLoaded('lattice'))",
        "invisible(loadNamespace('lattice'))",
        "emit('hook_set_when_lattice_loads',",
        "  identical(lattice::lattice.getOption('print.function'), maidr:::maidr_print_trellis))",
        "",
        "p <- lattice::xyplot(mpg ~ wt, data = mtcars)",
        "pages <- list()",
        "shown <- testthat::with_mocked_bindings(",
        "  withVisible(print(p)),",
        "  session_is_interactive = function() TRUE,",
        "  display_html = function(html_doc) {",
        "    pages[[length(pages) + 1L]] <<- as.character(html_doc)",
        "  },",
        "  .package = 'maidr'",
        ")",
        "emit('viewer_pages', length(pages))",
        "emit('viewer_page_is_chart', length(pages) == 1L && grepl('maidr-data', pages[[1]]))",
        "emit('print_answers_object_invisibly', !shown$visible && identical(shown$value, p))",
        "emit('devices_after_print', length(grDevices::dev.list()))",
        "file <- tempfile(fileext = '.html')",
        "maidr::save_html(p, file)",
        "emit('devices_after_save_html', length(grDevices::dev.list()))",
        "emit('default_device_opened', file.exists('Rplots.pdf'))",
        "",
        "options(device = function(...) grDevices::pdf(NULL))",
        "maidr::plot(p)",
        "emit('plot_opened_a_device', grDevices::dev.cur() > 1L)",
        "emit('plot_on_hidden_device', maidr:::is_maidr_temp_device())",
        "emit('plot_recorded', maidr:::has_device_calls(grDevices::dev.cur()))",
        "emit('plot_drawn', any(grepl('\\\\.xyplot\\\\.points\\\\.panel\\\\.1\\\\.1$',",
        "  grid::grid.ls(print = FALSE)$name)))",
        "invisible(grDevices::dev.off())",
        "",
        "maidr::barplot(c(3, 1, 2))",
        "hidden <- grDevices::dev.cur()",
        "emit('barplot_opened_hidden_device', maidr:::is_maidr_temp_device())",
        "invisible(grDevices::dev.off())",
        "pdf_file <- tempfile(fileext = '.pdf')",
        "grDevices::pdf(pdf_file, compress = FALSE)",
        "emit('file_device_has_hidden_number', grDevices::dev.cur() == hidden)",
        "file_pages <- 0L",
        "testthat::with_mocked_bindings(",
        "  print(lattice::xyplot(mpg ~ wt, data = mtcars, xlab = 'maidrreusednumber')),",
        "  session_is_interactive = function() TRUE,",
        "  display_html = function(html_doc) file_pages <<- file_pages + 1L,",
        "  .package = 'maidr'",
        ")",
        "invisible(grDevices::dev.off())",
        "emit('file_device_pages', file_pages)",
        "pdf_lines <- gsub('\\\\)\\\\s*-?[0-9.]+\\\\s*\\\\(', '',",
        "  readLines(pdf_file, warn = FALSE), useBytes = TRUE)",
        "emit('file_device_holds_chart',",
        "  any(grepl('maidrreusednumber', pdf_lines, fixed = TRUE, useBytes = TRUE)))",
        "svg_file <- tempfile(fileext = '.svg')",
        "svglite::svglite(svg_file)",
        "emit('svglite_has_hidden_number', grDevices::dev.cur() == hidden)",
        "svg_pages <- 0L",
        "testthat::with_mocked_bindings(",
        "  print(lattice::xyplot(mpg ~ wt, data = mtcars, xlab = 'maidrreusedsvglite')),",
        "  session_is_interactive = function() TRUE,",
        "  display_html = function(html_doc) svg_pages <<- svg_pages + 1L,",
        "  .package = 'maidr'",
        ")",
        "invisible(grDevices::dev.off())",
        "emit('svglite_pages', svg_pages)",
        "emit('svglite_holds_chart',",
        "  any(grepl('maidrreusedsvglite', readLines(svg_file, warn = FALSE), fixed = TRUE)))",
        "grab_pages <- 0L",
        "grabbed <- testthat::with_mocked_bindings(",
        "  grid::grid.grabExpr({",
        "    emit('grab_has_hidden_number', grDevices::dev.cur() == hidden)",
        "    print(lattice::xyplot(mpg ~ wt, data = mtcars))",
        "  }),",
        "  session_is_interactive = function() TRUE,",
        "  display_html = function(html_doc) grab_pages <<- grab_pages + 1L,",
        "  .package = 'maidr'",
        ")",
        "invisible(grDevices::graphics.off())",
        "emit('grab_pages', grab_pages)",
        "emit('grab_holds_chart', any(grepl('\\\\.xyplot\\\\.points\\\\.panel\\\\.1\\\\.1$',",
        "  grid::grid.ls(grabbed, print = FALSE)$name)))",
        "",
        "invisible(unloadNamespace('lattice'))",
        "invisible(loadNamespace('lattice'))",
        "emit('hook_set_when_lattice_reloads',",
        "  identical(lattice::lattice.getOption('print.function'), maidr:::maidr_print_trellis))",
        "",
        "unload_maidr()",
        "emit('maidr_unloaded', !isNamespaceLoaded('maidr'))",
        "emit('print_function_after_unload',",
        "  is.null(lattice::lattice.getOption('print.function')))",
        "emit('lattice_onload_hooks_after_unload',",
        "  length(getHook(packageEvent('lattice', 'onLoad'))))"
      ))
    }
    session
  }
})

fresh_session_print_function <- local({
  session <- NULL
  function() {
    if (is.null(session)) {
      session <<- in_fresh_session(c(
        "invisible(loadNamespace('lattice'))",
        "calls <- 0L",
        "mine <- function(x, ...) {",
        "  calls <<- calls + 1L",
        "  utils::getS3method('plot', 'trellis')(x, ...)",
        "}",
        "lattice::lattice.options(print.function = mine)",
        "load_maidr()",
        "emit('hook_set_at_load',",
        "  identical(lattice::lattice.getOption('print.function'), maidr:::maidr_print_trellis))",
        "emit('previous_is_mine',",
        "  identical(maidr:::.maidr_lattice_state$previous_print_function, mine))",
        "grDevices::pdf(NULL)",
        "shown <- withVisible(print(lattice::xyplot(mpg ~ wt, data = mtcars)))",
        "emit('calls_to_mine', calls)",
        "emit('drawn', any(grepl('\\\\.xyplot\\\\.points\\\\.panel\\\\.1\\\\.1$',",
        "  grid::grid.ls(print = FALSE)$name)))",
        "emit('print_answers_invisibly', !shown$visible)",
        "invisible(grDevices::dev.off())",
        "unload_maidr()",
        "emit('mine_after_unload', identical(lattice::lattice.getOption('print.function'), mine))"
      ))
    }
    session
  }
})

# ==============================================================================
# Saving a page
# ==============================================================================

test_that("save_html() writes a lattice chart MAIDR reads, point by point", {
  skip_if_no_lattice()

  html <- saved_html(mtcars_scatter())

  testthat::expect_false(grepl("data:image/png", html, fixed = TRUE))
  expect_mtcars_scatter(chart_svg(html))
})

test_that("save_html() exports the lattice chart, not a Base R chart the device recorded", {
  skip_if_no_lattice()

  # The Base R adapter claims by device state, because a Base R chart is not
  # an object; with a call recorded it used to claim anything it was given,
  # and a trellis object was saved as the recorded bar chart.
  undo_recording <- use_base_r_recording()
  on.exit(undo_recording(), add = TRUE)
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device)
      grDevices::dev.off(device)
    },
    add = TRUE
  )
  clear_base_r_device(device)
  barplot(c(3, 1, 2))
  testthat::expect_true(maidr:::has_device_calls(device))

  p <- mtcars_scatter()
  registry <- maidr:::get_global_registry()
  base_r <- registry$get_adapter("base_r")
  testthat::expect_true(base_r$can_handle(NULL))
  testthat::expect_false(base_r$can_handle(p))
  testthat::expect_identical(registry$detect_system(p), "lattice")

  expect_mtcars_scatter(chart_svg(saved_html(p)))

  # The recorded chart is still the device's, for the show() it waits for.
  testthat::expect_true(maidr:::has_device_calls(device))
})

test_that("a Base R chart passed to save_html() as its return value is still read", {
  # `save_html(barplot(x), file)` hands over the bar midpoints, which are no
  # plot; the device's recorded call is the chart, and has to stay so.
  undo_recording <- use_base_r_recording()
  on.exit(undo_recording(), add = TRUE)
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device)
      grDevices::dev.off(device)
    },
    add = TRUE
  )
  clear_base_r_device(device)

  svg <- chart_svg(saved_html(barplot(c(3, 1, 2))))
  schema <- jsonlite::fromJSON(xml2::xml_attr(svg, "maidr-data"), simplifyVector = FALSE)
  layer <- schema$subplots[[1]][[1]]$layers[[1]]
  testthat::expect_identical(layer$type, "bar")
  testthat::expect_equal(
    vapply(layer$data, function(bar) as.numeric(bar$y), numeric(1)),
    c(3, 1, 2)
  )

  # The selector is the Base R shape `#<id> rect`: the three bars, drawn to
  # the heights of the values, in their order.
  id <- gsub("\\\\(.)", "\\1", sub("^#(\\S+) rect$", "\\1", layer$selectors))
  bars <- xml2::xml_find_all(
    svg,
    sprintf("//*[@id='%s']//*[local-name()='rect']", id)
  )
  testthat::expect_length(bars, 3L)
  heights <- as.numeric(xml2::xml_attr(bars, "height"))
  testthat::expect_equal(heights / heights[2], c(3, 1, 2), tolerance = 1e-3)
})

test_that("save_html() of a chart the reading does not cover writes lattice's own picture of it", {
  skip_if_no_lattice()

  p <- lattice::cloud(mpg ~ wt * hp, data = datasets::mtcars)
  testthat::expect_warning(html <- saved_html(p), "unsupported elements")

  testthat::expect_false(grepl("maidr-data", html, fixed = TRUE))
  image <- png_in(html)
  testthat::expect_length(image, 1L)
  # Byte for byte the picture lattice draws of the chart on the same device,
  # which is the chart and not the placeholder drawn when drawing fails.
  testthat::expect_identical(image, png_uri(function() draw_with_lattice(p)))
  testthat::expect_false(identical(image, placeholder_uri()))
})

test_that("the picture of a chart laid out over several pages is its first page", {
  skip_if_no_lattice()

  p <- lattice::xyplot(mpg ~ wt | factor(cyl), data = datasets::mtcars, layout = c(1, 1))

  # lattice's own drawing of every page, one file per page.
  dir <- tempfile("maidr-pages-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  grDevices::png(file.path(dir, "page%d.png"), width = 7 * 150, height = 5 * 150, res = 150)
  device <- grDevices::dev.cur()
  tryCatch(draw_with_lattice(p), finally = grDevices::dev.off(device))
  pages <- file.path(dir, sprintf("page%d.png", 1:3))
  testthat::expect_true(all(file.exists(pages)))
  page_uri <- function(file) paste0("data:image/png;base64,", base64enc::base64encode(file))

  # The picture says it is one page of several, as the reading does.
  testthat::expect_warning(
    image <- maidr:::create_fallback_image(p),
    "laid out on 3 pages. Only the first page is shown as an image",
    fixed = TRUE
  )
  testthat::expect_identical(image, page_uri(pages[1]))
  testthat::expect_false(identical(image, page_uri(pages[3])))
})

test_that("a picture of a chart leaves lattice's last object as it was, never a first page", {
  skip_if_no_lattice()
  custom_panel <- function(x, y, ...) {
    lattice::panel.xyplot(x, y, ...)
    lattice::panel.lmline(x, y)
  }
  multi <- lattice::xyplot(
    mpg ~ wt | factor(cyl), datasets::mtcars,
    layout = c(1, 1), panel = custom_panel
  )
  single <- lattice::xyplot(mpg ~ wt | factor(cyl), datasets::mtcars, panel = custom_panel)
  drawn <- lattice::xyplot(disp ~ hp, datasets::mtcars)
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  utils::getS3method("plot", "trellis")(drawn)
  grDevices::dev.off(device)

  # A picture saved or shown is no print of the reader's.
  suppressWarnings(maidr:::create_fallback_image(multi))
  maidr:::create_fallback_image(single)
  testthat::expect_identical(lattice::trellis.last.object(), drawn)

  # A print the console hook opens the viewer for is: the chart printed is
  # the last object, but never a first page cut from a longer one, which
  # update(trellis.last.object()) would carry on from without the others.
  state <- maidr:::.maidr_lattice_state
  state$busy <- TRUE
  on.exit(state$busy <- FALSE, add = TRUE)
  maidr:::create_fallback_image(single)
  testthat::expect_identical(lattice::trellis.last.object(), single)
  suppressWarnings(maidr:::create_fallback_image(multi))
  testthat::expect_null(suppressWarnings(lattice::trellis.last.object()))
})

test_that("saving a lattice chart leaves lattice acting on the chart the reader drew", {
  skip_if_no_lattice()

  # lattice's trellis.focus(), trellis.currentLayout() and panel.identify()
  # act on the chart it drew last, and MAIDR draws its own copy off-screen.
  # A chart drawn into a file and annotated after an accessible copy is
  # saved is annotated on the file, as it would be without the copy.
  file <- tempfile(fileext = ".pdf")
  on.exit(unlink(file), add = TRUE)
  grDevices::pdf(file)
  device <- grDevices::dev.cur()
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)

  drawn <- lattice::xyplot(mpg ~ wt | factor(cyl), data = datasets::mtcars, layout = c(3, 1))
  utils::getS3method("plot", "trellis")(drawn)
  layout <- lattice::trellis.currentLayout()

  saved_html(mtcars_scatter())
  maidr::show(mtcars_scatter(), as_widget = TRUE)

  testthat::expect_identical(lattice::trellis.currentLayout(), layout)
  testthat::expect_no_error({
    lattice::trellis.focus("panel", 3, 1, highlight = FALSE)
    lattice::panel.abline(h = 20)
    lattice::trellis.unfocus()
  })
})

# ==============================================================================
# Showing a chart
# ==============================================================================

test_that("show() opens a lattice chart in the viewer", {
  skip_if_no_lattice()
  viewer <- local_console()

  result <- withVisible(maidr::show(mtcars_scatter()))

  testthat::expect_null(result$value)
  testthat::expect_false(result$visible)
  testthat::expect_length(viewer$pages, 1L)
  expect_mtcars_scatter(chart_svg(viewer$pages[[1]]))
})

test_that("show(as_widget = TRUE) returns a maidr htmlwidget holding the chart", {
  skip_if_no_lattice()

  widget <- maidr::show(mtcars_scatter(), as_widget = TRUE, use_cdn = TRUE)

  testthat::expect_s3_class(widget, "htmlwidget")
  testthat::expect_s3_class(widget, "maidr")
  expect_mtcars_scatter(frame_svg(widget$x$iframe_content))
})

test_that("show(shiny = TRUE) returns the chart's HTML", {
  skip_if_no_lattice()

  html <- maidr::show(mtcars_scatter(), shiny = TRUE)

  testthat::expect_s3_class(html, "html")
  expect_mtcars_scatter(chart_svg(html))
})

test_that("show() of a chart the reading does not cover draws it with lattice on a new device", {
  skip_if_no_lattice()
  viewer <- local_console()

  # The device a session opens when asked for a new one; a screen at the
  # console, and here one that writes no file.
  old <- options(device = function(...) grDevices::pdf(NULL))
  on.exit(options(old), add = TRUE)
  before <- grDevices::dev.list()
  on.exit(
    for (device in setdiff(grDevices::dev.list(), before)) grDevices::dev.off(device),
    add = TRUE
  )

  p <- lattice::cloud(mpg ~ wt * hp, data = datasets::mtcars)
  testthat::expect_warning(maidr::show(p), "unsupported elements")

  opened <- setdiff(grDevices::dev.list(), before)
  testthat::expect_length(opened, 1L)
  testthat::expect_true(any(grepl("\\.3dscatter\\.points", drawn_on(opened))))
  testthat::expect_length(viewer$pages, 0L)
})

test_that("show() of anything else is still methods::show()'s to print", {
  skip_if_no_lattice()

  # A summary of a trellis object is lattice's, and is not a chart.
  summary <- summary(mtcars_scatter())
  testthat::expect_false(inherits(summary, "trellis"))
  testthat::expect_output(maidr::show(summary), "Number of observations", fixed = TRUE)
  testthat::expect_output(maidr::show(data.frame(cyl = 4)), "cyl", fixed = TRUE)
})

test_that("maidr_widget() names lattice among the plots it takes", {
  # Other tests match the start of the message; it has to keep it.
  testthat::expect_error(
    maidr:::maidr_widget(42),
    "^Input must be a ggplot object, a lattice \\(trellis\\) object, or NULL"
  )
})

# ==============================================================================
# Shiny
# ==============================================================================

#' The chart in the widget a Shiny output holds
output_svg <- function(value) {
  frame_svg(jsonlite::fromJSON(as.character(value))$x$iframe_content)
}

test_that("render_maidr() renders a trellis object the expression returns", {
  skip_if_no_lattice()
  testthat::skip_if_not_installed("shiny")
  testthat::local_mocked_bindings(maidr_internet_available = function() TRUE, .package = "maidr")
  undo_recording <- use_base_r_recording()
  on.exit(undo_recording(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(
    {
      clear_base_r_device(screen$device)
      screen$close()
    },
    add = TRUE
  )

  # The object returned is the chart, as a returned ggplot is, even from an
  # expression that also drew with Base R on its way to it.
  server <- function(input, output, session) {
    output$returned <- render_maidr({
      lattice::xyplot(mpg ~ wt, data = datasets::mtcars)
    })
    output$after_base_r <- render_maidr({
      plot(1:3)
      lattice::xyplot(mpg ~ wt, data = datasets::mtcars)
    })
  }

  shiny::testServer(server, {
    expect_mtcars_scatter(output_svg(output$returned))
    expect_mtcars_scatter(output_svg(output$after_base_r))
  })
})

test_that("render_maidr() renders a chart the expression prints, which lattice draws", {
  skip_if_no_lattice()
  testthat::skip_if_not_installed("shiny")
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  viewer <- local_console()
  testthat::local_mocked_bindings(maidr_internet_available = function() TRUE, .package = "maidr")
  # Anything that got past the viewer to a browser would land here.
  browsed <- character(0)
  old <- options(
    browser = function(url) browsed <<- c(browsed, url),
    viewer = function(url, ...) browsed <<- c(browsed, url)
  )
  on.exit(options(old), add = TRUE)

  # With the reader's console and a screen device standing in, the only
  # thing between this print and the viewer is the reactive domain it runs
  # in: it is render_maidr()'s to show the chart, which it does from the
  # object print() answers, and lattice draws it where it was asked to.
  server <- function(input, output, session) {
    output$chart <- render_maidr({
      print(lattice::xyplot(mpg ~ wt, data = datasets::mtcars))
    })
  }

  shiny::testServer(server, {
    expect_mtcars_scatter(output_svg(output$chart))
  })

  testthat::expect_length(viewer$pages, 0L)
  testthat::expect_length(browsed, 0L)
  testthat::expect_true(has_scatter(screen$device))
})

# ==============================================================================
# Printing at the console
# ==============================================================================

test_that("printing a trellis object at the console opens it in the viewer", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  viewer <- local_console()

  p <- mtcars_scatter()
  shown <- withVisible(print(p))

  testthat::expect_length(viewer$pages, 1L)
  expect_mtcars_scatter(chart_svg(viewer$pages[[1]]))
  # In the viewer instead of on the screen, not as well as.
  testthat::expect_false(has_scatter(screen$device))
  # lattice's print answers the object, invisibly, as it does without MAIDR.
  testthat::expect_false(shown$visible)
  testthat::expect_identical(shown$value, p)
})

test_that("a print that places the chart on a shared page is drawn by lattice", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  viewer <- local_console()

  # lattice's own idiom for arranging several charts on one page. The
  # arguments are matched as plot.trellis() matches them, so a position
  # given by place or by a partial name places the chart just the same.
  compositions <- list(
    "split and more" = list(split = c(1, 1, 2, 1), more = TRUE),
    "more" = list(more = TRUE),
    "position" = list(position = c(0, 0, 0.5, 1)),
    "position by place" = list(c(0, 0, 0.5, 1)),
    "position by partial name" = list(pos = c(0, 0, 0.5, 1)),
    "split by place" = list(NULL, c(1, 1, 2, 1)),
    "newpage = FALSE" = list(newpage = FALSE),
    "draw.in" = list(draw.in = "maidr_test_region")
  )

  p <- mtcars_scatter()
  for (composition in names(compositions)) {
    grid::grid.newpage()
    if (composition == "draw.in") {
      grid::pushViewport(grid::viewport(width = 0.5, name = "maidr_test_region"))
      grid::upViewport()
    }
    shown <- withVisible(do.call(print, c(list(p), compositions[[composition]])))

    testthat::expect_length(viewer$pages, 0L)
    testthat::expect_true(has_scatter(screen$device), label = composition)
    testthat::expect_false(shown$visible, label = composition)
  }
  # The last composition was drawn without `more`, so lattice's own record
  # of a page still being composed is closed again for later prints.
})

test_that("a chart that carries its place on a shared page is drawn by lattice", {
  # plot.trellis() takes any argument print() was not given from the
  # object's `plot.args`, which `xyplot(plot.args = )` and `update()` set,
  # so such a chart shares its page just as one given the arguments does.
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  viewer <- local_console()

  left <- mtcars_scatter(plot.args = list(split = c(1, 1, 2, 1), more = TRUE))
  right <- update(mtcars_scatter(), plot.args = list(split = c(2, 1, 2, 1)))
  print(left)
  print(right)

  testthat::expect_length(viewer$pages, 0L)
  testthat::expect_identical(sum(grepl(scatter_points, drawn_on(screen$device))), 2L)

  # An argument print() is given wins over the stored one, as in lattice,
  # and lattice takes a stored one only by its exact name.
  print(right, split = NULL)
  print(mtcars_scatter(plot.args = list(pos = c(0, 0, 0.5, 1))))
  testthat::expect_length(viewer$pages, 2L)
})

test_that("a print into a file is drawn into the file", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  viewer <- local_console()

  file <- tempfile(fileext = ".pdf")
  on.exit(unlink(file), add = TRUE)
  grDevices::pdf(file, compress = FALSE)
  device <- grDevices::dev.cur()
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)

  print(mtcars_scatter(xlab = "maidrfilechart"))
  grDevices::dev.off(device)

  testthat::expect_length(viewer$pages, 0L)
  testthat::expect_true(pdf_draws_text(file, "maidrfilechart"))
})

test_that("a print captured as a grob is drawn into the grob", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  viewer <- local_console()

  p <- mtcars_scatter()
  grabbed <- grid::grid.grabExpr(print(p), warn = 0)
  testthat::expect_true(any(grepl(scatter_points, grid::grid.ls(grabbed, print = FALSE)$name)))

  # ggplotify, which maidr imports, turns a trellis object into a grob the
  # same way, and patchwork and cowplot compose one through it.
  converted <- ggplotify::as.grob(p)
  testthat::expect_true(any(grepl(scatter_points, grid::grid.ls(converted, print = FALSE)$name)))

  testthat::expect_length(viewer$pages, 0L)
})

test_that("a print while knitr is running is drawn by lattice", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  viewer <- local_console()

  # knitr records what is drawn as the chunk's figure; a chart a chunk
  # returns is knit_print.trellis()'s to make accessible.
  old <- options(knitr.in.progress = TRUE)
  on.exit(options(old), add = TRUE)

  print(mtcars_scatter())

  testthat::expect_length(viewer$pages, 0L)
  testthat::expect_true(has_scatter(screen$device))
})

test_that("a print with lattice interception or all interception off is drawn by lattice", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  viewer <- local_console()
  old <- options(maidr.lattice = TRUE, maidr.auto_show = TRUE)
  on.exit(options(old), add = TRUE)

  for (off in list(list(maidr.lattice = FALSE), list(maidr.auto_show = FALSE))) {
    grid::grid.newpage()
    switched <- options(off)
    print(mtcars_scatter())
    options(switched)

    testthat::expect_length(viewer$pages, 0L)
    testthat::expect_true(has_scatter(screen$device), label = names(off))
  }
})

test_that("a print outside an interactive session is drawn by lattice", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)

  # An Rscript or a batch job has no reader to open a viewer for.
  pages <- 0L
  testthat::local_mocked_bindings(
    session_is_interactive = function() FALSE,
    display_html = function(html_doc) pages <<- pages + 1L,
    .package = "maidr"
  )

  print(mtcars_scatter())

  testthat::expect_identical(pages, 0L)
  testthat::expect_true(has_scatter(screen$device))
})

test_that("a printed chart the reading does not cover is drawn by lattice", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  fresh <- use_new_screen()
  on.exit(fresh$close(), add = TRUE)
  viewer <- local_console()

  shown <- withVisible(print(lattice::cloud(mpg ~ wt * hp, data = datasets::mtcars)))

  # Drawn on a screen of its own, not into MAIDR's hidden device, which is
  # current again afterwards for the Base R chart it holds.
  testthat::expect_length(viewer$pages, 0L)
  opened <- fresh$opened()
  testthat::expect_length(opened, 1L)
  testthat::expect_true(any(grepl("\\.3dscatter\\.points", drawn_on(opened))))
  testthat::expect_false(any(grepl("\\.3dscatter\\.points", drawn_on(screen$device))))
  testthat::expect_identical(grDevices::dev.cur(), screen$device)
  testthat::expect_false(shown$visible)
})

test_that("a chart that cannot be exported opens as lattice's picture of it", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  viewer <- local_console()
  # The export is where a chart that was read can still fail, and with
  # fallback on build_interactive_svg() makes the failure a picture.
  testthat::local_mocked_bindings(
    create_enhanced_svg = function(...) stop("the export failed"),
    .package = "maidr"
  )

  testthat::expect_warning(print(mtcars_scatter()), "the export failed")

  testthat::expect_length(viewer$pages, 1L)
  testthat::expect_identical(
    png_in(as.character(viewer$pages[[1]])),
    png_uri(function() draw_with_lattice(mtcars_scatter()))
  )
  testthat::expect_false(maidr:::.maidr_lattice_state$busy)
})

test_that("a chart that fails to render with fallback off is drawn by lattice", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  fresh <- use_new_screen()
  on.exit(fresh$close(), add = TRUE)
  viewer <- local_console()
  old <- options(maidr.fallback_enabled = FALSE)
  on.exit(options(old), add = TRUE)
  testthat::local_mocked_bindings(
    create_enhanced_svg = function(...) stop("the export failed"),
    .package = "maidr"
  )

  print(mtcars_scatter())

  testthat::expect_length(viewer$pages, 0L)
  testthat::expect_length(fresh$opened(), 1L)
  testthat::expect_true(has_scatter(fresh$opened()))
  testthat::expect_false(has_scatter(screen$device))
  testthat::expect_identical(grDevices::dev.cur(), screen$device)
  testthat::expect_false(maidr:::.maidr_lattice_state$busy)
})

test_that("a chart the viewer cannot be opened for is drawn by lattice", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)
  fresh <- use_new_screen()
  on.exit(fresh$close(), add = TRUE)
  testthat::local_mocked_bindings(
    session_is_interactive = function() TRUE,
    display_html = function(html_doc) stop("no browser to open"),
    .package = "maidr"
  )

  print(mtcars_scatter())

  testthat::expect_length(fresh$opened(), 1L)
  testthat::expect_true(has_scatter(fresh$opened()))
  testthat::expect_identical(grDevices::dev.cur(), screen$device)
  testthat::expect_false(maidr:::.maidr_lattice_state$busy)
})

test_that("a print made while MAIDR renders is drawn by lattice, and never recurses", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)
  screen <- use_hidden_device()
  on.exit(screen$close(), add = TRUE)

  # Whatever runs while the chart is rendered -- here, the viewer itself --
  # printing the chart again draws it, rather than rendering it again.
  p <- mtcars_scatter()
  pages <- 0L
  testthat::local_mocked_bindings(
    session_is_interactive = function() TRUE,
    display_html = function(html_doc) {
      pages <<- pages + 1L
      print(p)
    },
    .package = "maidr"
  )

  print(p)

  testthat::expect_identical(pages, 1L)
  testthat::expect_true(has_scatter(screen$device))
  testthat::expect_false(maidr:::.maidr_lattice_state$busy)
})

test_that("MAIDR's print hook keeps the print function it replaced, and puts it back", {
  skip_if_no_lattice()
  restore <- use_lattice_hook()
  on.exit(restore(), add = TRUE)

  calls <- 0L
  mine <- function(x, ...) {
    calls <<- calls + 1L
    utils::getS3method("plot", "trellis")(x, ...)
  }
  maidr:::restore_lattice_print_method()
  lattice::lattice.options(print.function = mine)

  maidr:::register_lattice_print_method()
  testthat::expect_identical(
    lattice::lattice.getOption("print.function"), maidr:::maidr_print_trellis
  )
  # Setting it again changes nothing: what it keeps is the function it
  # replaced, never its own.
  maidr:::register_lattice_print_method()
  testthat::expect_identical(maidr:::.maidr_lattice_state$previous_print_function, mine)

  # A print MAIDR does not render -- this one is into a file -- is drawn with
  # that function, once.
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)
  print(mtcars_scatter())
  testthat::expect_identical(calls, 1L)
  testthat::expect_true(has_scatter(device))

  maidr:::restore_lattice_print_method()
  testthat::expect_identical(lattice::lattice.getOption("print.function"), mine)

  # One the user set over MAIDR's is theirs, and is left alone; and it is
  # the one a chart MAIDR draws natively -- show()'s or knitr's -- is drawn
  # with, not the one MAIDR kept from before.
  maidr:::register_lattice_print_method()
  other_calls <- 0L
  other <- function(x, ...) {
    other_calls <<- other_calls + 1L
    utils::getS3method("plot", "trellis")(x, ...)
  }
  lattice::lattice.options(print.function = other)
  maidr:::restore_lattice_print_method()
  testthat::expect_identical(lattice::lattice.getOption("print.function"), other)
  maidr:::print_trellis_natively(mtcars_scatter())
  testthat::expect_identical(other_calls, 1L)
  testthat::expect_identical(calls, 1L)

  # And MAIDR's is set again over it when asked to, keeping it: a flag
  # saying the hook was still set used to leave maidr_on() doing nothing.
  maidr:::register_lattice_print_method()
  testthat::expect_identical(
    lattice::lattice.getOption("print.function"), maidr:::maidr_print_trellis
  )
  testthat::expect_identical(maidr:::.maidr_lattice_state$previous_print_function, other)
})

test_that("MAIDR's hook is set when lattice loads after maidr, and again when it reloads", {
  skip_if_no_lattice()
  session <- fresh_console_session()

  # lattice is not one of maidr's imports, so in a fresh session it loads
  # after maidr, and only the onLoad hook can set the print function. Loaded
  # again, its options start over, and the hook has to set it again.
  testthat::expect_identical(session$status, 0L, info = session$errors)
  testthat::skip_if(
    identical(unname(session$results["lattice_loaded_with_maidr"]), "TRUE"),
    "something maidr imports loads lattice, so it cannot load after maidr"
  )
  expect_emitted(session, "hook_set_when_lattice_loads", "TRUE")
  expect_emitted(session, "hook_set_when_lattice_reloads", "TRUE")
})

test_that("a print at the console of a fresh session opens the viewer and leaves no device open", {
  skip_if_no_lattice()
  session <- fresh_console_session()

  expect_emitted(session, "viewer_pages", "1")
  expect_emitted(session, "viewer_page_is_chart", "TRUE")
  expect_emitted(session, "print_answers_object_invisibly", "TRUE")
  # With no device open, reading the chart used to open the default device
  # and leave it open behind it: a blank window beside the viewer at the
  # console, and in a script, as here, an Rplots.pdf.
  expect_emitted(session, "devices_after_print", "0")
  expect_emitted(session, "devices_after_save_html", "0")
  expect_emitted(session, "default_device_opened", "FALSE")
})

test_that("a file device given the number of MAIDR's closed hidden device gets the chart", {
  skip_if_no_lattice()
  session <- fresh_console_session()

  # R hands a closed device's number to the next device opened, so after the
  # reader closes the device Base R recording opened, a pdf() they open is
  # known by the hidden device's number. The chart has to go into their file.
  expect_emitted(session, "barplot_opened_hidden_device", "TRUE")
  expect_emitted(session, "file_device_has_hidden_number", "TRUE")
  expect_emitted(session, "file_device_pages", "0")
  expect_emitted(session, "file_device_holds_chart", "TRUE")
})

test_that("a device that records no file, given the hidden device's number, gets the chart", {
  skip_if_no_lattice()
  session <- fresh_console_session()

  # svglite's device, and the pdf(NULL) grid.grabExpr() opens, record no
  # file in .Devices; the hidden device always does, so neither is it.
  expect_emitted(session, "svglite_has_hidden_number", "TRUE")
  expect_emitted(session, "svglite_pages", "0")
  expect_emitted(session, "svglite_holds_chart", "TRUE")
  expect_emitted(session, "grab_has_hidden_number", "TRUE")
  expect_emitted(session, "grab_pages", "0")
  expect_emitted(session, "grab_holds_chart", "TRUE")
})

test_that("unloading maidr puts lattice's print function back and drops its hook", {
  skip_if_no_lattice()
  session <- fresh_console_session()

  # lattice outlives maidr; a print function left behind would be a function
  # from a namespace that is gone.
  expect_emitted(session, "maidr_unloaded", "TRUE")
  expect_emitted(session, "print_function_after_unload", "TRUE")
  expect_emitted(session, "lattice_onload_hooks_after_unload", "0")
})

test_that("a print function set before maidr loads is kept, drawn with, and put back", {
  skip_if_no_lattice()
  session <- fresh_session_print_function()

  expect_emitted(session, "hook_set_at_load", "TRUE")
  expect_emitted(session, "previous_is_mine", "TRUE")
  expect_emitted(session, "calls_to_mine", "1")
  expect_emitted(session, "drawn", "TRUE")
  expect_emitted(session, "print_answers_invisibly", "TRUE")
  expect_emitted(session, "mine_after_unload", "TRUE")
})

test_that("the default device a native drawing opened stays the reader's screen", {
  skip_if_no_lattice()
  # With no display R's default device is pdf() on Rplots.pdf. A chart MAIDR
  # cannot read, drawn by lattice with no device open, opens it; the reader
  # chose no file, and the charts they print next still open the viewer.
  session <- in_fresh_session(c(
    "work <- tempfile('maidr-session-')",
    "dir.create(work)",
    "setwd(work)",
    "options(device = 'pdf')",
    "load_maidr()",
    "invisible(loadNamespace('lattice'))",
    "pages <- 0L",
    "view <- function(p) testthat::with_mocked_bindings(",
    "  print(p),",
    "  session_is_interactive = function() TRUE,",
    "  display_html = function(html_doc) pages <<- pages + 1L,",
    "  .package = 'maidr'",
    ")",
    "view(lattice::cloud(mpg ~ wt * hp, data = mtcars))",
    "emit('default_opened', names(grDevices::dev.cur()))",
    "view(lattice::xyplot(mpg ~ wt, data = mtcars))",
    "emit('pages_after', pages)",
    "invisible(grDevices::graphics.off())"
  ))
  expect_emitted(session, "default_opened", "pdf")
  expect_emitted(session, "pages_after", "1")
})

test_that("a pdf() the reader opens once that default device is closed gets the chart", {
  skip_if_no_lattice()
  # R gives the closed device's number to the next one, and pdf() with no
  # file writes Rplots.pdf, so the reader's own pdf() has the number, name
  # and file of the device R opened by default. It is a file the reader
  # chose, and a print there is drawn into it, not taken to the viewer.
  session <- in_fresh_session(c(
    "work <- tempfile('maidr-session-')",
    "dir.create(work)",
    "setwd(work)",
    "options(device = 'pdf')",
    "load_maidr()",
    "invisible(loadNamespace('lattice'))",
    "pages <- 0L",
    "view <- function(p, ...) testthat::with_mocked_bindings(",
    "  print(p, ...),",
    "  session_is_interactive = function() TRUE,",
    "  display_html = function(html_doc) pages <<- pages + 1L,",
    "  .package = 'maidr'",
    ")",
    "view(lattice::cloud(mpg ~ wt * hp, data = mtcars))",
    "invisible(grDevices::dev.off())",
    "grDevices::pdf()",
    "emit('reused', paste(grDevices::dev.cur(), names(grDevices::dev.cur())))",
    "view(lattice::xyplot(mpg ~ wt, data = mtcars))",
    "emit('pages_after_pdf', pages)",
    sprintf(
      "emit('drawn_in_file', any(grepl(%s, grid::grid.ls(print = FALSE)$name)))",
      deparse(scatter_points)
    ),
    "invisible(grDevices::dev.off())",
    # A composition opens the default device the same way.
    "view(lattice::xyplot(mpg ~ wt, data = mtcars), split = c(1, 1, 2, 1))",
    "invisible(grDevices::graphics.off())",
    "grDevices::pdf()",
    "view(lattice::xyplot(mpg ~ wt, data = mtcars))",
    "emit('pages_after_composition', pages)",
    "invisible(grDevices::dev.off())",
    # Closed and opened again within one call, as a function or a sourced
    # script does, with nothing run between the two.
    "view(lattice::cloud(mpg ~ wt * hp, data = mtcars))",
    "local({",
    "  grDevices::dev.off()",
    "  grDevices::pdf()",
    "  view(lattice::xyplot(mpg ~ wt, data = mtcars))",
    "})",
    "emit('pages_within_one_call', pages)",
    "invisible(grDevices::dev.off())"
  ))
  expect_emitted(session, "reused", "2 pdf")
  expect_emitted(session, "pages_after_pdf", "0")
  expect_emitted(session, "drawn_in_file", "TRUE")
  expect_emitted(session, "pages_after_composition", "0")
  expect_emitted(session, "pages_within_one_call", "0")
})

test_that("an option off when lattice loads and set back on opens the viewer, as ggplot2's does", {
  skip_if_no_lattice()

  # From an .Rprofile, or while a package that imports lattice (Matrix,
  # nlme) loaded it: the option is read at each print, not when lattice loads.
  for (option in c("maidr.lattice", "maidr.auto_show")) {
    session <- in_fresh_session(c(
      "work <- tempfile('maidr-session-')",
      "dir.create(work)",
      "setwd(work)",
      sprintf("options(%s = FALSE)", option),
      "load_maidr()",
      "invisible(loadNamespace('lattice'))",
      "p <- lattice::xyplot(mpg ~ wt, data = mtcars)",
      "pages <- 0L",
      "view <- function() testthat::with_mocked_bindings(",
      "  print(p),",
      "  session_is_interactive = function() TRUE,",
      "  screen_device_is_current = function() TRUE,",
      "  display_html = function(html_doc) pages <<- pages + 1L,",
      "  .package = 'maidr'",
      ")",
      "grDevices::pdf(NULL)",
      "view()",
      "emit('pages_while_off', pages)",
      sprintf("options(%s = TRUE)", option),
      "view()",
      "emit('pages_once_on', pages)",
      "invisible(grDevices::dev.off())"
    ))
    expect_emitted(session, "pages_while_off", "0")
    expect_emitted(session, "pages_once_on", "1")
  }

  # maidr_off() is not undone by a lattice that loads after it.
  session <- in_fresh_session(c(
    "load_maidr()",
    "maidr::maidr_off()",
    "invisible(loadNamespace('lattice'))",
    "emit('set_after_off', !is.null(lattice::lattice.getOption('print.function')))",
    "maidr::maidr_on()",
    "emit('set_after_on',",
    "  identical(lattice::lattice.getOption('print.function'), maidr:::maidr_print_trellis))"
  ))
  expect_emitted(session, "set_after_off", "FALSE")
  expect_emitted(session, "set_after_on", "TRUE")
})

# ==============================================================================
# Base R's plot
# ==============================================================================

test_that("plot() of a trellis or ggplot object is drawn on the current device, unrecorded", {
  skip_if_no_lattice()
  testthat::skip_if_not_installed("ggplot2")

  undo_recording <- use_base_r_recording()
  on.exit(undo_recording(), add = TRUE)
  hidden_before <- maidr:::.maidr_patching_env$.temp_device_id

  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device)
      grDevices::dev.off(device)
    },
    add = TRUE
  )
  clear_base_r_device(device)

  # The plot() a reader reaches with maidr attached records Base R charts...
  maidr::plot(1:3)
  testthat::expect_true(maidr:::has_device_calls(device))
  clear_base_r_device(device)

  # ...and hands a trellis or ggplot object to its own package, which draws
  # it with grid where it was asked to, and records nothing.
  grid::grid.newpage()
  maidr::plot(mtcars_scatter())
  testthat::expect_false(maidr:::has_device_calls(device))
  testthat::expect_true(has_scatter(device))

  grid::grid.newpage()
  maidr::plot(
    ggplot2::ggplot(datasets::mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  )
  testthat::expect_false(maidr:::has_device_calls(device))
  # A gtable lists its panels only once forced to them.
  testthat::expect_identical(drawn_on(device), "layout")
  grDevices::dev.set(device)
  panels <- grid::grid.force(grid::grid.get("layout"))
  drawn <- grid::grid.ls(panels, print = FALSE)$name
  testthat::expect_true(any(grepl("^geom_point\\.points", drawn)))

  # Neither opened the hidden device the recording draws on.
  testthat::expect_identical(maidr:::.maidr_patching_env$.temp_device_id, hidden_before)
  testthat::expect_identical(grDevices::dev.cur(), device)
})

test_that("plot() of a trellis object in a fresh session draws on the default device", {
  skip_if_no_lattice()
  session <- fresh_console_session()

  # Recorded, it opened MAIDR's hidden device and drew there, where nobody
  # sees it.
  expect_emitted(session, "plot_opened_a_device", "TRUE")
  expect_emitted(session, "plot_on_hidden_device", "FALSE")
  expect_emitted(session, "plot_recorded", "FALSE")
  expect_emitted(session, "plot_drawn", "TRUE")
})

test_that("plot() forces only the argument it dispatches on, once, as plain R does", {
  skip_if_no_lattice()

  undo_recording <- use_base_r_recording()
  on.exit(undo_recording(), add = TRUE)

  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device)
      grDevices::dev.off(device)
    },
    add = TRUE
  )
  clear_base_r_device(device)

  # An `x` that fails to evaluate is evaluated once. A check that swallowed
  # the failure left the original, and then the retry, to evaluate it
  # again: every side effect and warning of it, three times.
  evaluated <- 0L
  unreadable <- function() {
    evaluated <<- evaluated + 1L
    warning("cannot open file 'no-such-file.csv'")
    stop("bad first argument")
  }
  warned <- 0L
  testthat::expect_error(
    withCallingHandlers(
      maidr::plot(unreadable()),
      warning = function(w) {
        warned <<- warned + 1L
        invokeRestart("muffleWarning")
      }
    ),
    "bad first argument"
  )
  testthat::expect_identical(evaluated, 1L)
  testthat::expect_identical(warned, 1L)

  # What evaluating it warns of is reported against the reader's call.
  coercion <- testthat::capture_warning(maidr::plot(as.numeric(c("1", "a", "3"))))
  testthat::expect_identical(conditionCall(coercion)[[1L]], quote(maidr::plot))

  # Every other argument is the method's to force, wherever it is written:
  # `panel.first` once the new plot is set up, not on the one before it...
  maidr::plot(1:5)
  usr <- list()
  maidr::plot(panel.first = usr <- c(usr, list(graphics::par("usr"))), 1:10)
  testthat::expect_length(usr, 1L)
  testthat::expect_gt(usr[[1L]][2L], 10)

  # ...and `subset` within `data`, where the formula method evaluates it.
  d <- data.frame(x = 1:10, y = (1:10)^2, g = rep(1:2, 5))
  testthat::expect_error(maidr::plot(subset = g == 1, y ~ x, data = d), NA)

  # A trellis chart given as `x` is lattice's to draw wherever it is written.
  clear_base_r_device(device)
  grid::grid.newpage()
  maidr::plot(newpage = TRUE, x = mtcars_scatter())
  testthat::expect_false(maidr:::has_device_calls(device))
  testthat::expect_true(has_scatter(device))
})

# ==============================================================================
# Options and theme
# ==============================================================================

test_that("maidr.lattice is on unless set otherwise, and is documented", {
  skip_if_no_lattice()
  old <- options(maidr.lattice = NULL, maidr.auto_show = TRUE)
  on.exit(options(old), add = TRUE)

  maidr:::initialize_maidr_options()
  testthat::expect_true(getOption("maidr.lattice"))
  testthat::expect_true(maidr:::is_lattice_enabled())

  # A value set before maidr loads, as in an .Rprofile, is kept.
  options(maidr.lattice = FALSE)
  maidr:::initialize_maidr_options()
  testthat::expect_false(getOption("maidr.lattice"))
  testthat::expect_false(maidr:::is_lattice_enabled())

  # maidr.auto_show is the switch over every system.
  options(maidr.lattice = TRUE, maidr.auto_show = FALSE)
  testthat::expect_false(maidr:::is_lattice_enabled())

  source <- testthat::test_path("..", "..", "R", "maidr_options.R")
  testthat::skip_if_not(
    file.exists(source),
    "the package sources are not beside the tests under R CMD check"
  )
  testthat::expect_true(any(grepl(
    "\\item{\\code{maidr.lattice}}", readLines(source, warn = FALSE),
    fixed = TRUE
  )))
})

test_that("a lattice theme set on the reader's device reaches the chart MAIDR draws", {
  skip_if_no_lattice()

  # lattice keeps a theme per kind of device. MAIDR draws the chart on an
  # off-screen pdf device, and a theme the reader set on the device in front
  # of them -- a png device stands in for it here -- has to come along.
  file <- tempfile(fileext = ".png")
  grDevices::png(file)
  device <- grDevices::dev.cur()
  before <- lattice::trellis.par.get("plot.symbol")
  on.exit(
    {
      grDevices::dev.set(device)
      lattice::trellis.par.set(plot.symbol = before)
      grDevices::dev.off(device)
      unlink(file)
    },
    add = TRUE
  )
  lattice::trellis.par.set(plot.symbol = list(col = "#D55E00"))

  point_colours <- function(p) {
    svg <- chart_svg(saved_html(p))
    layer <- expect_mtcars_scatter(svg)
    unique(xml2::xml_attr(lattice_selector_nodes(svg, layer$selectors), "stroke"))
  }
  testthat::expect_identical(point_colours(mtcars_scatter()), "rgb(213,94,0)")

  # The chart's own settings still come first.
  own <- mtcars_scatter(par.settings = list(plot.symbol = list(col = "#009E73")))
  testthat::expect_identical(point_colours(own), "rgb(0,158,115)")
})
