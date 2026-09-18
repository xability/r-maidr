# A path of rates is a ROC curve when its author says so, or when it says so
# itself.
#
# A receiver operating characteristic curve is drawn with `geom_path()` or
# `geom_line()`, and read as one it says the rates and nothing a ROC curve is
# drawn to say: the area under it, the threshold at each point, how far the
# point sits above chance. The core's `roc` trace says those; what this side
# decides is which paths are curves.
#
# Two answers, measured on ggplot2 3.4.4. `maidr_roc()` is a declaration
# carried by a geom of its own, `GeomRoc`, because a path has no aesthetic
# for a threshold and a geom that names one is the only way a column reaches
# `ggplot_build()`. And two producers name their columns after the rates --
# `pROC::ggroc()` maps `specificity` (or `1-specificity`) against
# `sensitivity`, `autoplot()` of a `yardstick::roc_curve()` maps
# `1 - specificity` against `sensitivity` -- which is a claim in the chart's
# own vocabulary and is read as one. Nothing else is: a `geom_line()` of
# `fpr` against `tpr` keeps the line reading it had, so that every chart
# already written keeps exactly the reading it has.
#
# The tests below assert, in order, that nothing undeclared moved; that a
# declaration is read and its threshold and area travel with the points; that
# the two named idioms are read, with specificity inverted into the rate the
# core measures against; and what a reader receives.

skip_unless_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

#' Two classifiers scored on one test set, with the cutoff behind each point
two_curves <- function() {
  rbind(
    data.frame(
      model = "logistic",
      fpr = c(0, 0.05, 0.1, 0.2, 0.35, 0.6, 1),
      tpr = c(0, 0.55, 0.75, 0.86, 0.93, 0.98, 1),
      cutoff = c(1, 0.8, 0.6, 0.45, 0.3, 0.15, 0)
    ),
    data.frame(
      model = "forest",
      fpr = c(0, 0.1, 0.25, 0.45, 0.7, 1),
      tpr = c(0, 0.4, 0.6, 0.78, 0.9, 1),
      cutoff = c(1, 0.7, 0.5, 0.35, 0.2, 0)
    )
  )
}

one_curve <- function() {
  two_curves()[two_curves()$model == "logistic", ]
}

roc_aes <- ggplot2::aes(x = fpr, y = tpr, threshold = cutoff)

detected <- function(plot, index = 1) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}

processed <- function(plot, index = 1) {
  built <- ggplot2::ggplot_build(plot)
  processor <- maidr:::Ggplot2RocLayerProcessor$new(
    list(index = index, type = "roc")
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
    list("geom_path of fpr and tpr", "line",
      ggplot2::ggplot(curve, ggplot2::aes(fpr, tpr)) + ggplot2::geom_path()),
    list("geom_line of fpr and tpr", "line",
      ggplot2::ggplot(curve, ggplot2::aes(fpr, tpr)) + ggplot2::geom_line()),
    list("a line of sensitivity over time", "line",
      ggplot2::ggplot(data.frame(day = 1:3, sensitivity = c(0.7, 0.8, 0.9)),
        ggplot2::aes(day, sensitivity)) + ggplot2::geom_line()),
    list("a line of specificity alone", "line",
      ggplot2::ggplot(data.frame(specificity = c(0.2, 0.5, 0.9), score = 1:3),
        ggplot2::aes(specificity, score)) + ggplot2::geom_line()),
    list("geom_step of rates", "step",
      ggplot2::ggplot(curve, ggplot2::aes(fpr, tpr)) + ggplot2::geom_step())
  )

  for (fixture in fixtures) {
    testthat::expect_identical(
      detected(fixture[[3]]), fixture[[2]],
      label = fixture[[1]]
    )
  }
})

test_that("a plain path with a threshold mapped is still a line", {
  skip_unless_ggplot2()

  # ggplot2 warns `Ignoring unknown aesthetics` as the layer is built and,
  # measured on 3.4.4, still carries the column through `ggplot_build()`.
  # The column is not the claim: the geom is, and this one is `GeomPath`.
  testthat::expect_warning(
    layer <- ggplot2::geom_path(ggplot2::aes(threshold = cutoff)),
    "threshold"
  )
  plot <- ggplot2::ggplot(one_curve(), ggplot2::aes(fpr, tpr)) + layer
  testthat::expect_identical(detected(plot), "line")
})


