# A ggdist lineribbon is a percentile band.
#
# `stat_lineribbon()` and `geom_lineribbon()` draw nested quantile intervals
# around a median -- a fan chart -- with ggdist's own geom, which matched no
# branch of the adapter: the layer was unread, and an unread layer drops the
# chart to a static image. The core's `percentile_band` trace reads one: at
# each x, the quantiles, entered on the median and walked band by band.
#
# What this side decides is when the ribbons are quantiles. A ribbon of width
# `w` spans the quantiles `(1 - w) / 2` and `(1 + w) / 2` only for a quantile
# interval, and the line is the 0.5 quantile only when it is the median, so a
# mean or a highest-density interval is not claimed; nor is a layer drawing
# several series, which one band cannot hold.

skip_slow_file_on_cran()

skip_unless_ggdist <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("ggdist")
}

draws <- function() {
  set.seed(1)
  d <- data.frame(week = rep(1:6, each = 200))
  d$sales <- stats::rnorm(nrow(d), d$week, d$week / 2)
  d
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


test_that("stat_lineribbon() is read as a percentile band", {
  skip_unless_ggdist()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    ggdist::stat_lineribbon(.width = c(0.5, 0.8, 0.95))

  testthat::expect_identical(detected(plot), "percentile_band")

  result <- processed(plot)
  testthat::expect_identical(result$type, "percentile_band")
  testthat::expect_length(result$data, 6L)
  testthat::expect_equal(
    levels_of(result$data[[1]]),
    c(0.025, 0.1, 0.25, 0.5, 0.75, 0.9, 0.975)
  )
  testthat::expect_equal(
    vapply(result$data, function(p) p$x, numeric(1)), 1:6
  )
})

test_that("the quantiles are the ones ggdist computed", {
  skip_unless_ggdist()

  data <- draws()
  plot <- ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
    ggdist::stat_lineribbon(.width = 0.8)
  first <- processed(plot)$data[[1]]$quantiles
  at_one <- data$sales[data$week == 1]

  testthat::expect_equal(
    vapply(first, function(q) q$value, numeric(1)),
    unname(stats::quantile(at_one, c(0.1, 0.5, 0.9), type = 7)),
    tolerance = 1e-8
  )
})

test_that("a geom_lineribbon() of a median_qi() summary is read from its data", {
  skip_unless_ggdist()
  testthat::skip_if_not_installed("dplyr")

  summary <- draws() |>
    dplyr::group_by(week) |>
    ggdist::median_qi(sales, .width = c(0.5, 0.9))
  plot <- ggplot2::ggplot(
    summary,
    ggplot2::aes(x = week, y = sales, ymin = .lower, ymax = .upper)
  ) + ggdist::geom_lineribbon()

  testthat::expect_identical(detected(plot), "percentile_band")
  result <- processed(plot)
  testthat::expect_equal(
    levels_of(result$data[[1]]),
    c(0.05, 0.25, 0.5, 0.75, 0.95)
  )
})

test_that("a mean, an hdi or several series are not claimed", {
  skip_unless_ggdist()

  data <- draws()
  data$model <- rep(c("a", "b"), length.out = nrow(data))
  fixtures <- list(
    list("a mean", ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
      ggdist::stat_lineribbon(point_interval = ggdist::mean_qi)),
    list("an hdi", ggplot2::ggplot(data, ggplot2::aes(week, sales)) +
      ggdist::stat_lineribbon(point_interval = ggdist::median_hdi)),
    list("two series", ggplot2::ggplot(data,
      ggplot2::aes(week, sales, colour = model)) + ggdist::stat_lineribbon())
  )
  for (fixture in fixtures) {
    testthat::expect_false(
      identical(detected(fixture[[2]]), "percentile_band"),
      label = fixture[[1]]
    )
  }
})

test_that("a summary without the columns that say what it is is not claimed", {
  skip_unless_ggdist()

  frame <- data.frame(
    week = 1:3, mid = c(1, 2, 3), lo = c(0, 1, 2), hi = c(2, 3, 4)
  )
  plot <- ggplot2::ggplot(frame, ggplot2::aes(week, mid, ymin = lo, ymax = hi)) +
    ggdist::geom_lineribbon()
  testthat::expect_false(identical(detected(plot), "percentile_band"))
})

test_that("one selector per band, outermost first, then the median line", {
  skip_unless_ggdist()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    ggdist::stat_lineribbon(.width = c(0.5, 0.8, 0.95))
  selectors <- unlist(processed(plot)$selectors)

  testthat::expect_length(selectors, 4L)
  testthat::expect_true(all(grepl(" polygon$", selectors[1:3])))
  testthat::expect_match(selectors[[4]], " polyline$")

  # Outermost first: ggdist draws its widest ribbon first, and the polygon
  # drawn first is the one whose fill is the widest band's.
  built <- ggplot2::ggplot_build(plot)$data[[1]]
  fill_of_widest <- unique(built$fill[built$.width == 0.95])
  tree <- maidr:::Ggplot2PercentileBandLayerProcessor$new(
    list(index = 1, type = "percentile_band")
  )$find_layer_grob_tree(plot, ggplot2::ggplotGrob(plot))
  first_polygon <- NULL
  walk <- function(g) {
    if (!is.null(first_polygon)) return(invisible())
    if (!is.null(g$name) && grepl("^GRID\\.polygon\\.", g$name)) {
      first_polygon <<- g
    }
    if (inherits(g, "gTree")) for (child in g$children) walk(child)
  }
  walk(tree)
  testthat::expect_identical(
    grDevices::col2rgb(first_polygon$gp$fill),
    grDevices::col2rgb(fill_of_widest)
  )
})

test_that("a chart renders with the band and its selectors resolve", {
  skip_if_no_render()
  skip_unless_ggdist()

  plot <- ggplot2::ggplot(draws(), ggplot2::aes(week, sales)) +
    ggdist::stat_lineribbon(.width = c(0.5, 0.8)) +
    ggplot2::scale_fill_brewer() +
    ggplot2::labs(x = "Week", y = "Sales")

  html <- rendered(plot)
  testthat::expect_false(fell_back(html))
  layer <- layers_from(html)[[1]]
  testthat::expect_identical(layer$type, "percentile_band")
  testthat::expect_length(layer$data, 6L)
  testthat::expect_length(layer$selectors, 3L)
  for (selector in unlist(layer$selectors)) {
    id <- gsub("\\\\", "", sub("^#", "", strsplit(selector, " ")[[1]][1]))
    testthat::expect_true(grepl(paste0('id="', id, '"'), html, fixed = TRUE))
  }
})

test_that("the processor is registered for the type", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  testthat::expect_true("percentile_band" %in% factory$get_supported_types())
})
