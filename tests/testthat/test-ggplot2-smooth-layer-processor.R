# Comprehensive tests for Ggplot2SmoothLayerProcessor
# Testing smooth layer processing, data extraction, and selector generation

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor initializes correctly", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2SmoothLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("Ggplot2SmoothLayerProcessor extract_data() works with geom_smooth", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  layer_info <- list(index = 2) # smooth is second layer after geom_point
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
  testthat::expect_type(data[[1]], "list")
  testthat::expect_true(length(data[[1]]) > 0)

  # First point should have x and y
  first_point <- data[[1]][[1]]
  testthat::expect_true("x" %in% names(first_point))
  testthat::expect_true("y" %in% names(first_point))
})

test_that("Ggplot2SmoothLayerProcessor generate_selectors() works", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
  testthat::expect_type(selectors[[1]], "character")
  testthat::expect_match(selectors[[1]], "polyline")
})

test_that("Ggplot2SmoothLayerProcessor process() integrates correctly", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- built$layout

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  result <- processor$process(p, layout, built, gt)

  expect_processor_output(result)
  # axes and title may or may not be present depending on implementation
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor handles minimal smooth data", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:5, y = 1:5)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "lm", se = FALSE)

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
  testthat::expect_true(length(data[[1]]) > 0)
})

test_that("Ggplot2SmoothLayerProcessor handles smooth with se=TRUE", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:20, y = rnorm(20))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "loess", se = TRUE)

  layer_info <- list(index = 2)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
})

test_that("Ggplot2SmoothLayerProcessor handles NULL gt parameter", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
  # Should use fallback selector
  testthat::expect_match(selectors[[1]], "polyline")
})

test_that("Ggplot2SmoothLayerProcessor handles non-ggplot input", {
  testthat::skip_if_not_installed("ggplot2")

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  testthat::expect_error(
    processor$extract_data("not a ggplot"),
    "must be a ggplot object"
  )
})

# ==============================================================================
# Tier 3: Integration Tests
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor works with loess method", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:30, y = sin(1:30 / 5) + rnorm(30, sd = 0.2))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "loess")

  layer_info <- list(index = 2)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
})

test_that("Ggplot2SmoothLayerProcessor works with lm method", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:20, y = 1:20 + rnorm(20))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "lm")

  layer_info <- list(index = 2)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
})

test_that("Ggplot2SmoothLayerProcessor axes extraction works via process()", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- built$layout

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  result <- processor$process(p, layout, built, gt)

  # Process should return data and selectors at minimum
  testthat::expect_type(result, "list")
  testthat::expect_true("data" %in% names(result))
  testthat::expect_true("selectors" %in% names(result))
})

# ==============================================================================
# Tier 4: Smooth-Specific Logic
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor detects GeomSmooth", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:10, y = 1:10)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_smooth()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  # Should not error
  data <- processor$extract_data(p)
  testthat::expect_type(data, "list")
})

test_that("Ggplot2SmoothLayerProcessor detects GeomDensity", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = rnorm(100))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x)) +
    ggplot2::geom_density()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  # Should not error
  data <- processor$extract_data(p)
  testthat::expect_type(data, "list")
})

test_that("Ggplot2SmoothLayerProcessor errors when no smooth layer found", {
  testthat::skip_if_not_installed("ggplot2")

  # Plot with no smooth layer
  p <- create_test_ggplot_bar()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  testthat::expect_error(
    processor$extract_data(p),
    "No smooth curve layers found"
  )
})

test_that("Ggplot2SmoothLayerProcessor polyline collection is recursive", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  # Should find polyline grobs recursively
  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
})

test_that("Ggplot2SmoothLayerProcessor picks last polyline (max ID)", {
  testthat::skip_if_not_installed("ggplot2")

  # Smooth with confidence interval creates multiple polylines
  df <- data.frame(x = 1:20, y = rnorm(20))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(method = "loess", se = TRUE)

  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 2)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  # Selector should reference the last (max ID) polyline
  testthat::expect_type(selectors, "list")
  testthat::expect_match(selectors[[1]], "polyline")
  # ID extraction logic should pick max numeric ID
})

test_that("Ggplot2SmoothLayerProcessor escapes dots in selector", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  gt <- ggplot2::ggplotGrob(p)

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(p, gt)

  # CSS selector should have escaped dots (\\.)
  testthat::expect_match(selectors[[1]], "\\\\\\.")
})

test_that("Ggplot2SmoothLayerProcessor data points have correct structure", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()
  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  data <- processor$extract_data(p)

  # Outer list
  testthat::expect_equal(length(data), 1)
  # Inner list of points
  points <- data[[1]]
  testthat::expect_type(points, "list")

  # Each point should have x and y
  for (point in points) {
    testthat::expect_type(point, "list")
    testthat::expect_true("x" %in% names(point))
    testthat::expect_true("y" %in% names(point))
    testthat::expect_type(point$x, "double")
    testthat::expect_type(point$y, "double")
  }
})

