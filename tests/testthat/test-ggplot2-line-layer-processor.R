# Comprehensive tests for Ggplot2LineLayerProcessor
# Testing single line, multiline, faceted plots, selector generation

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2LineLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2LineLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("Ggplot2LineLayerProcessor extract_data() works with single line", {
  # Create simple line plot
  df <- data.frame(x = 1:5, y = c(2, 4, 6, 8, 10))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1) # Single line series
  testthat::expect_equal(length(data[[1]]), 5) # 5 points

  # Check first point structure
  testthat::expect_equal(data[[1]][[1]]$x, "1")
  testthat::expect_equal(data[[1]][[1]]$y, 2)
})

test_that("Ggplot2LineLayerProcessor extract_data() works with multiline", {
  # Create multiline plot
  df <- data.frame(
    x = rep(1:5, 2),
    y = c(1, 2, 3, 4, 5, 5, 4, 3, 2, 1),
    group = rep(c("A", "B"), each = 5)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, color = group)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 2) # Two line series
  testthat::expect_equal(length(data[[1]]), 5) # 5 points per series

  # Check z field exists (group name)
  testthat::expect_true("z" %in% names(data[[1]][[1]]))
  testthat::expect_equal(data[[1]][[1]]$z, "A")
  testthat::expect_equal(data[[2]][[1]]$z, "B")
})

test_that("Ggplot2LineLayerProcessor process() returns correct structure", {
  df <- data.frame(x = 1:3, y = c(2, 4, 6))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::labs(title = "Test Line", x = "X Axis", y = "Y Axis")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  layout <- list(
    title = "Test Line",
    axes = list(x = "X Axis", y = "Y Axis")
  )

  # Process with NULL gt (skip selector generation for unit test)
  result <- processor$process(p, layout, NULL, NULL, NULL, NULL, NULL, NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$title, "Test Line")
  testthat::expect_equal(result$axes$x$label, "X Axis")
  testthat::expect_equal(result$axes$y$label, "Y Axis")
  testthat::expect_equal(length(result$data), 1)
  testthat::expect_equal(length(result$data[[1]]), 3)
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("Ggplot2LineLayerProcessor handles NULL built parameter", {
  df <- data.frame(x = 1:3, y = c(1, 2, 3))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  # Should build plot internally
  data <- processor$extract_data(p, built = NULL)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 3)
})

test_that("Ggplot2LineLayerProcessor handles single point line", {
  df <- data.frame(x = 1, y = 5)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_equal(length(data[[1]]), 1)
  # Reads x directly from the original plot$data column (integer 1)
  # rather than ggplot2's scale-formatted decimal label.
  testthat::expect_equal(data[[1]][[1]]$x, "1")
  testthat::expect_equal(data[[1]][[1]]$y, 5)
})

test_that("Ggplot2LineLayerProcessor handles panel filtering", {
  # Create faceted plot
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6),
    facet = rep(c("A", "B"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~facet)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)

  # Extract data for panel 1
  data_panel1 <- processor$extract_data(p, built, panel_id = 1)

  testthat::expect_type(data_panel1, "list")
  testthat::expect_equal(length(data_panel1), 1)
  testthat::expect_equal(length(data_panel1[[1]]), 3)
})

test_that("Ggplot2LineLayerProcessor handles group -1 (default)", {
  # Single line with default group = -1 should be treated as single line
  df <- data.frame(x = 1:4, y = c(2, 4, 3, 5))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  # Should return single series (not multiline)
  testthat::expect_equal(length(data), 1)
  # First point should not have 'fill' field
  testthat::expect_false("z" %in% names(data[[1]][[1]]))
})

# ==============================================================================
# Tier 3: Integration Tests
# ==============================================================================

test_that("Ggplot2LineLayerProcessor extract_layer_axes() works", {
  df <- data.frame(x = 1:3, y = c(5, 10, 15))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::labs(x = "Time", y = "Value")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  layout <- list(axes = list(x = "Time", y = "Value"))
  axes <- processor$extract_layer_axes(p, layout)

  testthat::expect_type(axes, "list")
  testthat::expect_equal(axes$x$label, "Time")
  testthat::expect_equal(axes$y$label, "Value")
})

test_that("Ggplot2LineLayerProcessor needs_reordering() returns FALSE", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  testthat::expect_false(processor$needs_reordering())
})

test_that("Ggplot2LineLayerProcessor get_group_column() finds colour mapping", {
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6),
    cat = rep(c("X", "Y"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, colour = cat)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  group_col <- processor$get_group_column(p)

  testthat::expect_equal(group_col, "cat")
})

