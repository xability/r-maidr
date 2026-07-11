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
