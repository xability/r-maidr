# A dot plot is a histogram drawn one dot per observation (issue #201)
#
# `geom_dotplot()` bins its values and stacks a dot per observation, so a
# stack's height *is* the bin's count. It reached MAIDR as nothing at all --
# not a mis-typed layer but no layer, because `should_fallback()` fired on the
# unclassified geom and the whole chart went out as an `<img>`:
#
#   geom_dotplot     svg=FALSE  maidr-data=FALSE  img=TRUE
#   geom_histogram   svg=TRUE   maidr-data=TRUE   img=FALSE
#
# on the same data. `GeomDotplot` is a direct `Geom` subclass, so the
# class-name match found nothing -- the same shape of miss `GeomRaster` was in
# #193, where the fix was likewise the name rather than the reading.
#
# The reading needs no reconstruction. `ggplot_build()` returns one row per
# observation carrying its bin centre, the bin width, and the bin's count, so
# collapsing on the centre gives the histogram directly.
#
# What does NOT transfer is highlighting, asserted below rather than left to be
# discovered. The layer draws one `dotstackGrob`, which gridSVG exports as one
# `<circle>` per observation: a bin of three dots has three elements and no
# element of its own, while the frontend's bar traces resolve exactly one per
# announced value. So the bins are announced and nothing lights up -- the
# highlight-only blind spot xability/maidr#814 names, and strictly better than
# the picture this chart was before.

skip_if_no_render <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("jsonlite")
}

#: Lopsided counts, so a transposed or mis-collapsed reading cannot pass by
#: symmetry, and one bin of one so an off-by-one on the bounds shows.
DOTS <- c(1, 1, 1, 2, 2, 3, 4, 4, 4, 4)

dot_frame <- function() data.frame(v = DOTS)

#' Render a plot and return the one layer it emits, or NULL when it emits none
dot_layer <- function(plot) {
  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(html, regexpr('maidr-data="[^"]*"', html))
  if (length(raw) != 1) {
    return(NULL)
  }
  json <- sub('"$', "", sub('^maidr-data="', "", raw))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers[[1]]
}

counts_of <- function(layer, field = "y") {
  vapply(layer$data, function(point) as.numeric(point[[field]]), numeric(1))
}

test_that("a dot plot reaches the dot plot processor at all", {
  testthat::skip_if_not_installed("ggplot2")

  # Upstream of everything else in this file and asked without rendering, for
  # the reason `test-raster-heatmap.R` gives: a regression here would
  # otherwise surface as four failures about bins rather than one about the
  # branch that broke.
  adapter <- maidr:::Ggplot2Adapter$new()
  plot <- ggplot2::ggplot(dot_frame(), ggplot2::aes(v)) +
    ggplot2::geom_dotplot(binwidth = 1)

  testthat::expect_equal(
    adapter$detect_layer_type(plot$layers[[1]], plot), "dotplot"
  )
})

test_that("a dot plot is a chart rather than a picture", {
  skip_if_no_render()

  # The defect itself. Not "reads as the wrong type" -- reads as nothing, with
  # the whole figure replaced by an image, so this asserts a layer exists and
  # is the histogram it draws before anything asks what is in it.
  plot <- ggplot2::ggplot(dot_frame(), ggplot2::aes(v)) +
    ggplot2::geom_dotplot(binwidth = 1)

  layer <- dot_layer(plot)

  testthat::expect_false(is.null(layer))
  testthat::expect_equal(layer$type, "hist")
})

test_that("a dot plot and a histogram announce the same distribution", {
  skip_if_no_render()

  # Asserted against the other spelling rather than against literals, because
  # what was wrong was the disagreement: one way of drawing a distribution was
  # navigable and the other was an image. `boundary` lines the two binnings up
  # -- `geom_dotplot` centres its bins on the data, `geom_histogram` does not.
  dots <- dot_layer(
    ggplot2::ggplot(dot_frame(), ggplot2::aes(v)) +
      ggplot2::geom_dotplot(binwidth = 1)
  )
  bars <- dot_layer(
    ggplot2::ggplot(dot_frame(), ggplot2::aes(v)) +
      ggplot2::geom_histogram(binwidth = 1, boundary = 0.5)
  )

  testthat::expect_equal(counts_of(dots), counts_of(bars))
  testthat::expect_equal(counts_of(dots, "x"), counts_of(bars, "x"))
  testthat::expect_equal(counts_of(dots, "xMin"), counts_of(bars, "xMin"))
  testthat::expect_equal(counts_of(dots, "xMax"), counts_of(bars, "xMax"))
})

