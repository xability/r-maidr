# A path of rates is a precision-recall curve when its author says so, or
# when it says so itself.
#
# Read as a line, a precision-recall curve says the rates and nothing it is
# drawn to say: how far each point's precision sits above the share of
# positives, the average precision, the threshold at each point. The core's
# `pr_curve` trace says those; what this side decides is which paths are
# curves, the way `test-roc.R` decides it for ROC curves.
#
# Two answers. `maidr_pr_curve()` is a declaration carried by a geom of its
# own, `GeomPrCurve`, which also lets a `threshold` column through
# `ggplot_build()`, and which takes the share of positives and the average
# precision as arguments. And `autoplot()` of a `yardstick::pr_curve()` maps
# columns named after the rates, `recall` against `precision`, which is read
# as the claim it is. Nothing else is.

skip_slow_file_on_cran()

skip_unless_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

#' Two classifiers scored on one test set, with the cutoff behind each point
two_curves <- function() {
  rbind(
    data.frame(
      model = "logistic",
      rec = c(0, 0.2, 0.4, 0.6, 0.8, 1),
      prec = c(1, 1, 0.89, 0.8, 0.62, 0.3),
      cutoff = c(1, 0.9, 0.75, 0.6, 0.4, 0)
    ),
    data.frame(
      model = "forest",
      rec = c(0, 0.25, 0.5, 0.75, 1),
      prec = c(1, 0.83, 0.71, 0.55, 0.3),
      cutoff = c(1, 0.8, 0.55, 0.3, 0)
    )
  )
}

one_curve <- function() {
  two_curves()[two_curves()$model == "logistic", ]
}

pr_aes <- ggplot2::aes(x = rec, y = prec, threshold = cutoff)

#' Read a layer's type with the `pr_curve` trace available, whatever the
#' bundle
detected <- function(plot, index = 1) {
  testthat::local_mocked_bindings(pr_curve_trace_available = function() TRUE)
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}

processed <- function(plot, index = 1) {
  built <- ggplot2::ggplot_build(plot)
  processor <- maidr:::Ggplot2PrCurveLayerProcessor$new(
    list(index = index, type = "pr_curve")
  )
  processor$process(plot, built$layout, built, ggplot2::ggplotGrob(plot))
}

#' The (x, y) pairs of one emitted series
rates_of <- function(series) {
  t(vapply(series, function(p) c(p$x, p$y), numeric(2)))
}


# ---------------------------------------------------------------------------
# Nothing undeclared moved
# ---------------------------------------------------------------------------

test_that("a path of rates under other names keeps the line reading", {
  skip_unless_ggplot2()

  curve <- one_curve()
  fixtures <- list(
    list("geom_path of rec and prec", "line",
      ggplot2::ggplot(curve, ggplot2::aes(rec, prec)) + ggplot2::geom_path()),
    list("a line of precision over time", "line",
      ggplot2::ggplot(data.frame(day = 1:3, precision = c(0.7, 0.8, 0.9)),
        ggplot2::aes(day, precision)) + ggplot2::geom_line()),
    list("precision against recall the other way round", "line",
      ggplot2::ggplot(data.frame(precision = c(1, 0.8), recall = c(0, 1)),
        ggplot2::aes(precision, recall)) + ggplot2::geom_line()),
    list("geom_step of recall and precision", "step",
      ggplot2::ggplot(data.frame(recall = c(0, 1), precision = c(1, 0.5)),
        ggplot2::aes(recall, precision)) + ggplot2::geom_step())
  )

  for (fixture in fixtures) {
    testthat::expect_identical(
      detected(fixture[[3]]), fixture[[2]],
      label = fixture[[1]]
    )
  }
})

test_that("a bundle without the trace keeps the line reading, declared or detected", {
  skip_unless_ggplot2()
  testthat::local_mocked_bindings(pr_curve_trace_available = function() FALSE)
  adapter <- maidr:::Ggplot2Adapter$new()

  declared <- ggplot2::ggplot(one_curve()) + maidr_pr_curve(pr_aes)
  named <- ggplot2::ggplot(
    data.frame(recall = c(0, 1), precision = c(1, 0.5)),
    ggplot2::aes(recall, precision)
  ) + ggplot2::geom_path()

  testthat::expect_identical(
    adapter$detect_layer_type(declared$layers[[1]], declared), "line"
  )
  testthat::expect_identical(
    adapter$detect_layer_type(named$layers[[1]], named), "line"
  )
})