# ---------------------------------------------------------------------------
# The declaration
# ---------------------------------------------------------------------------

test_that("maidr_roc() draws what geom_path() draws", {
  skip_unless_ggplot2()

  curve <- one_curve()
  declared <- ggplot2::ggplot(curve) + maidr_roc(ggplot2::aes(x = fpr, y = tpr))
  bare <- ggplot2::ggplot(curve) + ggplot2::geom_path(ggplot2::aes(x = fpr, y = tpr))

  testthat::expect_silent(built_declared <- ggplot2::ggplot_build(declared))
  built_bare <- ggplot2::ggplot_build(bare)

  testthat::expect_identical(built_declared$data[[1]], built_bare$data[[1]])
  testthat::expect_identical(
    built_declared$layout$panel_params[[1]]$x.range,
    built_bare$layout$panel_params[[1]]$x.range
  )
  testthat::expect_identical(class(declared$layers[[1]]$geom)[1], "GeomRoc")
  testthat::expect_identical(detected(declared), "roc")
})

test_that("the threshold aesthetic survives the build and travels per point", {
  skip_unless_ggplot2()

  plot <- ggplot2::ggplot(one_curve()) + maidr_roc(roc_aes)
  testthat::expect_silent(built <- ggplot2::ggplot_build(plot))
  testthat::expect_true("threshold" %in% names(built$data[[1]]))

  result <- processed(plot)
  testthat::expect_identical(result$type, "roc")
  testthat::expect_length(result$data, 1L)

  series <- result$data[[1]]
  testthat::expect_equal(rates_of(series), unname(as.matrix(one_curve()[, c("fpr", "tpr")])))
  testthat::expect_equal(
    vapply(series, function(p) p$threshold, numeric(1)),
    one_curve()$cutoff
  )
  # Numbers, not the strings the line processor announces x as: the core
  # measures the area and the height above chance from them.
  testthat::expect_true(is.numeric(series[[2]]$x))
  testthat::expect_true(is.numeric(series[[2]]$y))
})

test_that("a declared curve without thresholds carries none", {
  skip_unless_ggplot2()

  plot <- ggplot2::ggplot(one_curve()) + maidr_roc(ggplot2::aes(x = fpr, y = tpr))
  series <- processed(plot)$data[[1]]

  testthat::expect_true(all(vapply(series, function(p) is.null(p$threshold), logical(1))))
  testthat::expect_true(is.null(series[[1]]$auc))
})

test_that("several classifiers are several curves, each named and each highlighted", {
  skip_unless_ggplot2()

  plot <- ggplot2::ggplot(two_curves()) +
    maidr_roc(ggplot2::aes(x = fpr, y = tpr, colour = model, threshold = cutoff))
  result <- processed(plot)

  testthat::expect_length(result$data, 2L)
  # Groups are built in the sorted order of the colour column.
  testthat::expect_identical(
    vapply(result$data, function(series) series[[1]]$z, character(1)),
    c("forest", "logistic")
  )
  testthat::expect_identical(vapply(result$data, length, integer(1)), c(6L, 7L))
  testthat::expect_equal(
    vapply(result$data[[2]], function(p) p$threshold, numeric(1)),
    one_curve()$cutoff
  )
  testthat::expect_length(result$selectors, 2L)
  testthat::expect_identical(result$axes$z$label, "model")
})