test_that("Ggplot2LineLayerProcessor get_group_column() finds color mapping", {
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6),
    cat = rep(c("X", "Y"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, color = cat)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  group_col <- processor$get_group_column(p)

  testthat::expect_equal(group_col, "cat")
})

test_that("Ggplot2LineLayerProcessor get_group_column() defaults to 'group'", {
  df <- data.frame(x = 1:3, y = c(1, 2, 3))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  group_col <- processor$get_group_column(p)

  testthat::expect_equal(group_col, "group")
})

# ==============================================================================
# Tier 4: Line-Specific Logic
# ==============================================================================

test_that("Ggplot2LineLayerProcessor extract_single_line_data() returns correct structure", {
  df <- data.frame(x = 1:4, y = c(10, 20, 15, 25))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  layer_data <- built$data[[1]]

  result <- processor$extract_single_line_data(layer_data)

  testthat::expect_equal(length(result), 1) # Single series
  testthat::expect_equal(length(result[[1]]), 4) # 4 points

  # Check structure of first point
  testthat::expect_true("x" %in% names(result[[1]][[1]]))
  testthat::expect_true("y" %in% names(result[[1]][[1]]))
  testthat::expect_false("z" %in% names(result[[1]][[1]])) # No z for single line
})

test_that("Ggplot2LineLayerProcessor extract_multiline_data() handles multiple groups", {
  df <- data.frame(
    x = rep(1:3, 3),
    y = 1:9,
    series = rep(c("A", "B", "C"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, color = series)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  layer_data <- built$data[[1]]

  result <- processor$extract_multiline_data(layer_data, p)

  testthat::expect_equal(length(result), 3) # Three series
  testthat::expect_equal(length(result[[1]]), 3) # 3 points per series

  # Check fill field contains series names
  testthat::expect_equal(result[[1]][[1]]$z, "A")
  testthat::expect_equal(result[[2]][[1]]$z, "B")
  testthat::expect_equal(result[[3]][[1]]$z, "C")
})

test_that("Ggplot2LineLayerProcessor multiline fallback to group numbers", {
  # Create plot without explicit grouping column in data
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line(ggplot2::aes(group = rep(c(1, 2), each = 3)))

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  layer_data <- built$data[[1]]

  result <- processor$extract_multiline_data(layer_data, p)

  testthat::expect_equal(length(result), 2)
  # Should use fallback "Series N" naming
  testthat::expect_match(result[[1]][[1]]$z, "Series")
})

test_that("Ggplot2LineLayerProcessor handles NULL gt in generate_selectors", {
  df <- data.frame(x = 1:3, y = c(1, 2, 3))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  # NULL gt should still work (will build grob internally)
  selectors <- processor$generate_selectors(p, gt = NULL)

  testthat::expect_type(selectors, "list")
  # Should have at least one selector
  testthat::expect_true(length(selectors) > 0)
})

test_that("Ggplot2LineLayerProcessor generate_multiline_selectors() creates correct format", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  selectors <- processor$generate_multiline_selectors("61", 3)

  testthat::expect_equal(length(selectors), 3)
  testthat::expect_match(selectors[[1]], "#GRID\\\\.polyline\\\\.61\\\\.1\\\\.1")
  testthat::expect_match(selectors[[2]], "#GRID\\\\.polyline\\\\.61\\\\.1\\\\.2")
  testthat::expect_match(selectors[[3]], "#GRID\\\\.polyline\\\\.61\\\\.1\\\\.3")
})

test_that("Ggplot2LineLayerProcessor generate_single_line_selector() creates correct format", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  selector <- processor$generate_single_line_selector("42")

  testthat::expect_equal(length(selector), 1)
  testthat::expect_match(selector[[1]], "#GRID\\\\.polyline\\\\.42\\\\.1\\\\.1")
})

test_that("Ggplot2LineLayerProcessor handles faceted plot with grob_id", {
  df <- data.frame(
    x = rep(1:3, 2),
    y = c(1, 2, 3, 4, 5, 6),
    facet = rep(c("A", "B"), each = 3)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~facet)

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  # Faceted plots use grob_id parameter
  selectors <- processor$generate_selectors(p, gt = NULL, grob_id = "GRID.polyline.100")

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
  testthat::expect_match(selectors[[1]], "#GRID\\\\.polyline\\\\.100\\\\.1\\\\.1")
})

test_that("Ggplot2LineLayerProcessor x values converted to character", {
  df <- data.frame(x = c(10, 20, 30), y = c(1, 2, 3))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  # x values should be character strings
  testthat::expect_type(data[[1]][[1]]$x, "character")
  testthat::expect_equal(data[[1]][[1]]$x, "10")
  testthat::expect_equal(data[[1]][[2]]$x, "20")
})

