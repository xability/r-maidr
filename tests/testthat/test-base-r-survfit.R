# plot() of a survival `survfit` object.
#
# survival's plot method draws from inside its own namespace -- plot() with
# type = "n" for the frame, lines() for each staircase and bound, points()
# for the censoring marks -- where maidr's wrappers see none of it, so the
# one call recorded is the reader's `plot(fit)`. Typed by `type` it was an
# empty scatter. It is now read from the object as a `survival` layer: one
# Kaplan-Meier curve per stratum, with its censored times and, when drawn,
# its confidence band.

skip_slow_file_on_cran()
testthat::skip_if_not_installed("survival")

lung <- function() survival::lung

#' Draw `plot_fun` off-screen, save it as a user would, return its layers
survfit_layers <- function(plot_fun) {
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

field <- function(points, name) {
  vapply(points, function(p) if (is.null(p[[name]])) NA_real_ else as.numeric(p[[name]]), 0)
}

test_that("a stratified fit is one survival curve per stratum", {
  fit <- survival::survfit(survival::Surv(time, status) ~ sex, data = lung())
  layers <- survfit_layers(function() plot(fit, main = "Lung", xlab = "Days"))

  testthat::expect_length(layers, 1)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "survival")
  testthat::expect_identical(layer$title, "Lung")
  testthat::expect_identical(layer$axes$x$label, "Days")
  testthat::expect_identical(layer$axes$y$label, "Survival probability")
  testthat::expect_identical(layer$axes$z$label, "Stratum")
  testthat::expect_length(layer$data, 2)
  # No band for several curves unless asked, so one polyline each.
  testthat::expect_identical(
    layer$selectors,
    list(
      "#graphics-plot-1-lines-1\\.1 polyline",
      "#graphics-plot-1-lines-2\\.1 polyline"
    )
  )

  fit0 <- survival::survfit0(fit)
  sizes <- as.integer(fit0$strata)
  for (s in 1:2) {
    points <- layer$data[[s]]
    who <- seq_len(sizes[s]) + c(0, cumsum(sizes))[s]
    # From the origin the plot starts at, through every reported time.
    testthat::expect_equal(field(points, "x"), fit0$time[who])
    testthat::expect_equal(field(points, "y"), fit0$surv[who])
    testthat::expect_true(all(vapply(points, function(p) p$z, "") == names(fit$strata)[s]))
    testthat::expect_identical(
      vapply(points, function(p) isTRUE(p$censored), logical(1)),
      fit0$n.censor[who] > 0
    )
    testthat::expect_true(all(is.na(field(points, "yMin"))))
  }
})

test_that("the confidence band a single curve draws is each point's yMin and yMax", {
  fit <- survival::survfit(survival::Surv(time, status) ~ 1, data = lung())
  layers <- survfit_layers(function() plot(fit))

  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "survival")
  testthat::expect_null(layer$axes$z)
  testthat::expect_identical(layer$axes$x$label, "Time")
  # The curve, not the two bounds drawn after it.
  testthat::expect_identical(layer$selectors, list("#graphics-plot-1-lines-1\\.1 polyline"))

  points <- layer$data[[1]]
  fit0 <- survival::survfit0(fit)
  testthat::expect_null(points[[1]]$z)
  testthat::expect_equal(field(points, "yMin"), fit0$lower)
  testthat::expect_equal(field(points, "yMax"), fit0$upper)
})

test_that("conf.int decides the band, and each stratum's curve is outlined", {
  fit <- survival::survfit(survival::Surv(time, status) ~ sex, data = lung())
  layer <- survfit_layers(function() plot(fit, conf.int = TRUE))[[1]]
  # Curve, lower, upper per stratum: the curves are the first of each three.
  testthat::expect_identical(
    layer$selectors,
    list(
      "#graphics-plot-1-lines-1\\.1 polyline",
      "#graphics-plot-1-lines-4\\.1 polyline"
    )
  )
  testthat::expect_false(anyNA(field(layer$data[[1]], "yMin")))

  single <- survival::survfit(survival::Surv(time, status) ~ 1, data = lung())
  layer <- survfit_layers(function() plot(single, conf.int = FALSE))[[1]]
  testthat::expect_true(all(is.na(field(layer$data[[1]], "yMin"))))
})

test_that("xscale, yscale and xmax read the curve as the axes label it", {
  fit <- survival::survfit(survival::Surv(time, status) ~ 1, data = lung())
  layer <- survfit_layers(function() {
    plot(fit, xscale = 365.25, yscale = 100, xmax = 500, conf.int = FALSE)
  })[[1]]

  points <- layer$data[[1]]
  x <- field(points, "x")
  testthat::expect_equal(max(x), 500 / 365.25)
  testthat::expect_equal(field(points, "y")[1], 100)
  # The cut end holds the level before it and is no censored time.
  n <- length(points)
  testthat::expect_equal(points[[n]]$y, points[[n - 1]]$y)
  testthat::expect_null(points[[n]]$censored)
})

test_that("a drawing that is not a survival curve is declined", {
  fit <- survival::survfit(survival::Surv(time, status) ~ sex, data = lung())
  type_of <- function(...) maidr:::survfit_layer_type(list(fit, ...))

  testthat::expect_identical(type_of(), "survival")
  testthat::expect_identical(type_of(conf.int = TRUE), "survival")
  testthat::expect_identical(type_of(conf.int = 0.95), "survival")
  testthat::expect_identical(type_of(mark.time = TRUE), "survival")
  testthat::expect_identical(type_of(fun = "event"), "unknown")
  testthat::expect_identical(type_of(cumhaz = TRUE), "unknown")
  testthat::expect_identical(type_of(conf.int = "only"), "unknown")
  testthat::expect_identical(type_of(conf.int = 0.9), "unknown")
  testthat::expect_identical(type_of(conf.times = c(100, 200)), "unknown")

  none <- survival::survfit(
    survival::Surv(time, status) ~ 1,
    data = lung(), conf.type = "none"
  )
  # The plot still draws a band for it, from bounds it computes itself.
  testthat::expect_identical(maidr:::survfit_layer_type(list(none)), "unknown")
  testthat::expect_identical(
    maidr:::survfit_layer_type(list(none, conf.int = FALSE)), "survival"
  )
})

test_that("a declined survfit plot is shown as a picture, not an empty scatter", {
  fit <- survival::survfit(survival::Surv(time, status) ~ sex, data = lung())
  layers <- survfit_layers(function() plot(fit, fun = "event"))
  types <- vapply(layers %||% list(), function(l) l$type, "")
  testthat::expect_false(any(types %in% c("point", "survival")))
})