test_that("a declared area lands on the first point of its curve", {
  skip_unless_ggplot2()

  named <- ggplot2::ggplot(two_curves()) +
    maidr_roc(
      ggplot2::aes(x = fpr, y = tpr, colour = model),
      auc = c(logistic = 0.896, forest = 0.728)
    )
  series <- processed(named)$data
  testthat::expect_identical(series[[1]][[1]]$auc, 0.728)
  testthat::expect_identical(series[[2]][[1]]$auc, 0.896)
  testthat::expect_true(is.null(series[[2]][[2]]$auc))

  # Unnamed, in the groups' sorted order.
  positional <- ggplot2::ggplot(two_curves()) +
    maidr_roc(ggplot2::aes(x = fpr, y = tpr, colour = model), auc = c(0.7, 0.9))
  series <- processed(positional)$data
  testthat::expect_identical(series[[1]][[1]]$auc, 0.7)
  testthat::expect_identical(series[[2]][[1]]$auc, 0.9)

  # One number for one curve.
  single <- ggplot2::ggplot(one_curve()) +
    maidr_roc(ggplot2::aes(x = fpr, y = tpr), auc = 0.896)
  testthat::expect_identical(processed(single)$data[[1]][[1]]$auc, 0.896)

  # A count that matches nothing is left out rather than guessed.
  mismatched <- ggplot2::ggplot(two_curves()) +
    maidr_roc(ggplot2::aes(x = fpr, y = tpr, colour = model), auc = 0.8)
  series <- processed(mismatched)$data
  testthat::expect_true(is.null(series[[1]][[1]]$auc))
  testthat::expect_true(is.null(series[[2]][[1]]$auc))
})

test_that("auc is checked at the declaration", {
  skip_unless_ggplot2()

  testthat::expect_error(maidr_roc(roc_aes, auc = "high"), "numeric")
  testthat::expect_error(maidr_roc(roc_aes, auc = NA_real_), "missing")
  testthat::expect_silent(maidr_roc(roc_aes, auc = NULL))
})

test_that("the declaration survives a wrapper and do.call()", {
  skip_unless_ggplot2()

  wrapped <- function(...) maidr_roc(...)
  for (layer in list(
    wrapped(roc_aes, auc = 0.5),
    do.call(maidr_roc, list(roc_aes, auc = 0.5)),
    maidr::maidr_roc(roc_aes, auc = 0.5)
  )) {
    plot <- ggplot2::ggplot(one_curve()) + layer
    testthat::expect_identical(detected(plot), "roc")
    testthat::expect_identical(processed(plot)$data[[1]][[1]]$auc, 0.5)
  }
})


# ---------------------------------------------------------------------------
# The idioms read without a declaration
# ---------------------------------------------------------------------------

test_that("pROC::ggroc() is read, with specificity inverted into the rate", {
  skip_unless_ggplot2()
  testthat::skip_if_not_installed("pROC")

  data("aSAH", package = "pROC")
  roc <- pROC::roc(aSAH$outcome, aSAH$s100b, quiet = TRUE)
  plot <- pROC::ggroc(roc)

  testthat::expect_identical(detected(plot), "roc")

  result <- processed(plot)
  testthat::expect_identical(result$type, "roc")
  testthat::expect_length(result$data, 1L)
  rates <- rates_of(result$data[[1]])

  # ggroc draws specificity on a reversed axis, which is the same picture
  # as the false positive rate on an ordinary one. The rate is what is
  # announced, under a name that says so.
  coords <- pROC::coords(roc, "all", transpose = FALSE)
  testthat::expect_equal(sort(rates[, 1]), sort(1 - coords$specificity))
  testthat::expect_equal(sort(rates[, 2]), sort(coords$sensitivity))
  testthat::expect_true(all(rates >= 0 & rates <= 1))
  testthat::expect_identical(result$axes$x$label, "1 - specificity")
  testthat::expect_identical(result$axes$y$label, "sensitivity")
  testthat::expect_true(is.null(result$data[[1]][[1]]$threshold))
})

test_that("pROC::ggroc(legacy.axes = TRUE) is read as the rate it maps", {
  skip_unless_ggplot2()
  testthat::skip_if_not_installed("pROC")

  data("aSAH", package = "pROC")
  roc <- pROC::roc(aSAH$outcome, aSAH$s100b, quiet = TRUE)
  plot <- pROC::ggroc(roc, legacy.axes = TRUE)

  testthat::expect_identical(detected(plot), "roc")
  result <- processed(plot)
  coords <- pROC::coords(roc, "all", transpose = FALSE)
  testthat::expect_equal(sort(rates_of(result$data[[1]])[, 1]), sort(1 - coords$specificity))
  testthat::expect_identical(result$axes$x$label, "1-specificity")
})