test_that("Ggplot2LineLayerProcessor multiline detection works correctly", {
  # Single line (group = -1)
  df_single <- data.frame(x = 1:3, y = c(1, 2, 3))
  p_single <- ggplot2::ggplot(df_single, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  data_single <- processor$extract_data(p_single)
  testthat::expect_false("z" %in% names(data_single[[1]][[1]]))

  # Multiline (multiple groups)
  df_multi <- data.frame(
    x = rep(1:3, 2),
    y = 1:6,
    g = rep(c("A", "B"), each = 3)
  )
  p_multi <- ggplot2::ggplot(df_multi, ggplot2::aes(x = x, y = y, color = g)) +
    ggplot2::geom_line()

  data_multi <- processor$extract_data(p_multi)
  testthat::expect_true("z" %in% names(data_multi[[1]][[1]]))
  testthat::expect_equal(length(data_multi), 2)
})

test_that("Ggplot2LineLayerProcessor extracts all metadata correctly", {
  df <- data.frame(x = 1:5, y = c(10, 20, 15, 25, 30))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::labs(title = "Complete Line", x = "X Values", y = "Y Values")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)

  layout <- list(
    title = "Complete Line",
    axes = list(x = "X Values", y = "Y Values")
  )
  result <- processor$process(p, layout, NULL, NULL, NULL, NULL, NULL, NULL)

  # Test data extraction
  testthat::expect_equal(length(result$data), 1)
  testthat::expect_equal(length(result$data[[1]]), 5)

  # Test title
  testthat::expect_equal(result$title, "Complete Line")

  # Test axes
  testthat::expect_equal(result$axes$x$label, "X Values")
  testthat::expect_equal(result$axes$y$label, "Y Values")
})

# Selector tests with grob tree skipped - tested at orchestrator level

# ==============================================================================
# Tier 5: Date / POSIXct x-axis, NA y handling (multiline bug fixes)
# ==============================================================================

test_that("Ggplot2LineLayerProcessor emits ISO date strings for Date x-axis", {
  df <- data.frame(
    date = seq(as.Date("2024-01-02"), by = "day", length.out = 5),
    y = c(1, 2, 3, 4, 5)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = date, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)
  data <- processor$extract_data(p)

  testthat::expect_equal(length(data), 1L)
  testthat::expect_equal(length(data[[1]]), 5L)
  for (pt in data[[1]]) {
    testthat::expect_match(pt$x, "^\\d{4}-\\d{2}-\\d{2}$")
  }
  testthat::expect_equal(data[[1]][[1]]$x, "2024-01-02")
})

test_that("Ggplot2LineLayerProcessor emits ISO date strings for POSIXct x-axis", {
  df <- data.frame(
    when = as.POSIXct("2024-01-02 09:30:00", tz = "UTC") + (0:4) * 3600,
    y = c(1, 2, 3, 4, 5)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = when, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)
  data <- processor$extract_data(p)

  testthat::expect_equal(length(data[[1]]), 5L)
  # POSIXct format() returns timestamp string starting with the date
  testthat::expect_match(data[[1]][[1]]$x, "^2024-01-02")
})

test_that("Ggplot2LineLayerProcessor drops NA y-rows (single line)", {
  # NA y rows are dropped so that emitted data length matches the rendered
  # gridSVG polyline's `points` attribute length. Otherwise the MAIDR JS
  # frontend's polyline-path-parsing path maps row[i] to coord[i] and is
  # shifted by the count of leading NAs.
  df <- data.frame(x = 1:5, y = c(NA, 2, 3, NA, 5))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)
  data <- processor$extract_data(p)

  testthat::expect_equal(length(data[[1]]), 3L)
  testthat::expect_equal(data[[1]][[1]]$y, 2)
  testthat::expect_equal(data[[1]][[2]]$y, 3)
  testthat::expect_equal(data[[1]][[3]]$y, 5)
  for (pt in data[[1]]) {
    testthat::expect_false(is.na(pt$y))
  }
})

test_that("Ggplot2LineLayerProcessor drops NA y-rows in multiline series", {
  df <- data.frame(
    x = rep(1:4, 2),
    y = c(NA, 2, NA, 4, 1, NA, 3, NA),
    g = rep(c("A", "B"), each = 4)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, color = g)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)
  data <- processor$extract_data(p)

  testthat::expect_equal(length(data), 2L)
  # Series A had NAs at positions 1 and 3 -> only 2 surviving points.
  testthat::expect_equal(length(data[[1]]), 2L)
  testthat::expect_equal(data[[1]][[1]]$y, 2)
  testthat::expect_equal(data[[1]][[2]]$y, 4)
  # Series B had NAs at positions 2 and 4 -> only 2 surviving points.
  testthat::expect_equal(length(data[[2]]), 2L)
  testthat::expect_equal(data[[2]][[1]]$y, 1)
  testthat::expect_equal(data[[2]][[2]]$y, 3)
  for (series in data) for (pt in series) {
    testthat::expect_false(is.na(pt$y))
  }
})

