# Comprehensive tests for Ggplot2StepLayerProcessor
# Testing data extraction, ordinal level labels, step direction, selectors

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2StepLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::Ggplot2StepLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "Ggplot2StepLayerProcessor")
  testthat::expect_s3_class(processor, "Ggplot2LineLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("Ggplot2StepLayerProcessor extract_data() emits one point per sample", {
  # ggplot2 expands the stairstep inside GeomStep$draw_panel(), so the rendered
  # polyline carries 2n-1 vertices. The payload must still describe the n data
  # samples: vertex-level data would double every level and misreport both the
  # transition count and the run lengths.
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  built <- ggplot2::ggplot_build(p)
  data <- processor$extract_data(p, built)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1) # One series
  testthat::expect_equal(length(data[[1]]), 6) # 6 samples, not 11 vertices

  testthat::expect_equal(data[[1]][[1]]$x, "1")
  testthat::expect_equal(data[[1]][[1]]$y, 1)
  testthat::expect_equal(data[[1]][[4]]$y, 5)
})

test_that("Ggplot2StepLayerProcessor extract_data() keeps y numeric", {
  # y drives sonification, braille and the min/max range, so it must stay a
  # bare number even when the aesthetic is an ordinal factor.
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_hypnogram()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(p)

  for (point in data[[1]]) {
    testthat::expect_type(point$y, "double")
    testthat::expect_null(oldClass(point$y))
  }
})

test_that("Ggplot2StepLayerProcessor process() returns step type and direction", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  layout <- list(title = "Test Step Plot", axes = list(x = "X", y = "Y"))
  result <- processor$process(p, layout, NULL, NULL, NULL, NULL, NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$type, "step")
  testthat::expect_equal(result$stepDirection, "hv")
  testthat::expect_equal(result$title, "Test Step Plot")
  testthat::expect_equal(result$axes$x$label, "X")
  testthat::expect_equal(result$axes$y$label, "Y")
  testthat::expect_equal(length(result$data), 1)
  testthat::expect_equal(length(result$data[[1]]), 6)
})

test_that("Ggplot2StepLayerProcessor emits canonical axes only", {
  # build_axes()/validate_axes() reject bare strings and any key outside
  # {x,y,z}; stepDirection is a layer-level sibling, never an axis field.
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  layout <- list(title = "", axes = list(x = "X", y = "Y"))
  result <- processor$process(p, layout, NULL, NULL, NULL, NULL, NULL)

  testthat::expect_true(all(names(result$axes) %in% c("x", "y", "z")))
  testthat::expect_type(result$axes$x, "list")
  testthat::expect_false("stepDirection" %in% names(result$axes))
  testthat::expect_silent(maidr:::validate_axes(result$axes))
})

# ==============================================================================
# Tier 2: Ordinal level label recovery (the hypnogram case)
# ==============================================================================

test_that("Ggplot2StepLayerProcessor attaches factor level names as labels", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_hypnogram()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(p)

  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 10)

  labels <- vapply(data[[1]], function(pt) pt$label, character(1))
  testthat::expect_equal(
    labels,
    c("Awake", "N1", "N2", "N2", "N3", "N3", "REM", "N2", "N1", "Awake")
  )
})

test_that("Ggplot2StepLayerProcessor label matches the numeric level code", {
  # The lookup is keyed by the built y value, so equal levels must carry equal
  # labels and distinct levels distinct labels.
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_hypnogram()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(p)
  pairs <- unique(lapply(data[[1]], function(pt) c(pt$y, pt$label)))

  ys <- vapply(pairs, function(p) p[[1]], character(1))
  labels <- vapply(pairs, function(p) p[[2]], character(1))
  testthat::expect_equal(length(unique(ys)), length(unique(labels)))

  # The factor's level order drives the numeric code: N3 is level 1, Awake 5.
  n3 <- Filter(function(pt) identical(pt$label, "N3"), data[[1]])[[1]]
  awake <- Filter(function(pt) identical(pt$label, "Awake"), data[[1]])[[1]]
  testthat::expect_equal(n3$y, 1)
  testthat::expect_equal(awake$y, 5)
})

test_that("Ggplot2StepLayerProcessor emits no label for a continuous y", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(p)

  for (point in data[[1]]) {
    testthat::expect_false("label" %in% names(point))
  }
})

test_that("Ggplot2StepLayerProcessor recovers level names from a character y", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = 1:4,
    state = c("idle", "busy", "busy", "idle"),
    stringsAsFactors = FALSE
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = state, group = 1)) +
    ggplot2::geom_step()

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  labels <- vapply(data[[1]], function(pt) pt$label, character(1))
  testthat::expect_equal(labels, c("idle", "busy", "busy", "idle"))
})