test_that("Ggplot2SmoothLayerProcessor handles fallback selector", {
  testthat::skip_if_not_installed("ggplot2")

  # Create a mock gt with no polyline grobs
  p <- create_test_ggplot_bar()

  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  # gt with no polylines
  gt <- ggplot2::ggplotGrob(p)
  selectors <- processor$generate_selectors(p, gt)

  # Should use fallback
  testthat::expect_type(selectors, "list")
  testthat::expect_match(selectors[[1]], "polyline")
})

# ==============================================================================
# Integration with Full Pipeline
# ==============================================================================

test_that("Ggplot2SmoothLayerProcessor works in full pipeline", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_smooth()

  layer_info <- list(index = 2) # smooth is second layer
  processor <- maidr:::Ggplot2SmoothLayerProcessor$new(layer_info)

  built <- ggplot2::ggplot_build(p)
  gt <- ggplot2::ggplotGrob(p)
  layout <- built$layout

  result <- processor$process(p, layout, built, gt)

  # Validate full result
  expect_processor_output(result)

  # Validate data format
  expect_maidr_data_format(result$data[[1]], "smooth")
})

# ==============================================================================
# Grouped smooth -> one series per drawn curve (issue #81)
# ==============================================================================

# ggplot2 draws geom_smooth(aes(colour = g)) as one curve per group. The
# payload has to be split the same way: concatenating the groups into a single
# undifferentiated series walks a reader off the end of one curve into the
# start of the next with nothing announced in between, and leaves the layer's
# lone selector highlighting a single group's polyline for all of them.

grouped_smooth_df <- function() {
  data.frame(
    x = rep(1:10, 3),
    y = c(1:10, 10:1, rep(c(4, 6), 5)),
    g = rep(c("a", "b", "c"), each = 10)
  )
}

grouped_smooth_plot <- function(se = FALSE) {
  ggplot2::ggplot(
    grouped_smooth_df(),
    ggplot2::aes(x = x, y = y, colour = g)
  ) +
    ggplot2::geom_smooth(se = se, method = "lm", formula = y ~ x)
}

ungrouped_smooth_plot <- function() {
  ggplot2::ggplot(grouped_smooth_df(), ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_smooth(se = FALSE, method = "lm", formula = y ~ x)
}

smooth_processor <- function(index = 1) {
  maidr:::Ggplot2SmoothLayerProcessor$new(list(index = index))
}

process_smooth <- function(plot, index = 1) {
  processor <- smooth_processor(index)
  built <- ggplot2::ggplot_build(plot)
  layout <- list(title = "", axes = list(x = "x", y = "y"))
  result <- processor$process(
    plot, layout, built, ggplot2::ggplotGrob(plot)
  )
  maidr:::validate_axes(result$axes, "smooth layer")
  result
}

series_z_values <- function(series) {
  unique(vapply(series, function(point) {
    if (is.null(point$z)) NA_character_ else as.character(point$z)
  }, character(1)))
}

test_that("a grouped smooth emits one series per drawn curve", {
  testthat::skip_if_not_installed("ggplot2")

  data <- smooth_processor()$extract_data(grouped_smooth_plot())

  # ggplot2 fits each group over 80 points; before the fix all 240 landed in
  # a single series.
  testthat::expect_equal(length(data), 3)
  testthat::expect_equal(as.integer(lengths(data)), c(80L, 80L, 80L))
})

test_that("every point of a grouped smooth series carries its group name", {
  testthat::skip_if_not_installed("ggplot2")

  data <- smooth_processor()$extract_data(grouped_smooth_plot())

  testthat::expect_equal(series_z_values(data[[1]]), "a")
  testthat::expect_equal(series_z_values(data[[2]]), "b")
  testthat::expect_equal(series_z_values(data[[3]]), "c")
})

test_that("an ungrouped smooth stays a single series with no z", {
  testthat::skip_if_not_installed("ggplot2")

  data <- smooth_processor()$extract_data(ungrouped_smooth_plot())

  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 80)
  testthat::expect_false("z" %in% names(data[[1]][[1]]))
})

test_that("grouped smooth z label falls back to the mapped column name", {
  testthat::skip_if_not_installed("ggplot2")

  axes <- process_smooth(grouped_smooth_plot())$axes

  testthat::expect_equal(axes$z$label, "g")
})

test_that("grouped smooth z label comes from labs(colour = ...)", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- grouped_smooth_plot() + ggplot2::labs(colour = "Cohort")

  testthat::expect_equal(process_smooth(plot)$axes$z$label, "Cohort")
})