test_that("the gate reads the pinned bundle version", {
  testthat::expect_identical(
    maidr:::pr_curve_trace_available(),
    utils::compareVersion(maidr:::MAIDR_VERSION, "4.14.0") >= 0
  )
})

test_that("the processor is registered for the type", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  testthat::expect_true("pr_curve" %in% factory$get_supported_types())
  testthat::expect_s3_class(
    factory$create_processor("pr_curve", list(index = 1, type = "pr_curve")),
    "Ggplot2PrCurveLayerProcessor"
  )
})


# ---------------------------------------------------------------------------
# The declaration
# ---------------------------------------------------------------------------

test_that("maidr_pr_curve() draws what geom_path() draws", {
  skip_unless_ggplot2()

  declared <- ggplot2::ggplot(one_curve()) + maidr_pr_curve(pr_aes)
  plain <- ggplot2::ggplot(one_curve()) +
    ggplot2::geom_path(ggplot2::aes(x = rec, y = prec))

  testthat::expect_identical(detected(declared), "pr_curve")
  testthat::expect_s3_class(declared$layers[[1]]$geom, "GeomPath")
  testthat::expect_equal(
    ggplot2::layer_data(declared)[, c("x", "y")],
    ggplot2::layer_data(plain)[, c("x", "y")]
  )
})

test_that("the threshold aesthetic survives the build and travels per point", {
  skip_unless_ggplot2()

  plot <- ggplot2::ggplot(one_curve()) + maidr_pr_curve(pr_aes)
  result <- processed(plot)

  testthat::expect_identical(result$type, "pr_curve")
  series <- result$data[[1]]
  testthat::expect_equal(
    vapply(series, function(p) p$threshold, numeric(1)),
    one_curve()$cutoff
  )
  testthat::expect_equal(rates_of(series)[, 1], one_curve()$rec)
  testthat::expect_true(is.numeric(series[[2]]$x))
})

test_that("one share of positives lands on every curve; ap matched by name", {
  skip_unless_ggplot2()

  plot <- ggplot2::ggplot(two_curves()) +
    maidr_pr_curve(
      ggplot2::aes(x = rec, y = prec, colour = model, threshold = cutoff),
      prevalence = 0.3,
      ap = c(logistic = 0.81, forest = 0.66)
    )
  result <- processed(plot)

  by_name <- stats::setNames(
    result$data, vapply(result$data, function(s) s[[1]]$z, character(1))
  )
  testthat::expect_setequal(names(by_name), c("logistic", "forest"))
  testthat::expect_identical(by_name$logistic[[1]]$prevalence, 0.3)
  testthat::expect_identical(by_name$forest[[1]]$prevalence, 0.3)
  testthat::expect_identical(by_name$logistic[[1]]$ap, 0.81)
  testthat::expect_identical(by_name$forest[[1]]$ap, 0.66)
  for (series in result$data) {
    testthat::expect_null(series[[2]]$prevalence)
    testthat::expect_null(series[[2]]$ap)
  }
  testthat::expect_length(result$selectors, 2L)
})

test_that("a declaration without the numbers carries none of them", {
  skip_unless_ggplot2()

  result <- processed(ggplot2::ggplot(one_curve()) + maidr_pr_curve(pr_aes))
  testthat::expect_null(result$data[[1]][[1]]$prevalence)
  testthat::expect_null(result$data[[1]][[1]]$ap)
})

test_that("a vector of the wrong length is left out rather than guessed", {
  skip_unless_ggplot2()

  plot <- ggplot2::ggplot(two_curves()) +
    maidr_pr_curve(
      ggplot2::aes(x = rec, y = prec, colour = model),
      prevalence = c(0.3, 0.4, 0.5)
    )
  result <- processed(plot)
  for (series in result$data) {
    testthat::expect_null(series[[1]]$prevalence)
  }
})