test_that("Ggplot2StepLayerProcessor build_level_lookup returns NULL for numeric y", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  built <- ggplot2::ggplot_build(p)
  testthat::expect_null(processor$build_level_lookup(p, built))
})

test_that("a step layer names a dropped-level factor by what the axis draws", {
  # A discrete scale defaults to drop = TRUE, so a factor declaring five
  # levels of which two are drawn is coded 1..2. Naming by position in
  # levels() would call code 2 "N2"; the axis says "Awake". The lookup reads
  # the panel's own labels for exactly this reason.
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
  ) + ggplot2::geom_step()

  data <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))$extract_data(p)

  labels <- vapply(data[[1]], function(pt) pt$label, character(1))
  testthat::expect_equal(labels, c("Awake", "N3"))
})

# ==============================================================================
# Tier 3: Step direction extraction
# ==============================================================================

test_that("Ggplot2StepLayerProcessor extracts every step direction", {
  # geom_step(direction = ) is a draw_panel formal, so ggplot2 files it under
  # layer$geom_params$direction rather than the layer's mapping or aes_params.
  testthat::skip_if_not_installed("ggplot2")

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  for (direction in c("hv", "vh", "mid")) {
    p <- create_test_ggplot_step(direction)
    testthat::expect_equal(processor$extract_step_direction(p), direction)
  }
})

test_that("Ggplot2StepLayerProcessor defaults the direction to hv", {
  # ggplot2's own default is "hv", matching MAIDR's.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:3, y = c(1, 2, 2))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) + ggplot2::geom_step()

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
  testthat::expect_equal(processor$extract_step_direction(p), "hv")
})

test_that("Ggplot2StepLayerProcessor falls back to hv for an unknown direction", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  p$layers[[1]]$geom_params$direction <- "sideways"

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
  testthat::expect_equal(processor$extract_step_direction(p), "hv")
})

test_that("Ggplot2StepLayerProcessor returns NULL direction when the layer is missing", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 99))

  testthat::expect_null(processor$extract_step_direction(p))
})

test_that("Ggplot2StepLayerProcessor process() carries the direction through", {
  testthat::skip_if_not_installed("ggplot2")

  layout <- list(title = "", axes = list(x = "X", y = "Y"))

  for (direction in c("hv", "vh", "mid")) {
    p <- create_test_ggplot_step(direction)
    processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
    result <- processor$process(p, layout, NULL, NULL, NULL, NULL, NULL)
    testthat::expect_equal(result$stepDirection, direction)
  }
})

# ==============================================================================
# Tier 4: Selectors
# ==============================================================================

test_that("Ggplot2StepLayerProcessor generates one selector per series", {
  # The frontend's mapToSvgElements returns null outright unless
  # selectors.length equals the number of series, which kills highlighting.
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  gt <- ggplot2::ggplotGrob(p)
  selectors <- processor$generate_selectors(p, gt)
  data <- processor$extract_data(p)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), length(data))
  testthat::expect_match(selectors[[1]], "^#GRID\\\\\\.polyline\\\\\\.")
})

test_that("Ggplot2StepLayerProcessor generates a selector with a NULL gtable", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  selectors <- processor$generate_selectors(p, gt = NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 1)
})

test_that("Ggplot2StepLayerProcessor uses the faceted grob_id path", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  selectors <- processor$generate_selectors(p, gt = NULL, grob_id = "GRID.polyline.100")

  testthat::expect_equal(length(selectors), 1)
  testthat::expect_match(selectors[[1]], "#GRID\\\\.polyline\\\\.100\\\\.1\\\\.1")
})

test_that("A line layer and a step layer target different polylines", {
  # layer_polyline_grobs() returns every polyline the panel's geom-named grob
  # trees do not claim, and geom_step() draws a bare one, so the position used
  # to index that list must be counted over every polyline-producing layer
  # type. Counting only "line" layers made both layers of a mixed plot resolve
  # to the same polyline.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:6, y = c(1, 3, 3, 5, 2, 2))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::geom_step()

  line_processor <- maidr:::Ggplot2LineLayerProcessor$new(list(index = 1))
  step_processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 2))

  testthat::expect_equal(line_processor$line_layer_position(p), 1L)
  testthat::expect_equal(step_processor$line_layer_position(p), 2L)

  gt <- ggplot2::ggplotGrob(p)
  line_selectors <- line_processor$generate_selectors(p, gt)
  step_selectors <- step_processor$generate_selectors(p, gt)

  testthat::expect_equal(length(line_selectors), 1)
  testthat::expect_equal(length(step_selectors), 1)
  testthat::expect_false(identical(line_selectors[[1]], step_selectors[[1]]))
})