test_that("grouped smooth z label reads a layer-level colour mapping", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(grouped_smooth_df(), ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_smooth(
      ggplot2::aes(colour = g),
      se = FALSE, method = "lm", formula = y ~ x
    ) +
    ggplot2::labs(colour = "Cohort")

  testthat::expect_equal(process_smooth(plot)$axes$z$label, "Cohort")
})

test_that("an ungrouped smooth emits no z label", {
  testthat::skip_if_not_installed("ggplot2")

  testthat::expect_null(process_smooth(ungrouped_smooth_plot())$axes$z)
})

test_that("labs(colour = ...) on an ungrouped smooth invents no z label", {
  testthat::skip_if_not_installed("ggplot2")

  # ggplot2 records a labs() title even for an aesthetic the plot never maps,
  # so the lookup has to be gated on the layer actually drawing more than one
  # curve -- otherwise MAIDR would announce a legend that is not drawn.
  plot <- ungrouped_smooth_plot() + ggplot2::labs(colour = "Not a legend")

  axes <- suppressMessages(suppressWarnings(process_smooth(plot)))$axes

  testthat::expect_null(axes$z)
})

test_that("a smooth grouped by a fill mapping is split and labelled", {
  testthat::skip_if_not_installed("ggplot2")

  # geom_density() / geom_area() render a fill, so aes(fill = g) splits them
  # into one curve per group exactly as aes(colour = g) does.
  plot <- ggplot2::ggplot(
    grouped_smooth_df(),
    ggplot2::aes(x = y, fill = g)
  ) +
    ggplot2::geom_density(alpha = 0.3)

  result <- process_smooth(plot)

  testthat::expect_equal(length(result$data), 3)
  testthat::expect_equal(series_z_values(result$data[[1]]), "a")
  testthat::expect_equal(result$axes$z$label, "g")
})

test_that("a grouped smooth emits one distinct selector per curve", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- grouped_smooth_plot()
  selectors <- smooth_processor()$generate_selectors(
    plot, ggplot2::ggplotGrob(plot)
  )

  # selectors.length === data.length is a MAIDR frontend precondition.
  testthat::expect_equal(length(selectors), 3)
  testthat::expect_equal(length(unique(unlist(selectors))), 3)
})

test_that("an ungrouped smooth keeps its single selector", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ungrouped_smooth_plot()
  selectors <- smooth_processor()$generate_selectors(
    plot, ggplot2::ggplotGrob(plot)
  )

  testthat::expect_equal(length(selectors), 1)
})

test_that("a grouped smooth does not select a sibling line layer's polyline", {
  testthat::skip_if_not_installed("ggplot2")

  # geom_line() draws its own polyline as a sibling of the smooth layer's
  # grob tree. Scoping the search to this layer's tree is what keeps the two
  # layers' selectors apart.
  plot <- ggplot2::ggplot(
    grouped_smooth_df(),
    ggplot2::aes(x = x, y = y, colour = g)
  ) +
    ggplot2::geom_line() +
    ggplot2::geom_smooth(se = FALSE, method = "lm", formula = y ~ x)

  gt <- ggplot2::ggplotGrob(plot)
  built <- ggplot2::ggplot_build(plot)

  smooth_selectors <- unlist(
    smooth_processor(2)$generate_selectors(plot, gt)
  )
  line_selectors <- unlist(
    maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))$generate_selectors(
      plot, gt,
      built = built
    )
  )

  testthat::expect_equal(length(smooth_selectors), 3)
  testthat::expect_length(intersect(smooth_selectors, line_selectors), 0)
})

# ------------------------------------------------------------------------
# Full render pipeline: the payload has to line up with the drawn SVG
# ------------------------------------------------------------------------

render_smooth_payload <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(suppressMessages(save_html(plot, file)))
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

  list(
    data = jsonlite::fromJSON(json, simplifyVector = FALSE),
    doc = xml2::read_html(html)
  )
}

# The smooth layer emits id-only selectors ("#GRID\\.polyline\\.3\\.1\\.1"),
# so un-escaping is just the inverse of the processor's own escaping. The
# shape is asserted first: a selector carrying a combinator would need a real
# CSS engine, and must fail here rather than be mis-parsed into a wrong id.
smooth_selector_node <- function(doc, selector) {
  testthat::expect_false(grepl("[[:space:]>+~,]", selector))
  id <- sub("^#", "", gsub("\\.", ".", selector, fixed = TRUE))
  xml2::xml_find_first(doc, sprintf("//*[@id='%s']", id))
}

polyline_point_count <- function(node) {
  points <- xml2::xml_attr(node, "points")
  length(strsplit(trimws(points), "[[:space:]]+")[[1]])
}

