# `position = "fill"` rescales every category to a common height, so what the
# chart draws is each segment's share of its category and every bar totals 1
# by construction. r-maidr used to classify PositionFill as `stacked_bar`
# alongside PositionStack, which announced those shares as counts and implied
# the categories had equal totals -- the one thing a filled bar is drawn to
# deny.
#
# The value side has its own trap, and it only shows on `geom_bar()`. ggplot2
# keeps the untouched tally in `count` next to the rescaled `ymin`/`ymax`, so
# an extractor that prefers `count` reads the raw numbers off a chart made
# entirely of proportions. `geom_col()` has no `count` column and so was never
# affected, which is why this needs testing on both geoms rather than one.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

# Long-form counts: category "a" splits 10/30, category "b" splits 50/50.
# The two categories have deliberately different totals (40 vs 100) so a
# normalized reading cannot be confused with a stacked one, and "b" is an even
# split so a transposed extraction would still be caught by "a".
COUNTS <- data.frame(
  x = rep(c("a", "b"), each = 2),
  f = rep(c("u", "v"), 2),
  n = c(10, 30, 50, 50),
  stringsAsFactors = FALSE
)

# The same data as one row per observation, for the `stat = "count"` path.
OBSERVATIONS <- data.frame(
  x = rep(COUNTS$x, COUNTS$n),
  f = rep(COUNTS$f, COUNTS$n),
  stringsAsFactors = FALSE
)

# Shares of each category, in the order the segments carry them.
EXPECTED_SHARES <- list(u = c(10 / 40, 50 / 100), v = c(30 / 40, 50 / 100))

# Render through the real pipeline and return the sole emitted layer.
render_layer <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  testthat::expect_length(raw, 1)
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers[[1]]
}

# Series values keyed by their fill label, so assertions do not depend on the
# stacking order the extractor emits.
values_by_fill <- function(layer) {
  out <- list()
  for (series in layer$data) {
    label <- as.character(series[[1]]$z)
    out[[label]] <- vapply(series, function(point) as.numeric(point$y), numeric(1))
  }
  out
}

test_that("geom_col(position = 'fill') is typed as a normalized stacked bar", {
  skip_if_no_render()
  plot <- ggplot2::ggplot(COUNTS, ggplot2::aes(x = x, y = n, fill = f)) +
    ggplot2::geom_col(position = "fill")

  expect_equal(render_layer(plot)$type, "stacked_normalized_bar")
})

test_that("geom_bar(position = 'fill') is typed as a normalized stacked bar", {
  skip_if_no_render()
  plot <- ggplot2::ggplot(OBSERVATIONS, ggplot2::aes(x = x, fill = f)) +
    ggplot2::geom_bar(position = "fill")

  expect_equal(render_layer(plot)$type, "stacked_normalized_bar")
})

test_that("position = 'stack' still reads as a plain stacked bar", {
  skip_if_no_render()
  plot <- ggplot2::ggplot(COUNTS, ggplot2::aes(x = x, y = n, fill = f)) +
    ggplot2::geom_col(position = "stack")

  layer <- render_layer(plot)
  expect_equal(layer$type, "stacked_bar")
  # The counts themselves must be untouched by the normalized branch.
  values <- values_by_fill(layer)
  expect_equal(values$u, c(10, 50))
  expect_equal(values$v, c(30, 50))
})

test_that("a filled geom_col carries shares rather than counts", {
  skip_if_no_render()
  plot <- ggplot2::ggplot(COUNTS, ggplot2::aes(x = x, y = n, fill = f)) +
    ggplot2::geom_col(position = "fill")

  values <- values_by_fill(render_layer(plot))
  expect_equal(values$u, EXPECTED_SHARES$u, tolerance = 1e-8)
  expect_equal(values$v, EXPECTED_SHARES$v, tolerance = 1e-8)
})

test_that("a filled geom_bar carries shares, not the raw count column", {
  skip_if_no_render()
  # The regression this file exists for: `stat_count()` puts the untouched
  # tally in `count`, so preferring it emits 10/30/50/50 for a chart drawn
  # entirely out of proportions.
  plot <- ggplot2::ggplot(OBSERVATIONS, ggplot2::aes(x = x, fill = f)) +
    ggplot2::geom_bar(position = "fill")

  values <- values_by_fill(render_layer(plot))
  expect_equal(values$u, EXPECTED_SHARES$u, tolerance = 1e-8)
  expect_equal(values$v, EXPECTED_SHARES$v, tolerance = 1e-8)
})

test_that("every category of a filled bar totals one", {
  skip_if_no_render()
  # maidr.js derives a running total per category from these values. For a
  # filled bar that total has to come out as 1, because that is the height
  # every bar is drawn to.
  plot <- ggplot2::ggplot(OBSERVATIONS, ggplot2::aes(x = x, fill = f)) +
    ggplot2::geom_bar(position = "fill")

  values <- values_by_fill(render_layer(plot))
  totals <- Reduce(`+`, values)
  expect_equal(totals, rep(1, length(totals)), tolerance = 1e-8)
})

test_that("the ggplot2 factory can build a processor for the new type", {
  factory <- Ggplot2ProcessorFactory$new()

  expect_true("stacked_normalized_bar" %in% factory$get_supported_types())
  processor <- factory$create_processor(
    "stacked_normalized_bar",
    list(type = "stacked_normalized_bar")
  )
  expect_s3_class(processor, "Ggplot2StackedBarProcessor")
})