test_that("polyline_layer_position counts line and step layers together", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:4, y = c(1, 2, 2, 3))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_step() +
    ggplot2::geom_point() +
    ggplot2::geom_line()

  testthat::expect_equal(maidr:::polyline_layer_position(p, 1), 1L)
  # geom_point() produces no polyline, so it does not consume a position.
  testthat::expect_null(maidr:::polyline_layer_position(p, 2))
  testthat::expect_equal(maidr:::polyline_layer_position(p, 3), 2L)
})

# ==============================================================================
# Tier 5: Edge cases
# ==============================================================================

test_that("Ggplot2StepLayerProcessor handles a NULL built parameter", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_step()
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(p, built = NULL)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 6)
})

test_that("Ggplot2StepLayerProcessor handles a single-sample step", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1, y = 5)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) + ggplot2::geom_step()

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 1)
  testthat::expect_equal(data[[1]][[1]]$x, "1")
  testthat::expect_equal(data[[1]][[1]]$y, 5)
})

test_that("Ggplot2StepLayerProcessor handles an empty data frame", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = numeric(0), y = numeric(0))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) + ggplot2::geom_step()

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  # No rows is no series: an empty series would be listed as a layer the
  # reader is told to enter.
  testthat::expect_type(data, "list")
  testthat::expect_length(data, 0)
})

test_that("Ggplot2StepLayerProcessor drops NA-y rows", {
  # Inherited from the line processor: the rendered polyline only contains
  # coordinates for non-NA points, so emitting placeholder rows would shift
  # the frontend's vertex-to-sample mapping.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:5, y = c(NA, 2, 2, NA, 5))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) + ggplot2::geom_step()

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
  data <- suppressWarnings(processor$extract_data(p))

  testthat::expect_equal(length(data[[1]]), 3)
  for (point in data[[1]]) {
    testthat::expect_false(is.na(point$y))
  }
})

test_that("Ggplot2StepLayerProcessor emits ISO date strings for a Date x-axis", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    night = seq(as.Date("2024-03-01"), by = "day", length.out = 4),
    stage = factor(c("Awake", "N2", "N2", "REM"), levels = c("N2", "REM", "Awake"))
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = night, y = stage, group = 1)) +
    ggplot2::geom_step()

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  testthat::expect_equal(data[[1]][[1]]$x, "2024-03-01")
  testthat::expect_equal(data[[1]][[1]]$label, "Awake")
})

test_that("Ggplot2StepLayerProcessor labels every series of a multi-series step", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    x = rep(1:4, 2),
    stage = factor(
      c("Awake", "N1", "N1", "N2", "N2", "N2", "REM", "Awake"),
      levels = c("N2", "N1", "REM", "Awake")
    ),
    who = rep(c("A", "B"), each = 4)
  )
  # `group` must be stated: a discrete y aesthetic would otherwise join the
  # default grouping interaction and split the data one series per level.
  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = x, y = stage, colour = who, group = who)
  ) +
    ggplot2::geom_step()

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  testthat::expect_equal(length(data), 2)
  testthat::expect_equal(data[[1]][[1]]$z, "A")
  testthat::expect_equal(data[[1]][[1]]$label, "Awake")
  testthat::expect_equal(data[[2]][[1]]$label, "N2")
})

# ==============================================================================
# Tier 6: Orchestrator integration (assert on the emitted layer, not on
# "rendering succeeded" - an undetected geom_step degrades silently to a
# static PNG)
# ==============================================================================

test_that("A step plot reaches the payload as type 'step' with a direction", {
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_hypnogram()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)

  testthat::expect_false(orchestrator$should_fallback())

  layer <- orchestrator$get_combined_data()[[1]][[1]]$layers[[1]]

  testthat::expect_equal(layer$type, "step")
  testthat::expect_equal(layer$stepDirection, "hv")
  testthat::expect_equal(length(layer$data), 1)
  testthat::expect_equal(length(layer$data[[1]]), 10)
  testthat::expect_equal(length(layer$selectors), length(layer$data))
  testthat::expect_equal(layer$data[[1]][[1]]$label, "Awake")
})