test_that("Ggplot2LineLayerProcessor data length matches polyline points (SMA case)", {
  # Mirrors the candlestick + geom_ma scenario: a moving-average overlay's
  # warm-up period contributes leading NA y values. The emitted data length
  # per series must equal the rendered polyline's coordinate count so the
  # MAIDR JS highlight-to-point mapping aligns.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(1:10, 2),
    # Series A: 3 leading NAs (e.g. SMA-4); Series B: 5 leading NAs
    y = c(rep(NA_real_, 3), 4:10, rep(NA_real_, 5), 6:10),
    g = rep(c("A", "B"), each = 10)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, color = g)) +
    ggplot2::geom_line()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2LineLayerProcessor$new(layer_info)
  data <- processor$extract_data(p)

  testthat::expect_equal(length(data[[1]]), 7L) # 10 - 3 leading NA
  testthat::expect_equal(length(data[[2]]), 5L) # 10 - 5 leading NA
})

test_that("merge_line_layers dedupes selectors to match series count", {
  # Two input line layers, each with 1 series and the same 2 selectors (the
  # symptom of the panel-discovery path returning all panel polylines per
  # layer). After merge: 2 data series and exactly 2 unique selectors.
  layer_a <- list(
    id = "a", type = "line", title = "", axes = NULL,
    data = list(list(list(x = "1", y = 1))),
    selectors = list("#sel.A", "#sel.B")
  )
  layer_b <- list(
    id = "b", type = "line", title = "", axes = NULL,
    data = list(list(list(x = "1", y = 2))),
    selectors = list("#sel.A", "#sel.B")
  )
  merged <- maidr:::merge_line_layers(list(layer_a, layer_b))

  testthat::expect_equal(merged$type, "line")
  testthat::expect_equal(length(merged$data), 2L)
  testthat::expect_equal(length(merged$selectors), 2L)
  testthat::expect_equal(merged$selectors[[1]], "#sel.A")
  testthat::expect_equal(merged$selectors[[2]], "#sel.B")
})

# ==============================================================================
# Legend title -> z axis label (issue #27)
# ==============================================================================

# A grouped line layer emits a per-series `z` value. MAIDR announces it as
# "<z label> is <z value>", so without a z label the frontend substitutes the
# generic word "Group" and the legend title the plot shows is lost.

two_series_df <- function() {
  data.frame(
    x = rep(1:5, 2),
    y = c(1, 2, 3, 4, 5, 5, 4, 3, 2, 1),
    series = rep(c("A", "B"), each = 5)
  )
}

process_line_axes <- function(plot) {
  processor <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))
  layout <- list(title = "", axes = list(x = "x", y = "y"))
  result <- processor$process(plot, layout, ggplot2::ggplot_build(plot))
  maidr:::validate_axes(result$axes, "line layer")
  result$axes
}

test_that("multiline z label comes from labs(colour = ...)", {
  p <- ggplot2::ggplot(
    two_series_df(),
    ggplot2::aes(x = x, y = y, colour = series)
  ) +
    ggplot2::geom_line() +
    ggplot2::labs(colour = "Cohort")

  axes <- process_line_axes(p)

  testthat::expect_equal(axes$z$label, "Cohort")
})

test_that("multiline z label honours the American labs(color = ...) spelling", {
  p <- ggplot2::ggplot(
    two_series_df(),
    ggplot2::aes(x = x, y = y, color = series)
  ) +
    ggplot2::geom_line() +
    ggplot2::labs(color = "Cohort")

  axes <- process_line_axes(p)

  testthat::expect_equal(axes$z$label, "Cohort")
})

test_that("multiline z label falls back to the mapped column name", {
  p <- ggplot2::ggplot(
    two_series_df(),
    ggplot2::aes(x = x, y = y, colour = series)
  ) +
    ggplot2::geom_line()

  axes <- process_line_axes(p)

  testthat::expect_equal(axes$z$label, "series")
})

