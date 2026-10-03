# Several charts to a chunk: R/knitr_figure_map.R.
#
# knitr hands its plot hook a figure's file, never the page drawn, so every
# chart drawn in a knit marks its page, and the hook shows the one chart the
# figure's page carries -- a ggplot2 or lattice chart printed in a loop, each
# Base R chart -- and leaves every other figure as knitr made it. Each test
# knits a document and reads its charts and figures back in page order
# (`figure_sequence()`), as a chart's title and what its layers hold, or as
# the figure's file.

#' The lines of a chunk defining the charts the tests print
chart_setup <- c(
  "```{r charts}",
  "p <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
  "x <- c(1, 2, 2, 3, 3, 3, 4, 4, 5)",
  "fit <- lm(mpg ~ wt, data = mtcars)",
  "```"
)

skip_if_no_figures <- function() {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("lattice")
  testthat::skip_if_not_installed("withr")
}

test_that("every chart a chunk draws is shown in place of its figure, in order", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")

  page <- knit_for(c(
    chart_setup,
    "```{r ggplot}",
    "for (i in 1:3) print(p + ggplot2::ggtitle(paste0('gg-', i)))",
    "```",
    "```{r lattice}",
    "for (i in 1:2) print(lattice::barchart(c(a = 1, b = 2, c = i), main = paste0('lat-', i)))",
    "```",
    "```{r base}",
    "for (i in 2:3) barplot(seq_len(i), main = paste0('base-', i))",
    "barplot(c(3, 5, 2), main = 'bar')",
    "hist(x, main = 'hist')",
    "```",
    "```{r grid}",
    "op <- par(mfrow = c(1, 2))",
    "barplot(1:3, main = 'left')",
    "barplot(3:1, main = 'right')",
    "par(op)",
    "hist(x, main = 'single')",
    "```",
    "```{r mixed}",
    "print(p + ggplot2::ggtitle('mixed-gg'))",
    "barplot(1:4, main = 'mixed-bar')",
    "print(lattice::barchart(c(a = 1, b = 2), main = 'mixed-lat'))",
    "```"
  ), dir)

  testthat::expect_identical(figure_sequence(page), c(
    "gg-1: bar:3", "gg-2: bar:3", "gg-3: bar:3",
    "lat-1: bar:3", "lat-2: bar:3",
    "base-2: bar:2", "base-3: bar:3", "bar: bar:3", "hist: hist:4",
    # One page of two panels is one chart, and par(op) puts back one panel.
    "right: bar:3|bar:3", "single: hist:4",
    "mixed-gg: bar:3", "mixed-bar: bar:4", "mixed-lat: bar:2"
  ))
  # Each chart its own: no id is on the page twice.
  ids <- xml2::xml_attr(xml2::xml_find_all(xml2::read_html(page), "//*[@id]"), "id")
  testthat::expect_false(anyDuplicated(ids) > 0L)
})

test_that("a printed chart is read as it was when it was printed", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")

  # aes() on vectors outside a chart's data is evaluated when the chart is
  # built, and knitr writes the figures once the loop is over, when y holds
  # the last chart's values.
  page <- knit_for(c(
    "```{r lazy}",
    "for (i in 1:2) {",
    "  y <- c(i, 10 * i)",
    "  print(ggplot2::ggplot(mapping = ggplot2::aes(c('a', 'b'), y)) + ggplot2::geom_col())",
    "}",
    "```",
    # Reading the chart says nothing in the document: its warning is the
    # one its drawing gave.
    "```{r missing}",
    "print(ggplot2::ggplot(data.frame(u = c(1, NA, 3), v = 1:3), ggplot2::aes(u, v)) +",
    "  ggplot2::geom_point())",
    "```"
  ), dir)

  values <- lapply(inline_charts(page)[1:2], function(svg) {
    data <- jsonlite::parse_json(xml2::xml_attr(svg, "data-maidr-knitr"))
    points <- data$subplots[[1]][[1]]$layers[[1]]$data
    vapply(points, function(point) as.numeric(point$y), numeric(1))
  })
  testthat::expect_identical(values, list(c(1, 10), c(2, 20)))
  testthat::expect_length(inline_charts(page), 3L)
  testthat::expect_length(gregexpr("Removed 1 row", page, fixed = TRUE)[[1]], 1L)
})

