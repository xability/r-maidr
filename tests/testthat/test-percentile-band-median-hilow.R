# A `median_hilow` ribbon is a percentile band.
#
# `stat_summary(geom = "ribbon", fun.data = median_hilow)` draws, at each x,
# the quantiles `(1 - w) / 2` and `(1 + w) / 2` of the y values there, `w`
# being `fun.args$conf.int` (0.95 when unset), and computes their median.
# It read as an `error_bar`, which announces two bounds with nothing to say
# what share of the data lies between them. The levels are known from the
# layer itself, so it is the core's `percentile_band`: one band, entered on
# the median. A `stat_summary()` median line drawn on the same rows is that
# median, and the two layers are read as one.

skip_slow_file_on_cran()

skip_unless_hilow <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("Hmisc")
}

draws <- function() {
  set.seed(1)
  d <- data.frame(week = rep(1:6, each = 40))
  d$sales <- stats::rnorm(nrow(d), d$week, d$week / 2)
  d$store <- rep(c("a", "b"), length.out = nrow(d))
  d
}

hilow_ribbon <- function(...) {
  ggplot2::stat_summary(geom = "ribbon", fun.data = ggplot2::median_hilow, ...)
}

median_line <- function(...) {
  ggplot2::stat_summary(geom = "line", fun = stats::median, ...)
}

detected <- function(plot, index = 1) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}

processed <- function(plot, index = 1) {
  built <- ggplot2::ggplot_build(plot)
  processor <- maidr:::Ggplot2PercentileBandLayerProcessor$new(
    list(index = index, type = "percentile_band")
  )
  processor$process(plot, built$layout, built, ggplot2::ggplotGrob(plot))
}

levels_of <- function(point) {
  vapply(point$quantiles, function(q) q$level, numeric(1))
}

values_of <- function(point) {
  vapply(point$quantiles, function(q) q$value, numeric(1))
}


test_that("a median_hilow ribbon is read as a percentile band", {
  skip_unless_hilow()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    hilow_ribbon(fun.args = list(conf.int = 0.5))

  testthat::expect_identical(detected(plot), "percentile_band")
  result <- processed(plot)
  testthat::expect_identical(result$type, "percentile_band")
  testthat::expect_length(result$data, 6L)
  testthat::expect_equal(levels_of(result$data[[1]]), c(0.25, 0.5, 0.75))
  testthat::expect_equal(
    vapply(result$data, function(p) p$x, numeric(1)), 1:6
  )
})

test_that("the width defaults to 0.95 and the name of the function reads too", {
  skip_unless_hilow()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    ggplot2::stat_summary(geom = "ribbon", fun.data = "median_hilow")

  testthat::expect_identical(detected(plot), "percentile_band")
  testthat::expect_equal(
    levels_of(processed(plot)$data[[1]]), c(0.025, 0.5, 0.975)
  )
})

test_that("the quantiles and the median are the ones the stat computed", {
  skip_unless_hilow()

  data <- draws()
  plot <- ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
    hilow_ribbon(fun.args = list(conf.int = 0.8))
  at_one <- data$sales[data$week == 1]

  # The built ribbon's `y` is not the median -- `GeomRibbon` overwrites it
  # with `ymin` -- so this is what says the median was recovered.
  testthat::expect_equal(
    values_of(processed(plot)$data[[1]]),
    unname(stats::quantile(at_one, c(0.1, 0.5, 0.9))),
    tolerance = 1e-8
  )
})

test_that("a median line on the same rows is folded into the band", {
  skip_unless_hilow()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    hilow_ribbon(fun.args = list(conf.int = 0.5), alpha = 0.3) +
    median_line()

  testthat::expect_identical(detected(plot, 1), "percentile_band")
  testthat::expect_identical(detected(plot, 2), "skip")

  selectors <- unlist(processed(plot)$selectors)
  testthat::expect_length(selectors, 2L)
  testthat::expect_match(selectors[[1]], " polygon$")
  testthat::expect_match(selectors[[2]], "^#GRID\\\\\\.polyline\\\\\\.")
})

test_that("a median_hilow summary drawn as a line is a median line too", {
  skip_unless_hilow()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    hilow_ribbon() +
    ggplot2::stat_summary(geom = "line", fun.data = "median_hilow")

  testthat::expect_identical(detected(plot, 2), "skip")
  testthat::expect_length(unlist(processed(plot)$selectors), 2L)
})

test_that("without a median line the band names only itself", {
  skip_unless_hilow()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    hilow_ribbon()
  selectors <- unlist(processed(plot)$selectors)
  testthat::expect_length(selectors, 1L)
  testthat::expect_match(selectors[[1]], " polygon$")
})