test_that("prevalence and ap are checked at the declaration", {
  testthat::expect_error(maidr_pr_curve(prevalence = 1.5), "prevalence")
  testthat::expect_error(maidr_pr_curve(prevalence = "a"), "prevalence")
  testthat::expect_error(maidr_pr_curve(ap = NA_real_), "ap")
  testthat::expect_error(maidr_pr_curve(ap = -0.1), "ap")
})


# ---------------------------------------------------------------------------
# A producer that names its rates
# ---------------------------------------------------------------------------

test_that("autoplot() of a yardstick pr_curve() is read", {
  skip_unless_ggplot2()
  testthat::skip_if_not_installed("yardstick")

  curve <- yardstick::pr_curve(yardstick::two_class_example, truth, Class1)
  plot <- ggplot2::autoplot(curve)

  testthat::expect_identical(detected(plot, 1), "pr_curve")

  result <- processed(plot)
  rates <- rates_of(result$data[[1]])
  testthat::expect_equal(sort(rates[, 1]), sort(curve$recall))
  testthat::expect_equal(sort(rates[, 2]), sort(curve$precision))
  testthat::expect_identical(result$axes$x$label, "recall")
})

test_that("a grouped yardstick pr_curve() is one chart of several curves", {
  skip_unless_ggplot2()
  testthat::skip_if_not_installed("yardstick")
  testthat::skip_if_not_installed("dplyr")

  example <- yardstick::two_class_example
  scored <- rbind(
    transform(example, model = "a", score = Class1),
    transform(example, model = "b", score = rev(Class1))
  )
  curve <- yardstick::pr_curve(dplyr::group_by(scored, model), truth, score)
  plot <- ggplot2::autoplot(curve)

  testthat::expect_identical(detected(plot, 1), "pr_curve")
  testthat::expect_length(processed(plot)$data, 2L)
})


# ---------------------------------------------------------------------------
# What a reader receives
# ---------------------------------------------------------------------------

test_that("a declared chart renders as a line while the bundle lacks the trace", {
  skip_if_no_render()
  testthat::local_mocked_bindings(pr_curve_trace_available = function() FALSE)

  plot <- ggplot2::ggplot(two_curves()) +
    maidr_pr_curve(ggplot2::aes(x = rec, y = prec, colour = model))

  html <- rendered(plot)
  testthat::expect_false(fell_back(html))
  layer <- layers_from(html)[[1]]
  testthat::expect_identical(layer$type, "line")
  testthat::expect_length(layer$data, 2L)
})

test_that("a declared chart keeps its interactivity and carries the trace", {
  skip_if_no_render()
  testthat::local_mocked_bindings(pr_curve_trace_available = function() TRUE)

  plot <- ggplot2::ggplot(two_curves()) +
    maidr_pr_curve(
      ggplot2::aes(x = rec, y = prec, colour = model, threshold = cutoff),
      prevalence = 0.3
    ) +
    ggplot2::geom_hline(yintercept = 0.3, linetype = "dashed") +
    ggplot2::labs(x = "Recall", y = "Precision")

  html <- rendered(plot)
  testthat::expect_false(fell_back(html))

  layers <- layers_from(html)
  # The baseline is a reference line and is skipped, so the chart is the one
  # PR layer.
  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "pr_curve")
  testthat::expect_length(layer$data, 2L)
  testthat::expect_identical(layer$data[[1]][[1]]$prevalence, 0.3)
  testthat::expect_true(is.numeric(layer$data[[1]][[3]]$threshold))

  testthat::expect_length(layer$selectors, 2L)
  for (selector in unlist(layer$selectors)) {
    id <- gsub("\\\\", "", sub("^#", "", selector))
    testthat::expect_true(grepl(paste0('id="', id, '"'), html, fixed = TRUE))
  }
})

test_that("a yardstick chart renders as a PR layer", {
  skip_if_no_render()
  testthat::local_mocked_bindings(pr_curve_trace_available = function() TRUE)
  testthat::skip_if_not_installed("yardstick")

  curve <- yardstick::pr_curve(yardstick::two_class_example, truth, Class1)
  html <- rendered(ggplot2::autoplot(curve))
  testthat::expect_false(fell_back(html))
  layer <- layers_from(html)[[1]]
  testthat::expect_identical(layer$type, "pr_curve")
  testthat::expect_true(is.numeric(layer$data[[1]][[2]]$x))
})
