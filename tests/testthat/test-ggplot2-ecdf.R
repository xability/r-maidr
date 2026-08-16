# `stat_ecdf()` announced nothing at all (#168).
#
# An empirical CDF detected as `unknown` and fell back to the static image,
# even though `step` was already a supported type, the JS core already had a
# step trace, and py-maidr already read `sns.ecdfplot` as one.
#
# It was declined on purpose rather than by oversight, for two reasons that
# both reproduce. `StatEcdf` returns its rows in input order -- `GeomStep`
# only sorts them later, inside `draw_panel()` -- and pads them with `-Inf`
# and `Inf` for the two ends of the staircase. Emitting those rows as built
# would announce an unsorted staircase whose first and last x are infinite.
#
# Both are undone before anything reads the frame, which is what makes the
# stat claimable. The sort is not an imposed order: `ggplot2:::stairstep()`
# opens with `data[order(data$x), ]`, so the sorted rows are literally what
# is drawn.

ecdf_df <- function(n = 20) {
  set.seed(1)
  data.frame(x = stats::rnorm(n), g = rep(c("a", "b"), each = n / 2))
}

detect <- function(plot, index = 1L) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}

series_of <- function(plot) {
  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  for (sp in res$subplots) {
    for (cell in sp) {
      for (ly in cell$layers) {
        if (identical(ly$type, "step")) {
          return(ly$data)
        }
      }
    }
  }
  NULL
}

xs_of <- function(series) as.numeric(vapply(series, function(p) as.character(p$x), ""))
ys_of <- function(series) vapply(series, function(p) as.numeric(p$y), numeric(1))

test_that("an ECDF is read as a step layer rather than declined", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(ecdf_df(), ggplot2::aes(x)) + ggplot2::stat_ecdf()

  testthat::expect_equal(detect(plot), "step")
})

test_that("it emits one point per observation, not the padded rows", {
  testthat::skip_if_not_installed("ggplot2")

  # `StatEcdf` returns n + 2 rows for n observations. The two extras are the
  # conceptual ends of the staircase, not data -- there is no x to announce
  # for either.
  series <- series_of(
    ggplot2::ggplot(ecdf_df(), ggplot2::aes(x)) + ggplot2::stat_ecdf()
  )

  testthat::expect_length(series, 1)
  testthat::expect_length(series[[1]], nrow(ecdf_df()))
})

test_that("no non-finite value reaches the payload", {
  testthat::skip_if_not_installed("ggplot2")

  # The whole emitted structure, not just x: an infinity anywhere is worse
  # than a dropped point in both bindings. `jsonlite` writes it as the
  # *string* "-Inf", and the Python side's `json.dumps` writes a bare
  # `-Infinity` that `JSON.parse` rejects outright.
  res <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(ecdf_df(), ggplot2::aes(x)) + ggplot2::stat_ecdf()
  )$generate_maidr_data()

  non_finite <- 0L
  walk <- function(x) {
    if (is.list(x)) {
      lapply(x, walk)
    } else if (is.numeric(x)) {
      non_finite <<- non_finite + sum(!is.finite(x))
    }
  }
  walk(res)

  testthat::expect_equal(non_finite, 0L)
})

test_that("the samples are in the order the staircase is drawn in", {
  testthat::skip_if_not_installed("ggplot2")

  # Asserted because `StatEcdf` does *not* return them this way, so a pass
  # here cannot come from the input happening to be sorted already.
  frame <- ggplot2::ggplot_build(
    ggplot2::ggplot(ecdf_df(), ggplot2::aes(x)) + ggplot2::stat_ecdf()
  )$data[[1]]
  testthat::expect_true(is.unsorted(frame$x))

  series <- series_of(
    ggplot2::ggplot(ecdf_df(), ggplot2::aes(x)) + ggplot2::stat_ecdf()
  )

  testthat::expect_false(is.unsorted(xs_of(series[[1]])))
})

test_that("the proportions run from 1/n up to 1", {
  testthat::skip_if_not_installed("ggplot2")

  # What makes it an ECDF rather than any other staircase. If the rows had
  # been sorted without the y values travelling with them, this is what
  # would go.
  n <- nrow(ecdf_df())
  ys <- ys_of(
    series_of(ggplot2::ggplot(ecdf_df(), ggplot2::aes(x)) + ggplot2::stat_ecdf())[[1]]
  )

  testthat::expect_false(is.unsorted(ys))
  testthat::expect_equal(ys[[1]], 1 / n)
  testthat::expect_equal(ys[[length(ys)]], 1)
})

test_that("a grouped ECDF is one staircase per group", {
  testthat::skip_if_not_installed("ggplot2")

  # Ordered within group, never globally: `draw_panel()` runs once per group,
  # so a global sort would interleave the two staircases into one series that
  # walks backwards at every seam.
  df <- ecdf_df()
  series <- series_of(
    ggplot2::ggplot(df, ggplot2::aes(x, colour = g)) + ggplot2::stat_ecdf()
  )

  testthat::expect_length(series, 2)
  for (one in series) {
    testthat::expect_length(one, nrow(df) / 2)
    testthat::expect_false(is.unsorted(xs_of(one)))
  }
})

test_that("a hand-written geom_step is unaffected", {
  testthat::skip_if_not_installed("ggplot2")

  # Already-sorted rows are what every `geom_step()` written by hand has, so
  # the reordering has to be a no-op for them.
  df <- data.frame(t = 1:6, v = c(1, 3, 2, 5, 4, 6))
  plot <- ggplot2::ggplot(df, ggplot2::aes(t, v)) + ggplot2::geom_step()
  series <- series_of(plot)

  testthat::expect_equal(detect(plot), "step")
  testthat::expect_length(series[[1]], nrow(df))
  testthat::expect_equal(ys_of(series[[1]]), df$v)
})

test_that("the step direction still travels", {
  testthat::skip_if_not_installed("ggplot2")

  res <- maidr:::Ggplot2PlotOrchestrator$new(
    ggplot2::ggplot(data.frame(t = 1:4, v = c(1, 3, 2, 5)), ggplot2::aes(t, v)) +
      ggplot2::geom_step(direction = "vh")
  )$generate_maidr_data()

  testthat::expect_equal(res$subplots[[1]][[1]]$layers[[1]]$stepDirection, "vh")
})

test_that("a step layer on some other computed stat still declines", {
  testthat::skip_if_not_installed("ggplot2")

  # The gate was relaxed by naming a second stat, not by removing it. A stat
  # whose rows this has not been checked against keeps the static-image
  # fallback rather than being read on a guess.
  plot <- ggplot2::ggplot(ecdf_df(), ggplot2::aes(x)) +
    ggplot2::stat_bin(geom = "step", bins = 5)

  testthat::expect_equal(detect(plot), "unknown")
})

test_that("the reordering leaves a frame whose x is not numeric alone", {
  testthat::skip_if_not_installed("ggplot2")

  # `is.finite()` on a character vector is FALSE throughout, so an unguarded
  # filter would delete every row rather than none.
  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 1))
  built <- list(data = list(
    data.frame(x = c("b", "a"), y = c(2, 1), stringsAsFactors = FALSE)
  ))

  testthat::expect_equal(processor$in_drawn_order(built)$data[[1]], built$data[[1]])
})

test_that("it answers rather than erroring on a layer index it has no frame for", {
  testthat::skip_if_not_installed("ggplot2")

  processor <- maidr:::Ggplot2StepLayerProcessor$new(list(index = 9))
  built <- list(data = list(data.frame(x = 1:3, y = 1:3)))

  testthat::expect_equal(processor$in_drawn_order(built), built)
})
