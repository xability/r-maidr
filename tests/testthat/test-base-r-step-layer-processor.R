# Comprehensive tests for BaseRStepLayerProcessor
# Testing data extraction, step direction (type = "s" / "S"), selectors

#' Build a recorded plot call for a Base R step layer
#' @param type "s", "S", or NULL
#' @param x x values
#' @param y y values
#' @param ... Extra recorded arguments (main, xlab, ylab, ...)
#' @return layer_info list
step_layer_info <- function(type = "s",
                            x = c(1, 2, 3, 4, 5),
                            y = c(1, 3, 3, 5, 2),
                            fn = "plot",
                            ...) {
  args <- list(x, y, ...)
  if (!is.null(type)) {
    args$type <- type
  }
  list(
    index = 1,
    function_name = fn,
    plot_call = list(function_name = fn, args = args)
  )
}

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("BaseRStepLayerProcessor initializes correctly", {
  layer_info <- list(index = 1)
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  expect_processor_r6(processor, "BaseRStepLayerProcessor")
  testthat::expect_s3_class(processor, "BaseRLineLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("BaseRStepLayerProcessor extract_data() emits one point per sample", {
  # The rendered stairstep polyline carries the corner vertices too; the
  # payload must still describe the samples, not the vertices.
  layer_info <- step_layer_info()
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  data <- processor$extract_data(layer_info)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 5)

  testthat::expect_equal(data[[1]][[1]]$x, "1")
  testthat::expect_equal(data[[1]][[1]]$y, 1)
  testthat::expect_equal(data[[1]][[4]]$y, 5)
})

test_that("BaseRStepLayerProcessor extract_data() keeps y numeric", {
  layer_info <- step_layer_info()
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  data <- processor$extract_data(layer_info)

  for (point in data[[1]]) {
    testthat::expect_type(point$y, "double")
    testthat::expect_type(point$x, "character")
  }
})

test_that("BaseRStepLayerProcessor process() returns step type and direction", {
  layer_info <- step_layer_info(
    type = "s",
    main = "Sleep Stages",
    xlab = "Hour",
    ylab = "Stage"
  )
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$type, "step")
  testthat::expect_equal(result$stepDirection, "hv")
  testthat::expect_equal(result$title, "Sleep Stages")
  testthat::expect_equal(result$axes$x$label, "Hour")
  testthat::expect_equal(result$axes$y$label, "Stage")
  testthat::expect_equal(length(result$data), 1)
  testthat::expect_equal(length(result$data[[1]]), 5)
})

test_that("BaseRStepLayerProcessor emits canonical axes only", {
  layer_info <- step_layer_info(xlab = "Hour", ylab = "Stage")
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  testthat::expect_true(all(names(result$axes) %in% c("x", "y", "z")))
  testthat::expect_false("stepDirection" %in% names(result$axes))
  testthat::expect_silent(maidr:::validate_axes(result$axes))
})

# ==============================================================================
# Tier 2: Step direction extraction
# ==============================================================================

test_that("BaseRStepLayerProcessor maps type = 's' to hv", {
  # type = "s" draws the horizontal segment first. Do not transpose these two.
  layer_info <- step_layer_info(type = "s")
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  testthat::expect_equal(processor$extract_step_direction(layer_info), "hv")
})

test_that("BaseRStepLayerProcessor maps type = 'S' to vh", {
  layer_info <- step_layer_info(type = "S")
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  testthat::expect_equal(processor$extract_step_direction(layer_info), "vh")
})

test_that("BaseRStepLayerProcessor omits the direction when type is absent", {
  # OMIT rather than guess: the frontend then says nothing about the
  # convention instead of asserting one the call never requested.
  layer_info <- step_layer_info(type = NULL)
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  testthat::expect_null(processor$extract_step_direction(layer_info))

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )
  testthat::expect_false("stepDirection" %in% names(result))
  testthat::expect_equal(result$type, "step")
})

test_that("BaseRStepLayerProcessor omits the direction for a non-step type", {
  layer_info <- step_layer_info(type = "l")
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  testthat::expect_null(processor$extract_step_direction(layer_info))
})

test_that("BaseRStepLayerProcessor direction extraction is case sensitive", {
  processor <- maidr:::BaseRStepLayerProcessor$new(list(index = 1))

  testthat::expect_equal(maidr:::base_r_step_direction("s"), "hv")
  testthat::expect_equal(maidr:::base_r_step_direction("S"), "vh")
  testthat::expect_null(maidr:::base_r_step_direction("l"))
  testthat::expect_null(maidr:::base_r_step_direction(NULL))
})

test_that("BaseRStepLayerProcessor handles lines(type = 'S') calls", {
  layer_info <- step_layer_info(type = "S", fn = "lines")
  layer_info$group <- list(
    high_call = list(
      args = list(c(1, 2, 3), c(1, 2, 3), xlab = "X High", ylab = "Y High")
    )
  )
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  testthat::expect_equal(result$type, "step")
  testthat::expect_equal(result$stepDirection, "vh")
  # Low-level calls inherit their axis titles from the HIGH-level plot() call.
  testthat::expect_equal(result$axes$x$label, "X High")
  testthat::expect_equal(result$axes$y$label, "Y High")
})