test_that("fig.keep and fig.show pick the figures, and each is the chart it shows", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")
  three <- c(
    "barplot(1:3, main = '%s-bar')",
    "hist(x, main = '%s-hist')",
    "plot(1:3, main = '%s-plot')"
  )

  page <- knit_for(c(
    chart_setup,
    "```{r all, fig.keep = 'all'}",
    "plot(1:3, main = 'all')",
    "abline(h = 2)",
    "```",
    "```{r first, fig.keep = 'first'}", sprintf(three, "first"), "```",
    "```{r last, fig.keep = 'last'}", sprintf(three, "last"), "```",
    "```{r index, fig.keep = c(1, 3)}", sprintf(three, "index"), "```",
    "```{r none, fig.keep = 'none'}", "barplot(1:3, main = 'none')", "```",
    "```{r hold, fig.show = 'hold'}",
    "barplot(1:3, main = 'hold-bar')",
    "cat('hold-text\\n')",
    "print(p + ggplot2::ggtitle('hold-gg'))",
    "```",
    "```{r hide, fig.show = 'hide'}",
    "par(mfrow = c(1, 2))",
    "barplot(1:3, main = 'hidden')",
    "```",
    "```{r after_hide}",
    "plot(1:5, main = 'after-hide')",
    "```",
    "```{r animate, fig.show = 'animate', animation.hook = function(x, options) 'ANIMATION'}",
    "for (i in 1:2) plot(1:3, main = paste0('frame-', i))",
    "```"
  ), dir)

  testthat::expect_identical(figure_sequence(page), c(
    "all: point:3", "all: point:3+line:1",
    "first-bar: bar:3",
    "last-plot: point:3",
    "index-bar: bar:3", "index-plot: point:3",
    "hold-bar: bar:3", "hold-gg: bar:3",
    # The hidden chunk's grid is not this chunk's.
    "after-hide: point:5"
  ))
  testthat::expect_lt(regexpr("## hold-text", page), regexpr('aria-label="hold-bar"', page))
  # An animation is knitr's, made of its figures.
  testthat::expect_match(page, "ANIMATION", fixed = TRUE)
})

test_that("a figure that is not one whole chart stays knitr's figure", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")

  # plot(fit) under par(mfrow = ) warns as maidr reads it.
  page <- suppressWarnings(knit_for(c(
    chart_setup,
    # Something drawn over a chart: an inset, grid's own drawing, lattice's
    # documented way to annotate a panel.
    "```{r inset}",
    "print(p + ggplot2::ggtitle('inset-main'))",
    "print(p, vp = grid::viewport(x = 0.75, y = 0.75, width = 0.4, height = 0.4))",
    "```",
    "```{r note}",
    "print(p + ggplot2::ggtitle('note'))",
    "grid::grid.text('NOTE')",
    "```",
    "```{r focus}",
    "print(lattice::barchart(c(a = 1, b = 2, c = 3), main = 'focus'))",
    "lattice::trellis.focus('panel', 1, 1)",
    "lattice::panel.abline(v = 2.5)",
    "lattice::trellis.unfocus()",
    "```",
    "```{r basenote}",
    "barplot(1:3, main = 'basenote')",
    "grid::grid.text('NOTE')",
    "```",
    # A page composed of several charts.
    "```{r split}",
    "print(lattice::barchart(c(a = 1, b = 2)), split = c(1, 1, 2, 1), more = TRUE)",
    "print(lattice::barchart(c(a = 3, b = 4)), split = c(2, 1, 2, 1))",
    "```",
    # One call drawing several pages, and a chart sharing the last of them.
    "```{r pages}",
    "plot(fit, which = 1:2)",
    "```",
    "```{r shared}",
    "par(mfrow = c(1, 2))",
    "plot(fit, which = 1:3)",
    "barplot(1:3, main = 'after-fit')",
    "```",
    # A chart maidr reads as no data at all, and one it cannot read.
    "```{r empty}",
    "par(mfrow = c(2, 2))",
    "plot(fit)",
    "```",
    "```{r persp}",
    "persp(volcano[1:10, 1:10])",
    "```",
    "```{r after}",
    "barplot(c(9, 8), main = 'after')",
    "```"
  ), dir))

  testthat::expect_identical(figure_sequence(page), c(
    "figure inset-1.svg", "figure note-1.svg", "figure focus-1.svg",
    "figure basenote-1.svg", "figure split-1.svg",
    "figure pages-1.svg", "figure pages-2.svg",
    "figure shared-1.svg", "figure shared-2.svg",
    "figure empty-1.svg", "figure persp-1.svg",
    "after: bar:2"
  ))
})