test_that("multiline z label reads a layer-level colour mapping", {
  p <- ggplot2::ggplot(two_series_df(), ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line(ggplot2::aes(colour = series)) +
    ggplot2::labs(colour = "Cohort")

  axes <- process_line_axes(p)

  testthat::expect_equal(axes$z$label, "Cohort")
})

test_that("single line emits no z label", {
  p <- ggplot2::ggplot(
    data.frame(x = 1:5, y = c(2, 4, 6, 8, 10)),
    ggplot2::aes(x = x, y = y)
  ) +
    ggplot2::geom_line()

  axes <- process_line_axes(p)

  testthat::expect_null(axes$z)
})

test_that("labs(colour = ...) on an ungrouped line invents no z label", {
  # ggplot2 records a labs() title even for an aesthetic the plot never maps,
  # so the lookup has to be gated on the layer actually being split into
  # series -- otherwise MAIDR would announce a legend that is not drawn.
  p <- ggplot2::ggplot(
    data.frame(x = 1:5, y = c(2, 4, 6, 8, 10)),
    ggplot2::aes(x = x, y = y)
  ) +
    ggplot2::geom_line() +
    ggplot2::labs(colour = "Not a legend")

  # ggplot2 emits "Ignoring unknown labels" while building this plot.
  axes <- suppressMessages(suppressWarnings(process_line_axes(p)))

  testthat::expect_null(axes$z)
})

test_that("a line grouped by aes(group = ...) emits no z label", {
  # aes(group = ) draws no legend, so there is no title to announce.
  p <- ggplot2::ggplot(
    two_series_df(),
    ggplot2::aes(x = x, y = y, group = series)
  ) +
    ggplot2::geom_line()

  axes <- process_line_axes(p)

  testthat::expect_null(axes$z)
})

test_that("multiline z label survives the full render pipeline", {
  testthat::skip_if_not_installed("jsonlite")

  p <- ggplot2::ggplot(
    two_series_df(),
    ggplot2::aes(x = x, y = y, colour = series)
  ) +
    ggplot2::geom_line() +
    ggplot2::labs(colour = "Cohort")

  file <- tempfile(fileext = ".html")

  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(p, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(
    html, gregexpr('maidr-data="([^"]*)"', html, perl = TRUE)
  )[[1]]
  testthat::expect_gt(length(raw), 0)

  json <- sub('"$', "", sub('^maidr-data="', "", raw[1]))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)
  payload <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  layer <- payload$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_equal(layer$type, "line")
  testthat::expect_equal(layer$axes$z$label, "Cohort")
  # The label names the per-series z values the layer already emits.
  testthat::expect_equal(layer$data[[1]][[1]]$z, "A")
  testthat::expect_equal(layer$data[[2]][[1]]$z, "B")
})

# ==============================================================================
# One selector per series when another layer also draws polylines (issue #95)
# ==============================================================================

# A grouped `geom_line()` draws ALL of its curves as ONE polyline grob that
# gridSVG splits into `GRID.polyline.N.1.1`, `.1.2`, `.1.3`; a `geom_smooth()`
# beside it contributes further grobs of its own. Indexing the flat panel-wide
# polyline list by this layer's position among line layers therefore returned a
# single selector for a three-curve layer. The frontend's multiline trace opens
# `mapToSvgElements(n)` with `if (!n || n.length !== this.lineValues.length)
# return null`, so the mismatch left `highlightValues` null and the whole line
# layer lost its highlight -- it was not merely aimed at the wrong curve.

grouped_line_df <- function() {
  data.frame(
    x = rep(1:8, 3),
    g = factor(rep(c("g1", "g2", "g3"), each = 8)),
    y = c(1:8, 10 + 1:8 * 0.5, 20 - 1:8 * 0.4)
  )
}

line_layer_payload <- function(plot, layer_index = 1) {
  processor <- maidr:::Ggplot2LineLayerProcessor$new(list(index = layer_index))
  built <- ggplot2::ggplot_build(plot)
  gt <- ggplot2::ggplot_gtable(built)
  processor$process(plot, built$layout, built, gt)
}

# Selectors address gridSVG ids, which carry grid's session-wide grob counter,
# so assert on the SHAPE (one per series, all distinct, all sharing this
# layer's own base id) rather than on literal numbers.
expect_one_selector_per_series <- function(result) {
  selectors <- unlist(result$selectors, use.names = FALSE)
  testthat::expect_equal(length(selectors), length(result$data))
  testthat::expect_equal(length(unique(selectors)), length(result$data))
  for (selector in selectors) {
    testthat::expect_match(selector, "^#GRID\\\\\\.polyline\\\\\\.\\d+\\\\\\.1\\\\\\.\\d+$")
  }
  selectors
}

test_that("grouped line beside geom_smooth(se = FALSE) emits one selector per series", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(grouped_line_df(), ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_line() +
    ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE)

  result <- line_layer_payload(p, layer_index = 1)

  testthat::expect_equal(length(result$data), 3L)
  selectors <- expect_one_selector_per_series(result)

  # All three name curves of ONE grob -- this layer's own -- and differ only
  # in the trailing curve index.
  base <- unique(sub("\\\\\\.1\\\\\\.\\d+$", "", selectors))
  testthat::expect_equal(length(base), 1L)
  testthat::expect_equal(
    sub("^.*\\\\\\.1\\\\\\.", "", selectors),
    c("1", "2", "3")
  )
})