test_that("a grouped smooth's selectors each address their own curve", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
  testthat::skip_if_not_installed("xml2")

  payload <- render_smooth_payload(grouped_smooth_plot())
  layer <- payload$data$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_equal(layer$type, "smooth")
  testthat::expect_equal(length(layer$data), 3)
  testthat::expect_equal(length(layer$selectors), 3)
  testthat::expect_equal(layer$axes$z$label, "g")
  testthat::expect_equal(
    vapply(layer$data, function(s) as.character(s[[1]]$z), character(1)),
    c("a", "b", "c")
  )

  for (i in seq_along(layer$selectors)) {
    node <- smooth_selector_node(payload$doc, layer$selectors[[i]])
    testthat::expect_false(inherits(node, "xml_missing"))
    testthat::expect_equal(xml2::xml_name(node), "polyline")
    # A selector aimed at one group while the data holds all three is the
    # mismatch this issue is about, so compare the vertex counts.
    testthat::expect_equal(
      polyline_point_count(node), length(layer$data[[i]])
    )
  }
})

test_that("a grouped se = TRUE smooth selects the fitted lines, not the ribbons", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
  testthat::skip_if_not_installed("xml2")

  payload <- render_smooth_payload(grouped_smooth_plot(se = TRUE))
  layer <- payload$data$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_equal(length(layer$data), 3)
  testthat::expect_equal(length(layer$selectors), 3)

  # Each group draws a confidence ribbon whose outline polyline carries
  # stroke="none", and a fitted line stroked in the group's own colour.
  # Selecting a distinct visible stroke per series is what tells the two
  # apart.
  strokes <- vapply(layer$selectors, function(selector) {
    node <- smooth_selector_node(payload$doc, selector)
    testthat::expect_false(inherits(node, "xml_missing"))
    as.character(xml2::xml_attr(node, "stroke"))
  }, character(1))

  testthat::expect_false(any(strokes == "none"))
  testthat::expect_equal(length(unique(strokes)), 3)
})

# ==============================================================================
# The grouped-selector fallback emits nothing rather than one wrong selector
# ==============================================================================

test_that("a chunking failure emits no selector rather than a mismatched one", {
  # grouped_curve_selectors() gives up when the layer's grob children do not
  # divide evenly by the group count. The old single-curve path is NOT a safe
  # landing place there: it returns one selector while the data already holds
  # one series per group, so the highlight sits on one curve while the reader
  # walks all of them -- the defect this processor was fixed for. Forcing the
  # give-up proves the answer is an empty list, not a wrong selector.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(1:10, 3),
    y = c(1:10, 11:20, 21:30),
    g = rep(c("a", "b", "c"), each = 10)
  )
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_smooth(se = FALSE, method = "lm", formula = y ~ x)

  processor <- Ggplot2SmoothLayerProcessor$new(list(index = 1))
  gt <- ggplot2::ggplotGrob(plot)

  # A group count the grob tree cannot divide by: 3 curves, 4 claimed groups.
  testthat::expect_null(processor$grouped_curve_selectors(plot, gt, NULL, 4L))

  # And through the wrapper that decides what to do about it, since that is
  # the branch the fix actually changed -- it must return nothing rather than
  # fall through to the single-curve path. Subclassed rather than patched:
  # an R6 object is locked, so the count cannot be overwritten in place.
  stubbed <- R6::R6Class(
    "StubbedSmoothProcessor",
    inherit = Ggplot2SmoothLayerProcessor,
    public = list(
      series_group_count = function(plot, built = NULL, panel_id = NULL) 4L
    )
  )$new(list(index = 1))

  testthat::expect_length(stubbed$generate_selectors(plot, gt), 0L)
})

test_that("geom_area(stat = \"density\") splits per group like the others", {
  # A default geom_area() uses StatAlign and never reaches this processor,
  # but with stat = "density" the adapter types it smooth, so it does.
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")

  set.seed(1)
  df <- data.frame(
    y = c(stats::rnorm(30), stats::rnorm(30, 3), stats::rnorm(30, 6)),
    g = rep(c("a", "b", "c"), each = 30)
  )
  plot <- ggplot2::ggplot(df, ggplot2::aes(y, fill = g)) +
    ggplot2::geom_area(stat = "density", alpha = 0.3)

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  json <- sub('"$', "", sub('^maidr-data="', "", regmatches(
    html, regexpr('maidr-data="[^"]*"', html)
  )))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)
  payload <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  layer <- payload$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_equal(layer$type, "smooth")
  testthat::expect_length(layer$data, 3)
  testthat::expect_length(unlist(layer$selectors), 3)
  testthat::expect_equal(layer$axes$z$label, "g")
})