test_that("a bin's bounds are the bin, not the dot", {
  skip_if_no_render()

  # `xmin`/`xmax` in the built data name the bin in this orientation and the
  # dot's own width in the other, so the bounds are computed from the centre
  # and the width instead. Pinned here because a reading that took the columns
  # would pass every other test in this file and put four dot-sized boxes on
  # the chart in place of its bins.
  layer <- dot_layer(
    ggplot2::ggplot(dot_frame(), ggplot2::aes(v)) +
      ggplot2::geom_dotplot(binwidth = 1)
  )

  testthat::expect_equal(counts_of(layer, "xMin"), c(0.5, 1.5, 2.5, 3.5))
  testthat::expect_equal(counts_of(layer, "xMax"), c(1.5, 2.5, 3.5, 4.5))
  testthat::expect_equal(counts_of(layer, "yMin"), c(0, 0, 0, 0))
  testthat::expect_equal(counts_of(layer, "yMax"), counts_of(layer, "y"))
})

test_that("a dot plot binned up the y axis says so and swaps its fields", {
  skip_if_no_render()

  # `binaxis = "y"` is the form drawn beside a categorical x, and it is the
  # orientation where the built data's own bounds columns are useless: the
  # panel's whole range sits in `ymin`/`ymax`. Both halves are asserted --
  # a payload that swapped its fields without saying `horz` would be read
  # back the way it came in.
  layer <- dot_layer(
    ggplot2::ggplot(dot_frame(), ggplot2::aes(x = factor(1), y = v)) +
      ggplot2::geom_dotplot(binaxis = "y", binwidth = 1, stackdir = "center")
  )

  testthat::expect_equal(layer$orientation, "horz")
  testthat::expect_equal(counts_of(layer, "y"), c(1, 2, 3, 4))
  testthat::expect_equal(counts_of(layer, "x"), c(3, 2, 1, 4))
  testthat::expect_equal(counts_of(layer, "yMin"), c(0.5, 1.5, 2.5, 3.5))
  testthat::expect_equal(counts_of(layer, "yMax"), c(1.5, 2.5, 3.5, 4.5))
})

test_that("the count axis is named count in either orientation", {
  skip_if_no_render()

  # ggplot2 labels a dot plot's other axis "count" while drawing values on it
  # that its own documentation calls meaningless, so the name is written here
  # rather than read back -- otherwise a caller who renamed the fiction would
  # have a real count announced under it.
  vertical <- dot_layer(
    ggplot2::ggplot(dot_frame(), ggplot2::aes(v)) +
      ggplot2::geom_dotplot(binwidth = 1)
  )
  horizontal <- dot_layer(
    ggplot2::ggplot(dot_frame(), ggplot2::aes(x = factor(1), y = v)) +
      ggplot2::geom_dotplot(binaxis = "y", binwidth = 1, stackdir = "center")
  )

  testthat::expect_equal(vertical$axes$x$label, "v")
  testthat::expect_equal(vertical$axes$y$label, "count")
  testthat::expect_equal(horizontal$axes$x$label, "count")
  testthat::expect_equal(horizontal$axes$y$label, "v")
})

test_that("a renamed count axis is still announced as the count", {
  skip_if_no_render()

  # The case the assertion above cannot make on its own: reading the label
  # back gives "count" for a default dot plot too, so only a caller who has
  # renamed it separates the two readings.
  #
  # `labs(y = ...)` on a dot plot renames an axis whose values ggplot2's own
  # documentation calls meaningless -- the label is about the fiction, and the
  # number underneath it here is a real count. Announcing the count under the
  # caller's name for the fiction would describe neither.
  layer <- dot_layer(
    ggplot2::ggplot(dot_frame(), ggplot2::aes(v)) +
      ggplot2::geom_dotplot(binwidth = 1) +
      ggplot2::labs(y = "proportion of stack")
  )

  testthat::expect_equal(layer$axes$y$label, "count")
  testthat::expect_equal(counts_of(layer), c(3, 2, 1, 4))
})

