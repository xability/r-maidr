# plot() of a ROCR `performance` object.
#
# ROCR's plot method draws from inside its own namespace -- plot.xy() for the
# curve, axis() and box() for the frame -- where maidr's wrappers see none of
# it, so the one call recorded is the reader's `plot(perf)`. Typed by `type`
# it was an empty scatter. It is now read from the object: a
# precision-recall curve, titled "Recall" and "Precision" by ROCR, as a
# `pr_curve` layer with each point's cutoff, anything else ROCR plots as a
# line.

skip_slow_file_on_cran()
testthat::skip_if_not_installed("ROCR")

rocr_prediction <- function() {
  env <- new.env()
  utils::data("ROCR.simple", package = "ROCR", envir = env)
  ROCR::prediction(env$ROCR.simple$predictions, env$ROCR.simple$labels)
}

#' Draw `plot_fun` off-screen, save it as a user would, return its layers
rocr_layers <- function(plot_fun) {
  testthat::skip_if_not_installed("jsonlite")
  maidr:::clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(
    {
      grDevices::dev.off()
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )
  plot_fun()
  suppressWarnings(suppressMessages(maidr::save_html(plot = NULL, file = file)))
  layers_from(paste(readLines(file, warn = FALSE), collapse = "\n"))
}

test_that("plot(performance(pred, 'prec', 'rec')) is a precision-recall curve", {
  perf <- ROCR::performance(rocr_prediction(), "prec", "rec")
  layers <- rocr_layers(function() plot(perf))

  testthat::expect_length(layers, 1)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "pr_curve")
  testthat::expect_identical(layer$axes$x$label, "Recall")
  testthat::expect_identical(layer$axes$y$label, "Precision")
  testthat::expect_identical(layer$selectors, list("#graphics-plot-1-lines-1\\.1 polyline"))

  # The points ROCR draws: every finite pair, in its order. The first,
  # recall 0 at an infinite cutoff, has no precision and is not drawn.
  x <- perf@x.values[[1]]
  y <- perf@y.values[[1]]
  drawn <- is.finite(x) & is.finite(y)
  points <- layer$data[[1]]
  testthat::expect_length(points, sum(drawn))
  testthat::expect_equal(vapply(points, function(p) p$x, 0), x[drawn])
  testthat::expect_equal(vapply(points, function(p) p$y, 0), y[drawn])

  # Each with the cutoff it was scored at.
  testthat::expect_equal(
    vapply(points, function(p) p$threshold, 0),
    perf@alpha.values[[1]][drawn]
  )
})

test_that("an infinite cutoff is left out rather than written", {
  perf <- ROCR::performance(rocr_prediction(), "prec", "rec")
  perf@y.values[[1]][1] <- 1 # draw the point scored at the infinite cutoff
  layers <- rocr_layers(function() plot(perf))

  first <- layers[[1]]$data[[1]][[1]]
  testthat::expect_equal(first$x, 0)
  testthat::expect_null(first$threshold)
  testthat::expect_false(is.null(layers[[1]]$data[[1]][[2]]$threshold))
})

test_that("titles given to plot() are the ones read", {
  perf <- ROCR::performance(rocr_prediction(), "prec", "rec")
  layers <- rocr_layers(function() {
    plot(perf, main = "Classifier", xlab = "Sensitivity")
  })

  testthat::expect_identical(layers[[1]]$title, "Classifier")
  testthat::expect_identical(layers[[1]]$axes$x$label, "Sensitivity")
  # No longer titled Recall, so no longer claimed as a precision-recall curve.
  testthat::expect_identical(layers[[1]]$type, "line")
  testthat::expect_null(layers[[1]]$data[[1]][[1]]$threshold)
})

test_that("each run of a cross-validated performance is a curve of its own", {
  env <- new.env()
  utils::data("ROCR.xval", package = "ROCR", envir = env)
  pred <- ROCR::prediction(env$ROCR.xval$predictions, env$ROCR.xval$labels)
  perf <- ROCR::performance(pred, "prec", "rec")
  layers <- rocr_layers(function() plot(perf))

  runs <- length(perf@x.values)
  testthat::expect_identical(layers[[1]]$type, "pr_curve")
  testthat::expect_length(layers[[1]]$data, runs)
  testthat::expect_length(layers[[1]]$selectors, runs)
  testthat::expect_identical(
    vapply(layers[[1]]$data, function(series) series[[1]]$z, ""),
    paste("Run", seq_len(runs))
  )
})

test_that("a ROC curve, or any other measure ROCR plots, is a line", {
  perf <- ROCR::performance(rocr_prediction(), "tpr", "fpr")
  layers <- rocr_layers(function() plot(perf))

  testthat::expect_identical(layers[[1]]$type, "line")
  testthat::expect_identical(layers[[1]]$axes$x$label, "False positive rate")
  testthat::expect_identical(layers[[1]]$axes$y$label, "True positive rate")
  testthat::expect_length(layers[[1]]$selectors, 1)
})

test_that("a drawing that is not one polyline per run is declined", {
  perf <- ROCR::performance(rocr_prediction(), "prec", "rec")
  type_of <- function(...) maidr:::rocr_performance_layer_type(list(perf, ...))

  testthat::expect_identical(type_of(), "rocr_performance")
  testthat::expect_identical(type_of(avg = "none"), "rocr_performance")
  testthat::expect_identical(type_of(type = "l"), "rocr_performance")
  testthat::expect_identical(type_of(colorize = TRUE), "unknown")
  testthat::expect_identical(type_of(avg = "vertical"), "unknown")
  testthat::expect_identical(type_of(add = TRUE), "unknown")
  testthat::expect_identical(type_of(downsampling = 0.5), "unknown")
  testthat::expect_identical(type_of(type = "p"), "unknown")
})

test_that("only a ROCR performance object is taken for one", {
  perf <- ROCR::performance(rocr_prediction(), "prec", "rec")
  testthat::expect_true(maidr:::is_rocr_performance(perf))
  testthat::expect_false(maidr:::is_rocr_performance(list(x.values = list(1))))
  testthat::expect_false(maidr:::is_rocr_performance(1:3))
})

test_that("ROCR attached ahead of maidr is named as masking plot()", {
  testthat::skip_if_not("package:maidr" %in% search())
  testthat::skip_if("package:ROCR" %in% search())

  # Search-path order is fixed at library() time; a stand-in frame of ROCR's
  # name ahead of maidr reproduces what the diagnostics key off.
  attach(list(), name = "package:ROCR", warn.conflicts = FALSE)
  on.exit(detach("package:ROCR", character.only = TRUE), add = TRUE)

  testthat::expect_true("ROCR" %in% maidr:::packages_masking_maidr())
  msg <- maidr:::no_base_r_plots_message()
  testthat::expect_match(msg, "'ROCR' is attached ahead of 'maidr'")
  testthat::expect_match(msg, "maidr::plot()", fixed = TRUE)
})