test_that("grouped line beside geom_smooth(se = TRUE) emits one selector per series", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(grouped_line_df(), ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_line() +
    ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = TRUE)

  result <- line_layer_payload(p, layer_index = 1)

  testthat::expect_equal(length(result$data), 3L)
  expect_one_selector_per_series(result)
})

test_that("the smooth layer may be drawn first without starving the line layer", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(grouped_line_df(), ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE) +
    ggplot2::geom_line()

  result <- line_layer_payload(p, layer_index = 2)

  testthat::expect_equal(length(result$data), 3L)
  selectors <- expect_one_selector_per_series(result)

  # The smooth's three grobs must not be mistaken for this layer's curves:
  # every selector belongs to the same, single grob.
  base <- unique(sub("\\\\\\.1\\\\\\.\\d+$", "", selectors))
  testthat::expect_equal(length(base), 1L)
})

test_that("a grouped line with no second polyline layer still emits one selector per series", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(grouped_line_df(), ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_line()

  result <- line_layer_payload(p, layer_index = 1)

  testthat::expect_equal(length(result$data), 3L)
  expect_one_selector_per_series(result)
})

test_that("an ungrouped line beside a smooth keeps its single selector", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:8, y = c(1, 3, 2, 5, 4, 7, 6, 9))
  p <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_line() +
    ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE)

  result <- line_layer_payload(p, layer_index = 1)

  testthat::expect_equal(length(result$data), 1L)
  expect_one_selector_per_series(result)
})

test_that("each of two line layers in a panel resolves to its OWN polyline grob", {
  # The shape the position-indexing branch was written for: several
  # single-curve line overlays in one panel (candlestick + N x geom_ma).
  # tidyquant is only in Suggests, so exercise the same grob structure with
  # two plain geom_line() layers over a bar layer.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:8, y = c(1, 3, 2, 5, 4, 7, 6, 9))
  p <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_col() +
    ggplot2::geom_line() +
    ggplot2::geom_line(ggplot2::aes(y = y * 0.5), linetype = "dashed")

  first <- line_layer_payload(p, layer_index = 2)
  second <- line_layer_payload(p, layer_index = 3)

  testthat::expect_equal(length(first$selectors), 1L)
  testthat::expect_equal(length(second$selectors), 1L)
  testthat::expect_false(identical(first$selectors[[1]], second$selectors[[1]]))
})

test_that("no selector is emitted when the curves cannot be lined up with the series", {
  # The honest failure mode: a wrong-length selector list silently kills the
  # layer's highlight in the frontend, so emit nothing instead and let the
  # caller see it.
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(grouped_line_df(), ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_line() +
    ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE)

  processor <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplot_gtable(built)

  selectors <- processor$generate_selectors(
    p, gt,
    built = built, n_series = 7
  )

  testthat::expect_equal(length(selectors), 0L)
})

test_that("the payload a grouped line + smooth renders satisfies the JS length precondition", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(grouped_line_df(), ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_line() +
    ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE)

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  maidr_data <- orchestrator$generate_maidr_data()
  layers <- maidr_data$subplots[[1]][[1]]$layers

  types <- vapply(layers, function(l) l$type, character(1))
  testthat::expect_true("line" %in% types)

  for (layer in layers) {
    if (!identical(layer$type, "line")) next
    testthat::expect_equal(
      length(unlist(layer$selectors, use.names = FALSE)),
      length(layer$data)
    )
  }
})

# ==============================================================================
# Faceted panels under a transformed x scale
# ==============================================================================

# `ggplot_build()` records x positions in the scale's TRANSFORMED space: under
# scale_x_log10() the data value 100 is stored as 2. A faceted panel recovers
# the user-facing value by matching those positions against the raw column, so
# the raw column has to make the same trip through the transformation first.
# Without that, nothing matched and the panel announced 0/1/2/3 for an axis
# labelled 1/10/100/1000.

facet_line_x <- function(plot, panel_id) {
  processor <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))
  built <- ggplot2::ggplot_build(plot)
  series <- processor$extract_data(plot, built, panel_id = panel_id)
  lapply(series, function(points) {
    vapply(points, function(point) point$x, character(1))
  })
}

transformed_scale_df <- function() {
  data.frame(
    g = rep(c("a", "b"), each = 4),
    x = rep(c(1, 10, 100, 1000), 2),
    y = 1:8
  )
}

transformed_scale_aes <- ggplot2::aes(x = x, y = y)

faceted_line <- function(df = transformed_scale_df()) {
  ggplot2::ggplot(df, transformed_scale_aes) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~g)
}

