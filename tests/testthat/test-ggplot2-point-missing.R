# A scatter emitted a sample ggplot2 never drew (#170).
#
# ggplot2 discards a point whose position or value is missing before it
# renders, and says so out loud -- "Removed 1 rows containing missing values
# (`geom_point()`)". The processor kept it, so `data` came out longer than the
# marks the selector resolves to.
#
# Measured on four rows with one NA: 4 points emitted against 3 `<use>`
# elements. The selector pairs them in order, so every sample from the gap
# onward is highlighted at the *next* observation's mark and the last has none
# left. That is worse than a missing point: a reader is shown a mark that does
# not correspond to the value being announced, and nothing says so.
#
# `Ggplot2LineLayerProcessor$extract_data()` already drops NA-y rows for
# exactly this reason and documents it. This brings the point processor into
# line with the rule its sibling already follows.

gap_df <- function() {
  data.frame(
    x = c(1, 2, 3, 4),
    y = c(1, NA, 3, 4),
    g = c("a", "b", "a", "b")
  )
}

points_of <- function(plot) {
  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  for (sp in res$subplots) {
    for (cell in sp) {
      for (ly in cell$layers) {
        if (identical(ly$type, "point")) {
          return(ly$data)
        }
      }
    }
  }
  NULL
}

drawn_count <- function(plot) {
  frame <- ggplot2::ggplot_build(plot)$data[[1]]
  sum(is.finite(frame$x) & is.finite(frame$y))
}

test_that("it emits exactly as many samples as ggplot2 draws", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(gap_df(), ggplot2::aes(x, y)) + ggplot2::geom_point()

  testthat::expect_equal(length(points_of(plot)), drawn_count(plot))
})

test_that("the sample it drops is the one with no value", {
  testthat::skip_if_not_installed("ggplot2")

  # Asserted on which rows survive, not just how many: dropping the wrong one
  # would keep the count right and the reading wrong.
  plot <- ggplot2::ggplot(gap_df(), ggplot2::aes(x, y)) + ggplot2::geom_point()
  xs <- vapply(points_of(plot), function(p) as.numeric(p$x), numeric(1))

  testthat::expect_equal(xs, c(1, 3, 4))
})

test_that("no sample carries a missing value through", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(gap_df(), ggplot2::aes(x, y)) + ggplot2::geom_point()

  for (point in points_of(plot)) {
    testthat::expect_true(is.finite(as.numeric(point$y)))
  }
})

test_that("a missing x is dropped as well as a missing y", {
  testthat::skip_if_not_installed("ggplot2")

  # ggplot2 removes either, so reading only y would leave the same mismatch
  # for a chart whose x is the incomplete column.
  df <- data.frame(x = c(1, NA, 3), y = c(1, 2, 3))
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y)) + ggplot2::geom_point()

  testthat::expect_equal(length(points_of(plot)), 2)
})

test_that("a mapped aesthetic still lines up with the samples that survive", {
  testthat::skip_if_not_installed("ggplot2")

  # The row indices are what the colour/group lookups index the original frame
  # through, so filtering the data without filtering them in step would shift
  # every series name by the number of dropped rows -- trading a wrong
  # highlight for a wrong legend.
  plot <- ggplot2::ggplot(gap_df(), ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_point()
  points <- points_of(plot)

  testthat::expect_equal(length(points), drawn_count(plot))

  # Row 2 (g = "b") is the dropped one, so the survivors carry a, a, b in x
  # order. Asserted unconditionally and on the key the payload really uses:
  # an earlier version read `fill`, which a `colour` mapping never sets, and
  # guarded the comparison behind "if any are present" -- so it passed with
  # the row indices left unfiltered, which is the very thing it is here to
  # catch.
  testthat::expect_equal(
    vapply(points, function(p) as.character(p$color), character(1)),
    c("a", "a", "b")
  )
})

test_that("a scatter with nothing missing is unchanged", {
  testthat::skip_if_not_installed("ggplot2")

  df <- data.frame(x = 1:5, y = c(2, 4, 6, 8, 10))
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y)) + ggplot2::geom_point()
  points <- points_of(plot)

  testthat::expect_equal(length(points), nrow(df))
  testthat::expect_equal(
    vapply(points, function(p) as.numeric(p$y), numeric(1)),
    df$y
  )
})

test_that("a faceted scatter drops only its own panel's missing sample", {
  testthat::skip_if_not_installed("ggplot2")

  # The panel filter and this one both narrow the same frame, so they have to
  # compose rather than one undoing the other.
  df <- data.frame(
    x = c(1, 2, 3, 4),
    y = c(1, NA, 3, 4),
    panel = c("p", "p", "q", "q")
  )
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~panel)

  res <- maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
  counts <- c()
  for (sp in res$subplots) {
    for (cell in sp) {
      for (ly in cell$layers) {
        counts <- c(counts, length(ly$data))
      }
    }
  }

  # Panel "p" keeps one of its two samples; panel "q" keeps both.
  testthat::expect_equal(sort(counts), c(1, 2))
})