# ==============================================================================
# Tier 3: Selectors
# ==============================================================================

test_that("BaseRStepLayerProcessor generate_selectors() handles a NULL gtable", {
  layer_info <- step_layer_info()
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(layer_info, NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_equal(length(selectors), 0)
})

#' Wrap grob names in a minimal gTree the selector search can walk
#' @param ... Grob names
#' @return A gTree whose children carry those names
fake_grob_tree <- function(...) {
  structure(
    list(
      name = "root",
      children = lapply(
        c(...),
        function(nm) structure(list(name = nm), class = "grob")
      )
    ),
    class = c("gTree", "grob")
  )
}

test_that("BaseRStepLayerProcessor produces one polyline selector per grob", {
  # gridGraphics names a grob after the `type` letter that drew it, so the
  # stairstep lands under `-step-` / `-Step-`, never `-lines-`. Searching for
  # the line name yields zero selectors, and the frontend's
  # `selectors.length === series count` precondition then drops highlighting.
  layer_info <- step_layer_info()
  layer_info$group_index <- 1
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(
    layer_info, fake_grob_tree("graphics-plot-1-step-1")
  )

  testthat::expect_equal(length(selectors), 1)
  testthat::expect_equal(
    selectors[[1]],
    "#graphics-plot-1-step-1\\.1 polyline"
  )
})

test_that("BaseRStepLayerProcessor finds the type = 'S' stairstep grob", {
  # type = "S" is drawn into `-Step-`, capitalised.
  layer_info <- step_layer_info(type = "S")
  layer_info$group_index <- 1
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  selectors <- processor$generate_selectors(
    layer_info, fake_grob_tree("graphics-plot-1-Step-1")
  )

  testthat::expect_equal(length(selectors), 1)
  testthat::expect_equal(
    selectors[[1]],
    "#graphics-plot-1-Step-1\\.1 polyline"
  )
})

test_that("BaseRStepLayerProcessor ignores a sibling line layer's grob", {
  # plot(type = "l") + lines(type = "s") puts both a `-lines-` and a `-step-`
  # grob in the same group. Each layer must claim only its own, or the counts
  # stop matching the series counts on both sides.
  layer_info <- step_layer_info(type = "s", fn = "lines")
  layer_info$group_index <- 1
  step_processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)
  line_processor <- maidr:::BaseRLineLayerProcessor$new(layer_info)

  grob <- fake_grob_tree("graphics-plot-1-lines-1", "graphics-plot-1-step-1")

  step_selectors <- step_processor$generate_selectors(layer_info, grob)
  line_selectors <- line_processor$generate_selectors(layer_info, grob)

  testthat::expect_equal(step_selectors, list("#graphics-plot-1-step-1\\.1 polyline"))
  testthat::expect_equal(line_selectors, list("#graphics-plot-1-lines-1\\.1 polyline"))
})

test_that("BaseRStepLayerProcessor selects from the real rendered grob", {
  # Pins the grob-naming assumption to what gridGraphics actually emits, so a
  # rename upstream fails here rather than silently emitting zero selectors.
  testthat::skip_if_not_installed("ggplotify")

  for (type in c("s", "S")) {
    plot_fn <- local({
      t <- type
      function() graphics::plot(1:6, c(1, 3, 3, 5, 2, 2), type = t)
    })
    grDevices::pdf(tempfile(fileext = ".pdf"))
    grob <- ggplotify::as.grob(plot_fn)
    grDevices::dev.off()

    # `index` (1) doubles as the group index here; setting `group_index`
    # without a sibling `group` would make R's partial `$` matching resolve
    # `layer_info$group` to it.
    layer_info <- step_layer_info(type = type, x = 1:6, y = c(1, 3, 3, 5, 2, 2))
    processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

    selectors <- processor$generate_selectors(layer_info, grob)
    data <- processor$extract_data(layer_info)

    testthat::expect_equal(length(selectors), length(data))
    testthat::expect_equal(length(selectors), 1)
  }
})

# ==============================================================================
# Tier 4: Edge cases
# ==============================================================================

test_that("BaseRStepLayerProcessor handles NULL layer_info", {
  processor <- maidr:::BaseRStepLayerProcessor$new(list(index = 1))

  data <- processor$extract_data(NULL)

  testthat::expect_type(data, "list")
  testthat::expect_equal(length(data), 0)
})

test_that("BaseRStepLayerProcessor handles a single-sample step", {
  layer_info <- step_layer_info(x = 1, y = 5)
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 1)
  testthat::expect_equal(length(data[[1]]), 1)
  testthat::expect_equal(data[[1]][[1]]$x, "1")
  testthat::expect_equal(data[[1]][[1]]$y, 5)
})