test_that("the charts of one page are one figure, whatever is drawn elsewhere between them", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")

  # Pages started on other devices between two charts, and a page
  # replayPlot() puts back, are counted as pages the knit drew: the page
  # count the charts' markers carry differs, the page does not.
  page <- knit_for(c(
    chart_setup,
    "```{r elsewhere}",
    "hist(x, main = 'elsewhere', xlim = c(0, 12))",
    "png(tempfile(fileext = '.png')); plot(1:3); invisible(dev.off())",
    "hist(x + 6, add = TRUE)",
    "```",
    "```{r panels}",
    "par(mfrow = c(1, 2))",
    "barplot(1:3, main = 'panel-left')",
    "ggplot2::ggsave(tempfile(fileext = '.png'), p, width = 3, height = 3)",
    "barplot(3:1, main = 'panel-right')",
    "```",
    "```{r putback}",
    "hist(x, main = 'putback', xlim = c(0, 12))",
    "drawn <- recordPlot()",
    "barplot(1:2, main = 'between')",
    "replayPlot(drawn)",
    "hist(x + 6, add = TRUE)",
    "```"
  ), dir)

  testthat::expect_identical(figure_sequence(page), c(
    "elsewhere: hist:4+hist:4",
    "panel-right: bar:3|bar:3",
    "putback: hist:4", "between: bar:2", "putback: hist:4+hist:4"
  ))
})

test_that("a page the chunk replays itself belongs to no figure", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")
  image <- file.path(dir, "image.png")
  grDevices::png(image)
  graphics::plot.new()
  grDevices::dev.off()

  page <- knit_for(c(
    chart_setup,
    "```{r print}",
    "barplot(1:3, main = 'print-bar')",
    "hist(x, main = 'print-hist')",
    "invisible(dev.print(pdf, tempfile()))",
    "```",
    # The composition carries no marker: the page dev.print() replayed after
    # it must not lend it the chart printed next.
    "```{r compose}",
    "print(p, vp = grid::viewport(width = 0.5))",
    "print(p + ggplot2::ggtitle('compose-gg'))",
    "invisible(dev.print(pdf, tempfile()))",
    "```",
    "```{r include}",
    sprintf("knitr::include_graphics(%s)", deparse(image)),
    "barplot(1:4, main = 'include-bar')",
    "invisible(dev.copy(png, tempfile())); invisible(dev.off())",
    "```",
    "```{r replay}",
    "barplot(1:3, main = 'replay-bar')",
    "drawn <- recordPlot()",
    "hist(x, main = 'replay-hist')",
    "replayPlot(drawn)",
    "```"
  ), dir)

  testthat::expect_identical(figure_sequence(page), c(
    "print-bar: bar:3", "print-hist: hist:4",
    "figure compose-1.svg", "compose-gg: bar:3",
    "figure image.png", "include-bar: bar:4",
    # The barplot again, replayed onto a page of its own.
    "replay-bar: bar:3", "replay-hist: hist:4", "replay-bar: bar:3"
  ))
})

test_that("a page replayed by the chunk that installs maidr belongs to no figure", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")

  # maidr_on() installs maidr into the knit again in the middle of the
  # chunk, which knitr runs without maidr's evaluate hook.
  page <- knit_for(c(
    chart_setup,
    "```{r off}",
    "maidr::maidr_off()",
    "```",
    "```{r install}",
    "maidr::maidr_on()",
    "print(p, vp = grid::viewport(width = 0.5))",
    "print(p + ggplot2::ggtitle('install-gg'))",
    "invisible(dev.print(pdf, tempfile()))",
    "```"
  ), dir)

  # The chunk's device was chosen while maidr was off: knitr's png.
  testthat::expect_identical(
    figure_sequence(page),
    c("figure install-1.png", "install-gg: bar:3")
  )
})

test_that("a chunk that stops with an error leaves nothing to the next chunk", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")

  page <- knit_for(c(
    "```{r failing, error = TRUE}",
    "par(mfrow = c(1, 2))",
    "barplot(1:3, main = 'failing')",
    "stop('boom')",
    "```",
    "```{r next}",
    "barplot(c(9, 8), main = 'next')",
    "```"
  ), dir)

  # The page the error left, one panel of two drawn; then the next chunk's
  # chart, on a page of its own.
  testthat::expect_identical(figure_sequence(page), c("failing: bar:3|", "next: bar:2"))
})

test_that("a cached chunk's charts come back from the cache", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")
  chunks <- c(
    chart_setup,
    "```{r cached, cache = TRUE}",
    "for (i in 1:2) print(p + ggplot2::ggtitle(paste0('cached-', i)))",
    "barplot(1:3, main = 'cached-bar')",
    "```"
  )
  expected <- c("cached-1: bar:3", "cached-2: bar:3", "cached-bar: bar:3")

  testthat::expect_identical(figure_sequence(knit_for(chunks, dir)), expected)
  testthat::expect_identical(figure_sequence(knit_for(chunks, dir)), expected)
})