test_that("a line that is not the band's median stays a line", {
  skip_unless_hilow()

  data <- draws()
  fixtures <- list(
    list("a mean", ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
      hilow_ribbon() + ggplot2::stat_summary(geom = "line", fun = mean)),
    list("another y", ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
      hilow_ribbon() +
      median_line(ggplot2::aes(y = sales * 2))),
    list("a plain line", ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
      hilow_ribbon() + ggplot2::geom_line(stat = "summary", fun = mean)),
    list("two median lines", ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
      hilow_ribbon() + median_line() + median_line())
  )
  for (fixture in fixtures) {
    testthat::expect_identical(detected(fixture[[2]], 2), "line", label = fixture[[1]])
  }
})

test_that("a line drawn on two bands' median is read as a line", {
  skip_unless_hilow()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    hilow_ribbon(fun.args = list(conf.int = 0.9)) +
    hilow_ribbon(fun.args = list(conf.int = 0.5)) +
    median_line()

  testthat::expect_identical(detected(plot, 1), "percentile_band")
  testthat::expect_identical(detected(plot, 2), "percentile_band")
  testthat::expect_identical(detected(plot, 3), "line")
})

test_that("other summaries, several series or a flipped ribbon are not claimed", {
  skip_unless_hilow()

  data <- draws()
  fixtures <- list(
    list("mean_se", ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
      ggplot2::stat_summary(geom = "ribbon", fun.data = ggplot2::mean_se)),
    list("an unnamed argument", ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
      hilow_ribbon(fun.args = list(0.5))),
    list("two series", ggplot2::ggplot(data,
      ggplot2::aes(week, sales, fill = store)) + hilow_ribbon()),
    list("flipped", ggplot2::ggplot(data, ggplot2::aes(sales, week)) +
      hilow_ribbon(orientation = "y"))
  )
  for (fixture in fixtures) {
    testthat::expect_false(
      identical(detected(fixture[[2]]), "percentile_band"),
      label = fixture[[1]]
    )
  }
})

test_that("a median_hilow pointrange keeps its error bar reading", {
  skip_unless_hilow()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(factor(week), sales)) +
    ggplot2::stat_summary(fun.data = ggplot2::median_hilow, geom = "pointrange")
  testthat::expect_identical(detected(plot), "error_bar")
})

test_that("an older bundle keeps the reading the ribbon and line had", {
  skip_unless_hilow()
  testthat::local_mocked_bindings(percentile_band_trace_available = function() FALSE)

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    hilow_ribbon() + median_line()
  testthat::expect_identical(detected(plot, 1), "error_bar")
  testthat::expect_identical(detected(plot, 2), "line")
})

test_that("each panel of a facet reads its own band", {
  skip_unless_hilow()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    hilow_ribbon() + median_line() +
    ggplot2::facet_wrap(~store)
  built <- ggplot2::ggplot_build(plot)
  processor <- maidr:::Ggplot2PercentileBandLayerProcessor$new(
    list(index = 1, type = "percentile_band")
  )
  data <- draws()
  for (panel in 1:2) {
    result <- processor$process(plot, built$layout, built, panel_id = panel)
    at_one <- data$sales[data$week == 1 & data$store == c("a", "b")[panel]]
    testthat::expect_length(result$data, 6L)
    testthat::expect_equal(
      values_of(result$data[[1]]),
      unname(stats::quantile(at_one, c(0.025, 0.5, 0.975))),
      tolerance = 1e-8
    )
  }
})

test_that("a chart renders with the band and its selectors resolve", {
  skip_if_no_render()
  skip_unless_hilow()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    hilow_ribbon(fun.args = list(conf.int = 0.5), alpha = 0.3) +
    median_line() +
    ggplot2::geom_line(ggplot2::aes(y = week)) +
    ggplot2::labs(x = "Week", y = "Sales")

  html <- rendered(plot)
  testthat::expect_false(fell_back(html))
  layers <- layers_from(html)
  testthat::expect_identical(
    vapply(layers, function(l) l$type, character(1)),
    c("percentile_band", "line")
  )
  testthat::expect_length(layers[[1]]$data, 6L)
  testthat::expect_length(layers[[1]]$selectors, 2L)
  ids <- vapply(c(unlist(layers[[1]]$selectors), unlist(layers[[2]]$selectors)),
    function(selector) {
      gsub("\\\\", "", sub("^#", "", strsplit(selector, " ")[[1]][1]))
    }, character(1))
  for (id in ids) {
    testthat::expect_true(grepl(paste0('id="', id, '"'), html, fixed = TRUE))
  }
  # The plain line after the folded one names its own polyline, not the
  # median's: the folded line still counts among the drawn polylines.
  testthat::expect_false(identical(ids[[2]], ids[[3]]))
})