test_that("a dot plot announces its bins but has nothing to highlight", {
  skip_if_no_render()

  # The limit, pinned rather than described. One `dotstackGrob` becomes one
  # `<circle>` per observation, so a three-dot bin has three elements and no
  # element of its own, while the frontend's bar traces resolve exactly one
  # per announced value. A partial or representative selector would be worse
  # than none: the reader would be shown one dot of a stack as though it were
  # the bin.
  #
  # If a later ggplot2 or gridSVG starts emitting a group per stack, this
  # fails -- which is the reminder to give it selectors and delete this.
  dots <- dot_layer(
    ggplot2::ggplot(dot_frame(), ggplot2::aes(v)) +
      ggplot2::geom_dotplot(binwidth = 1)
  )
  bars <- dot_layer(
    ggplot2::ggplot(dot_frame(), ggplot2::aes(v)) +
      ggplot2::geom_histogram(binwidth = 1, boundary = 0.5)
  )

  # Asserted first, or the rest passes vacuously: `NULL$selectors` is `NULL`
  # too, so a chart that emitted no layer would look like one without
  # selectors -- which is exactly the state this whole file exists to fix.
  testthat::expect_false(is.null(dots))
  testthat::expect_length(dots$data, 4)

  testthat::expect_true(is.null(dots$selectors) || length(dots$selectors) == 0)
  testthat::expect_false(is.null(bars$selectors))
})

test_that("a weighted dot plot announces the weighted count", {
  skip_if_no_render()

  # A pin on an equivalence rather than a guard on a choice, and said plainly
  # because the difference matters. `stat_bindot` expands a bin to one row per
  # weighted unit and refuses a fractional weight outright ("`weight` must be
  # nonnegative integers"), so counting rows gives the same answer everywhere
  # ggplot2 will build -- measured, and a reading that counted rows passes
  # this test. The count column is read anyway, as the stat's own answer
  # rather than a count of the rows that happen to represent it, and what
  # this fixes in place is that a weighted plot announces four and five here
  # rather than two and one.
  frame <- data.frame(v = c(1, 1, 2), w = c(2L, 2L, 5L))
  layer <- dot_layer(
    ggplot2::ggplot(frame, ggplot2::aes(v, weight = w)) +
      ggplot2::geom_dotplot(binwidth = 1)
  )

  testthat::expect_equal(counts_of(layer), c(4, 5))
})


test_that("a bin holding two fill groups announces both", {
  skip_if_no_render()

  # `stat_bindot` counts per group, so `aes(fill = )` puts several rows on one
  # centre carrying different counts. Measured on five observations at the bin
  # at 1, split three and two:
  #
  #     x count group countidx stackpos
  #     1     3     1        1      0.5
  #     1     3     1        2      1.5
  #     1     3     1        3      2.5
  #     1     2     2        1      0.5
  #     1     2     2        2      1.5
  #
  # Reading the first row's count announces three and drops two observations
  # with nothing saying so, which is the failure this test exists for.
  #
  # Summed rather than maxed. What the sum is: the number of observations the
  # bin holds, which is what a `hist` layer's value means, and what
  # `stackgroups = TRUE` literally draws -- that spelling continues the stack
  # to `stackpos` 3.5 and 4.5, so the column really is five high. The default
  # overlaps the groups instead and shows a pile of three, which is the
  # rendering caveat ggplot2 documents rather than a fact about the data.
  frame <- data.frame(
    v = c(1, 1, 1, 1, 1, 2, 2),
    g = c("a", "a", "a", "b", "b", "a", "a")
  )
  overlapping <- dot_layer(
    ggplot2::ggplot(frame, ggplot2::aes(v, fill = g)) +
      ggplot2::geom_dotplot(binwidth = 1)
  )
  stacked <- dot_layer(
    ggplot2::ggplot(frame, ggplot2::aes(v, fill = g)) +
      ggplot2::geom_dotplot(binwidth = 1, stackgroups = TRUE, method = "histodot")
  )

  testthat::expect_equal(counts_of(overlapping), c(5, 2))
  testthat::expect_equal(counts_of(stacked), c(5, 2))
})