test_that("faceted panels announce data x values under scale_x_log10()", {
  p <- faceted_line() + ggplot2::scale_x_log10()

  for (panel in c(1, 2)) {
    series <- facet_line_x(p, panel)
    testthat::expect_length(series, 1)
    testthat::expect_equal(series[[1]], c("1", "10", "100", "1000"))
  }
})

test_that("faceted panels announce data x values under scale_x_sqrt()", {
  p <- faceted_line() + ggplot2::scale_x_sqrt()

  for (panel in c(1, 2)) {
    testthat::expect_equal(
      facet_line_x(p, panel)[[1]], c("1", "10", "100", "1000")
    )
  }
})

test_that("faceted panels announce data x values under scale_x_reverse()", {
  p <- faceted_line() + ggplot2::scale_x_reverse()

  # A reversed axis draws 1000 leftmost, and geom_line orders its points the
  # way it draws them, so the announced order follows the drawn line.
  for (panel in c(1, 2)) {
    testthat::expect_equal(
      facet_line_x(p, panel)[[1]], c("1000", "100", "10", "1")
    )
  }
})

test_that("faceted panels announce data x values under a named transform", {
  p <- faceted_line() + ggplot2::scale_x_continuous(trans = "log2")

  for (panel in c(1, 2)) {
    testthat::expect_equal(
      facet_line_x(p, panel)[[1]], c("1", "10", "100", "1000")
    )
  }
})

test_that("faceted panels keep working on an untransformed x scale", {
  p <- faceted_line()

  for (panel in c(1, 2)) {
    testthat::expect_equal(
      facet_line_x(p, panel)[[1]], c("1", "10", "100", "1000")
    )
  }
})

test_that("faceted Date panels still announce ISO dates", {
  dates <- as.Date("2024-01-01") + c(0, 10, 20, 30)
  df <- data.frame(
    g = rep(c("a", "b"), each = 4),
    x = rep(dates, 2),
    y = 1:8
  )

  for (panel in c(1, 2)) {
    testthat::expect_equal(
      facet_line_x(faceted_line(df), panel)[[1]],
      c("2024-01-01", "2024-01-11", "2024-01-21", "2024-01-31")
    )
  }
})

test_that("every series of a faceted multiline panel is untransformed", {
  df <- data.frame(
    g = rep(c("a", "b"), each = 8),
    s = rep(rep(c("s1", "s2"), each = 4), 2),
    x = rep(c(1, 10, 100, 1000), 4),
    y = 1:16
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x, y, colour = s)) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~g) +
    ggplot2::scale_x_log10()

  for (panel in c(1, 2)) {
    series <- facet_line_x(p, panel)
    testthat::expect_length(series, 2)
    for (points in series) {
      testthat::expect_equal(points, c("1", "10", "100", "1000"))
    }
  }
})

test_that("each faceted panel reads break labels off its own scale", {
  df <- data.frame(
    g = rep(c("a", "b"), each = 3),
    x = c(1, 2, 3, 1000, 2000, 3000),
    y = 1:6
  )
  # An expression x aesthetic leaves no raw column to match against, so the
  # break/label mapping is what supplies the announced value. Under
  # scales = "free_x" it has to read the panel's own breaks; panel 1's do not
  # reach panel 2's data at all.
  p <- ggplot2::ggplot(df, ggplot2::aes(x + 0, y)) +
    ggplot2::geom_line() +
    ggplot2::facet_wrap(~g, scales = "free_x") +
    ggplot2::scale_x_continuous(labels = function(value) paste0("<", value, ">"))

  testthat::expect_equal(facet_line_x(p, 1)[[1]], c("<1>", "<2>", "<3>"))
  testthat::expect_equal(
    facet_line_x(p, 2)[[1]], c("<1000>", "<2000>", "<3000>")
  )
})

# ==============================================================================
# Discrete y: the level NAME, not the level code (#121)
# ==============================================================================

hypnogram_df <- function() {
  data.frame(
    t = 1:6,
    stage = factor(
      c("Awake", "REM", "N1", "N2", "N3", "N2"),
      levels = c("N3", "N2", "N1", "REM", "Awake"),
      ordered = TRUE
    )
  )
}

test_that("a factor y on geom_line() carries the level name as label", {
  # Without this the reader hears ggplot2's internal level code -- "5" where
  # the axis says "Awake". y stays numeric on purpose: it drives sonification,
  # braille and the min/max range.
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(
    hypnogram_df(), ggplot2::aes(t, stage, group = 1)
  ) + ggplot2::geom_line()

  data <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))$extract_data(p)

  labels <- vapply(data[[1]], function(pt) pt$label, character(1))
  testthat::expect_equal(
    labels, c("Awake", "REM", "N1", "N2", "N3", "N2")
  )

  # The factor's level order drives the code: N3 is level 1, Awake is 5.
  ys <- vapply(data[[1]], function(pt) pt$y, numeric(1))
  testthat::expect_equal(ys[[1]], 5)
  testthat::expect_equal(ys[[5]], 1)
})