test_that("a chunk that knits a child document keeps its own chart", {
  skip_if_no_figures()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-figures-")

  page <- knit_for(c(
    chart_setup,
    "```{r parent, results = 'asis'}",
    "print(p + ggplot2::ggtitle('parent-gg'))",
    "barplot(1:2, main = 'parent')",
    "child <- c('```{r child}', 'barplot(c(2, 4, 6), main = \"child\")', '```')",
    "cat(knitr::knit_child(text = child, quiet = TRUE))",
    "```"
  ), dir)

  # The child's chunks start afresh on devices of their own, and leave the
  # parent's charts, still to be shown, as they were.
  testthat::expect_identical(
    figure_sequence(page),
    c("parent-gg: bar:3", "parent: bar:2", "child: bar:3")
  )
})

test_that("bookdown labels a chunk's charts as knitr labels its figures", {
  skip_if_no_figures()
  local_knitr_state()
  chunks <- c(
    "```{r bookdown, include = FALSE}",
    "knitr::opts_knit$set(bookdown.internal.label = TRUE)",
    "```",
    "```{r loop, fig.cap = c('First', 'Second')}",
    "for (i in 1:2) barplot(seq_len(i + 1))",
    "```",
    "```{r one, fig.cap = 'Only'}",
    "barplot(1:3)",
    "```",
    "```{r held, fig.cap = 'Held', fig.show = 'hold'}",
    "barplot(1:2)",
    "barplot(1:3)",
    "```",
    # Charts the chunk returns, written by knit_print() as the chunk runs.
    "```{r returned, fig.cap = 'Returned'}",
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(gear))) + ggplot2::geom_bar()",
    "```",
    "```{r alone, fig.cap = 'Alone'}",
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(am))) + ggplot2::geom_bar()",
    "```"
  )
  labels <- function(page) {
    found <- regmatches(page, gregexpr("\\(\\\\?#fig:[^)]+\\)[^<]*", page))[[1]]
    trimws(sub("\\#", "#", found, fixed = TRUE))
  }

  charts <- knit_for(chunks, withr::local_tempdir("maidr-figures-"))
  maidr::maidr_off()
  figures <- knit_for(chunks, withr::local_tempdir("maidr-figures-"))

  testthat::expect_length(inline_charts(charts), 8L)
  # Held to the end of the chunk, two figures are captioned once.
  testthat::expect_identical(labels(charts), c(
    "(#fig:loop-1) First", "(#fig:loop-2) Second", "(#fig:one) Only", "(#fig:held) Held",
    "(#fig:returned-1) Returned", "(#fig:returned-2) Returned", "(#fig:alone) Alone"
  ))
  testthat::expect_identical(gsub(" ", "", labels(charts)), labels(figures))
})

test_that("a chart's marker needs nothing but base R to be replayed", {
  # knitr's cache = 1 and cache = 2 keep a chunk's pages, markers and all,
  # and replay them in later sessions, with another maidr or none.
  grDevices::pdf(NULL)
  device <- grDevices::dev.cur()
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)
  grDevices::dev.control("enable")
  graphics::plot.new()
  token <- maidr:::new_knit_token("b")
  maidr:::mark_knit_page(token, 0L)

  page <- grDevices::recordPlot()
  marker <- page[[1]][[length(page[[1]])]][[2]]
  testthat::expect_identical(marker[[2]]$maidr_token, token)
  testthat::expect_identical(marker[[3]], baseenv())
  names <- setdiff(all.names(marker[[1]]), c("replayed", "maidr_token", "maidr_page"))
  testthat::expect_true(all(vapply(names, exists, logical(1), envir = baseenv())))
  # With no callback set, a replay draws the page and nothing else.
  withr::local_options(maidr.knit.replayed = NULL)
  testthat::expect_no_error(grDevices::replayPlot(page))
})

test_that("a chart's token is unique beyond its R session", {
  first <- maidr:::new_knit_token("o")
  second <- maidr:::new_knit_token("o")
  testthat::expect_false(identical(first, second))
  testthat::expect_true(startsWith(first, "o"))
  # The process id is part of it, as of an inline chart's id prefix.
  testthat::expect_match(first, maidr:::base36_fixed(Sys.getpid(), 5L), fixed = TRUE)
})