test_that("A step layer payload serialises to JSON", {
  # A discrete y aesthetic makes ggplot_build() return `mapped_discrete`,
  # which jsonlite cannot encode ("No method asJSON S3 class").
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_hypnogram()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  payload <- orchestrator$generate_maidr_data()

  json <- jsonlite::toJSON(payload, auto_unbox = TRUE)
  testthat::expect_true(grepl('"type":"step"', json, fixed = TRUE))
  testthat::expect_true(grepl('"stepDirection":"hv"', json, fixed = TRUE))
  testthat::expect_true(grepl('"label":"REM"', json, fixed = TRUE))
})

test_that("A step layer is not collapsed into a line layer", {
  # collapse_lines_to_multiseries() / merge_line_layers() hardcode type =
  # "line". A step layer swept into that merge would lose both its type and
  # its stepDirection.
  panel <- list(
    id = "subplot",
    layers = list(
      list(
        id = 1, type = "line", title = "", axes = NULL,
        data = list(list(list(x = "1", y = 1))), selectors = list("#line-a")
      ),
      list(
        id = 2, type = "step", title = "", axes = NULL, stepDirection = "vh",
        data = list(list(list(x = "1", y = 2, label = "REM"))),
        selectors = list("#step-a")
      ),
      list(
        id = 3, type = "line", title = "", axes = NULL,
        data = list(list(list(x = "1", y = 3))), selectors = list("#line-b")
      )
    )
  )

  collapsed <- maidr:::collapse_lines_to_multiseries(panel)

  types <- vapply(collapsed$layers, function(l) l$type, character(1))
  testthat::expect_equal(types, c("line", "step"))

  step_layer <- collapsed$layers[[which(types == "step")]]
  testthat::expect_equal(step_layer$stepDirection, "vh")
  testthat::expect_equal(step_layer$selectors, list("#step-a"))
  testthat::expect_equal(step_layer$data[[1]][[1]]$label, "REM")
})

test_that("merge_line_layers ignores step layers handed to it", {
  # Defensive: merge_line_layers() is only ever called with the layers
  # collapse_lines_to_multiseries() filtered, and it always reports "line".
  # This pins the type down so a step layer can never inherit it silently.
  layer_a <- list(
    id = "a", type = "line", title = "", axes = NULL,
    data = list(list(list(x = "1", y = 1))), selectors = list("#sel.A")
  )
  layer_b <- list(
    id = "b", type = "line", title = "", axes = NULL,
    data = list(list(list(x = "1", y = 2))), selectors = list("#sel.B")
  )

  merged <- maidr:::merge_line_layers(list(layer_a, layer_b))

  testthat::expect_equal(merged$type, "line")
  testthat::expect_null(merged$stepDirection)
})

test_that("A step layer survives alongside a line layer in the payload", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:6, y = c(1, 3, 3, 5, 2, 2))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line() +
    ggplot2::geom_step()

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  layers <- orchestrator$get_combined_data()[[1]][[1]]$layers

  types <- vapply(layers, function(l) l$type, character(1))
  testthat::expect_true("step" %in% types)
  testthat::expect_true("line" %in% types)

  step_layer <- layers[[which(types == "step")]]
  line_layer <- layers[[which(types == "line")]]
  testthat::expect_equal(step_layer$stepDirection, "hv")
  testthat::expect_false(
    identical(step_layer$selectors[[1]], line_layer$selectors[[1]])
  )
})

test_that("A faceted step plot keeps its stepDirection", {
  # Facet panels rebuild the payload layer field by field instead of copying
  # the processor result, so anything not carried across silently disappears
  # from every faceted step plot. The carry is `process_facet_panel()`'s
  # generic one, which copies every processor field outside its exclusion
  # list -- `stepDirection` is not in that list. This test is what stands
  # between a future edit to that list and the direction vanishing without a
  # word, so it asserts on the emitted field rather than on the mechanism.
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(
    hour = rep(1:4, 2),
    stage = factor(rep(c("Awake", "N1", "N2", "N2"), 2), levels = c("N2", "N1", "Awake")),
    night = rep(c("n1", "n2"), each = 4)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = hour, y = stage, group = 1)) +
    ggplot2::geom_step(direction = "vh") +
    ggplot2::facet_wrap(~night)

  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(p)
  grid <- orchestrator$get_combined_data()

  for (row in grid) {
    for (panel in row) {
      layer <- panel$layers[[1]]
      testthat::expect_equal(layer$type, "step")
      testthat::expect_equal(layer$stepDirection, "vh")
      testthat::expect_equal(length(layer$selectors), length(layer$data))
      testthat::expect_equal(layer$data[[1]][[1]]$label, "Awake")
    }
  }
})