test_that("a list of pROC curves is one chart of several curves", {
  skip_unless_ggplot2()
  testthat::skip_if_not_installed("pROC")

  data("aSAH", package = "pROC")
  curves <- list(
    s100b = pROC::roc(aSAH$outcome, aSAH$s100b, quiet = TRUE),
    ndka = pROC::roc(aSAH$outcome, aSAH$ndka, quiet = TRUE)
  )
  plot <- pROC::ggroc(curves)

  testthat::expect_identical(detected(plot), "roc")
  result <- processed(plot)
  testthat::expect_length(result$data, 2L)
  testthat::expect_setequal(
    vapply(result$data, function(series) series[[1]]$z, character(1)),
    c("s100b", "ndka")
  )
  testthat::expect_length(result$selectors, 2L)
})

test_that("autoplot() of a yardstick roc_curve() is read, and its diagonal skipped", {
  skip_unless_ggplot2()
  testthat::skip_if_not_installed("yardstick")

  curve <- yardstick::roc_curve(yardstick::two_class_example, truth, Class1)
  plot <- ggplot2::autoplot(curve)

  testthat::expect_identical(detected(plot, 1), "roc")
  testthat::expect_identical(detected(plot, 2), "skip")

  result <- processed(plot)
  rates <- rates_of(result$data[[1]])
  testthat::expect_equal(sort(rates[, 1]), sort(1 - curve$specificity))
  testthat::expect_equal(sort(rates[, 2]), sort(curve$sensitivity))
  testthat::expect_identical(result$axes$x$label, "1 - specificity")
})


# ---------------------------------------------------------------------------
# What a reader receives
# ---------------------------------------------------------------------------

test_that("a declared chart keeps its interactivity and carries the trace", {
  skip_if_no_render()

  plot <- ggplot2::ggplot(two_curves()) +
    maidr_roc(
      ggplot2::aes(x = fpr, y = tpr, colour = model, threshold = cutoff),
      auc = c(logistic = 0.896, forest = 0.728)
    ) +
    ggplot2::geom_abline(linetype = "dashed") +
    ggplot2::labs(x = "False positive rate", y = "True positive rate")

  html <- rendered(plot)
  testthat::expect_false(fell_back(html))

  layers <- layers_from(html)
  # The diagonal is skipped, so the chart is the one ROC layer.
  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "roc")
  testthat::expect_length(layer$data, 2L)
  testthat::expect_identical(layer$data[[2]][[1]]$z, "logistic")
  testthat::expect_identical(layer$data[[2]][[1]]$auc, 0.896)
  testthat::expect_identical(layer$data[[2]][[4]]$threshold, 0.45)
  testthat::expect_true(is.numeric(layer$data[[2]][[4]]$x))

  # A selector naming nothing is the highlight-only blind spot
  # xability/maidr#814 describes, so each id is looked for in the export.
  testthat::expect_length(layer$selectors, 2L)
  for (selector in unlist(layer$selectors)) {
    id <- gsub("\\\\", "", sub("^#", "", selector))
    testthat::expect_true(grepl(paste0('id="', id, '"'), html, fixed = TRUE))
  }
})

test_that("a ggroc chart renders as a ROC layer", {
  skip_if_no_render()
  testthat::skip_if_not_installed("pROC")

  data("aSAH", package = "pROC")
  plot <- pROC::ggroc(pROC::roc(aSAH$outcome, aSAH$s100b, quiet = TRUE))

  html <- rendered(plot)
  testthat::expect_false(fell_back(html))
  layer <- layers_from(html)[[1]]
  testthat::expect_identical(layer$type, "roc")
  testthat::expect_identical(layer$axes$x$label, "1 - specificity")
  testthat::expect_true(is.numeric(layer$data[[1]][[2]]$x))
})