test_that("a factor y on geom_line() leaves y a bare number", {
  # ggplot_build() returns y classed mapped_discrete. It inherits numeric, so
  # jsonlite encodes it either way, but the wire contract asks for a plain
  # number and a stray S3 class is one dependency bump away from mattering.
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(
    hypnogram_df(), ggplot2::aes(t, stage, group = 1)
  ) + ggplot2::geom_line()

  data <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))$extract_data(p)

  testthat::expect_identical(class(data[[1]][[1]]$y), "numeric")
  testthat::expect_silent(jsonlite::toJSON(data, auto_unbox = TRUE))
})

test_that("a continuous y on geom_line() emits no label", {
  # A number is the right announcement for a continuous y; a label would be
  # noise. This is what keeps the fix scoped to discrete aesthetics.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(t = 1:5, v = c(2.5, 3.1, 4.0, 3.3, 2.2))
  p <- ggplot2::ggplot(df, ggplot2::aes(t, v)) + ggplot2::geom_line()

  data <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))$extract_data(p)

  testthat::expect_null(data[[1]][[1]]$label)
  testthat::expect_equal(data[[1]][[1]]$y, 2.5)
})

test_that("a grouped factor y keeps both the series name and the level name", {
  # z (the series) and label (the level) are different things and must not
  # displace one another.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    t = rep(1:3, 2),
    s = factor(rep(c("A", "B", "C"), 2), levels = c("C", "B", "A")),
    g = rep(c("x", "y"), each = 3)
  )
  p <- ggplot2::ggplot(
    df, ggplot2::aes(t, s, colour = g, group = g)
  ) + ggplot2::geom_line()

  data <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))$extract_data(p)

  testthat::expect_equal(length(data), 2)
  testthat::expect_equal(data[[1]][[1]]$z, "x")
  testthat::expect_equal(data[[1]][[1]]$label, "A")
})

test_that("an unsorted geom_line() still names each level correctly", {
  # GeomLine$setup_data() sorts the built data by (PANEL, group, x) -- that
  # sort is the documented difference between geom_line() and geom_path() --
  # while the caller's column keeps its own order. Pairing the two row by row
  # therefore attaches the wrong name to the wrong code, and every other test
  # here happens to use an already-sorted x, which hides it. Reading the names
  # off the factor's own level vector sidesteps ordering entirely.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    t = c(3, 1, 2),
    stage = factor(
      c("N1", "N3", "N2"),
      levels = c("N3", "N2", "N1", "REM", "Awake"),
      ordered = TRUE
    )
  )
  p <- ggplot2::ggplot(
    df, ggplot2::aes(t, stage, group = 1)
  ) + ggplot2::geom_line()

  data <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))$extract_data(p)

  # The built data is x-sorted, so the codes run 1, 2, 3 and must name the
  # levels at those positions -- not the levels of the caller's rows 1, 2, 3.
  pairs <- vapply(
    data[[1]], function(pt) paste0(pt$y, "=", pt$label), character(1)
  )
  testthat::expect_equal(pairs, c("1=N3", "2=N2", "3=N1"))
})

test_that("a factor with unused levels is named by what the axis draws", {
  # A discrete scale defaults to drop = TRUE. A factor declaring five levels
  # of which two are drawn is coded 1..2, NOT by position in levels(), so
  # naming from the factor would call code 2 "N2" while the axis says
  # "Awake". The panel's own labels are the only source that agrees with the
  # drawn axis, which is the whole point of the announcement.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    t = 1:2,
    stage = factor(
      c("Awake", "N3"),
      levels = c("N3", "N2", "N1", "REM", "Awake"),
      ordered = TRUE
    )
  )
  p <- ggplot2::ggplot(
    df, ggplot2::aes(t, stage, group = 1)
  ) + ggplot2::geom_line()

  built <- ggplot2::ggplot_build(p)
  testthat::expect_equal(
    as.character(built$layout$panel_params[[1]]$y$get_labels()),
    c("N3", "Awake")
  )

  data <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))$extract_data(p)

  # Built as x-sorted: t = 1 is "Awake" (code 2), t = 2 is "N3" (code 1).
  testthat::expect_equal(data[[1]][[1]]$y, 2)
  testthat::expect_equal(data[[1]][[1]]$label, "Awake")
  testthat::expect_equal(data[[1]][[2]]$y, 1)
  testthat::expect_equal(data[[1]][[2]]$label, "N3")
})