test_that("BaseRStepLayerProcessor process() on NULL layer_info stays well formed", {
  processor <- maidr:::BaseRStepLayerProcessor$new(list(index = 1))

  result <- processor$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)

  testthat::expect_equal(result$type, "step")
  testthat::expect_equal(length(result$data), 0)
  testthat::expect_false("stepDirection" %in% names(result))
  testthat::expect_silent(maidr:::validate_axes(result$axes))
})

test_that("BaseRStepLayerProcessor honours custom axis() labels", {
  layer_info <- step_layer_info(xlab = "Day", ylab = "Stage")
  layer_info$group <- list(
    low_calls = list(
      list(
        function_name = "axis",
        args = list(1, labels = c("Mon", "Tue", "Wed", "Thu", "Fri"))
      )
    )
  )
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  data <- processor$extract_data(layer_info)

  testthat::expect_equal(data[[1]][[1]]$x, "Mon")
  testthat::expect_equal(data[[1]][[5]]$x, "Fri")
})

test_that("BaseRStepLayerProcessor extracts multi-series step data", {
  x <- c(1, 2, 3)
  y_matrix <- matrix(c(1, 1, 3, 2, 2, 4), nrow = 3, ncol = 2)
  colnames(y_matrix) <- c("Night1", "Night2")

  layer_info <- step_layer_info(x = x, y = y_matrix, fn = "matplot")
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  data <- processor$extract_data(layer_info)

  testthat::expect_equal(length(data), 2)
  testthat::expect_equal(data[[1]][[1]]$z, "Night1")
  testthat::expect_equal(data[[2]][[1]]$z, "Night2")
})

# ==============================================================================
# Tier 5: Payload shape
# ==============================================================================

test_that("A Base R step plot reaches the payload as type 'step'", {
  # Assert on the emitted layer, not on "rendering succeeded": an undetected
  # type = "s" degrades silently to a static, inaccessible PNG.
  plot(1:6, c(1, 3, 3, 5, 2, 2),
    type = "s",
    main = "Steps", xlab = "X", ylab = "Y"
  )

  orchestrator <- maidr:::BaseRPlotOrchestrator$new(grDevices::dev.cur())

  testthat::expect_false(orchestrator$should_fallback())

  layer <- orchestrator$get_combined_data()[[1]][[1]]$layers[[1]]
  testthat::expect_equal(layer$type, "step")
  testthat::expect_equal(layer$stepDirection, "hv")
  testthat::expect_equal(length(layer$data), 1)
  testthat::expect_equal(length(layer$data[[1]]), 6)

  clear_base_r_state()
})

test_that("A positionally supplied type = 's' reaches the payload as step", {
  # `plot()` is patched as `function(...)`, so the recorded call keeps only
  # the names the caller typed and `args$type` is empty for `plot(x, y, "s")`.
  # #113 matches every recorded call against the definition R dispatched to
  # before detection reads it, which is what puts the third argument under
  # `type`. Detection and the payload sit downstream of that, so this pins the
  # seam: reverting the matching sends the layer to "point" and the step
  # reading disappears without any error.
  plot(1:6, c(1, 3, 3, 5, 2, 2), "s", main = "Steps", xlab = "X", ylab = "Y")

  orchestrator <- maidr:::BaseRPlotOrchestrator$new(grDevices::dev.cur())

  testthat::expect_false(orchestrator$should_fallback())

  layer <- orchestrator$get_combined_data()[[1]][[1]]$layers[[1]]
  testthat::expect_equal(layer$type, "step")
  testthat::expect_equal(layer$stepDirection, "hv")
  testthat::expect_equal(length(layer$data[[1]]), 6)
  # One selector, addressing the `-step-` grob rather than the `-lines-` one
  # the inherited line search would look for.
  testthat::expect_equal(length(layer$selectors), 1)
  testthat::expect_match(layer$selectors[[1]], "graphics-plot-1-step-1")

  clear_base_r_state()
})

test_that("A Base R type = 'S' plot reports stepDirection vh", {
  plot(1:4, c(1, 2, 2, 4), type = "S", main = "Steps", xlab = "X", ylab = "Y")

  orchestrator <- maidr:::BaseRPlotOrchestrator$new(grDevices::dev.cur())
  layer <- orchestrator$get_combined_data()[[1]][[1]]$layers[[1]]

  testthat::expect_equal(layer$type, "step")
  testthat::expect_equal(layer$stepDirection, "vh")

  clear_base_r_state()
})

test_that("A Base R step layer payload serialises to JSON", {
  layer_info <- step_layer_info(type = "S", main = "Steps", xlab = "X", ylab = "Y")
  processor <- maidr:::BaseRStepLayerProcessor$new(layer_info)

  result <- processor$process(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, layer_info
  )

  json <- jsonlite::toJSON(result, auto_unbox = TRUE)
  testthat::expect_true(grepl('"type":"step"', json, fixed = TRUE))
  testthat::expect_true(grepl('"stepDirection":"vh"', json, fixed = TRUE))
})
