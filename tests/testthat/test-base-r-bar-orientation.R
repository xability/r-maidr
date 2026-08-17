# A base R horizontal grouped bar chart was announced as a vertical one (#189).
#
# `BaseRBarplotLayerProcessor` already reported `orientation = "horz"` for
# `barplot(h, horiz = TRUE)`, and its points come out swapped for free because
# it reads the drawn rectangles -- on a horizontal chart the bar's length lies
# along x. The stacked and dodged processors read the caller's *matrix*
# instead, so their points are in the vertical arrangement whichever way the
# chart was drawn, and neither emitted an `orientation` key at all.
#
# The data was never lost, which is what separates this from #186: base R has
# no flipped aesthetics to misread, and a `vert` key over a vertical payload is
# self-consistent. What went wrong is everything downstream that depends on
# knowing which way the chart is drawn -- the announced chart type, and the
# stereo cue, which swept left-to-right across categories that run down the
# page.
#
# Both halves have to move together: `"horz"` over vertical points is the
# combination #184 was about, so setting the key alone would have turned a
# wrong announcement into a silent chart.

bar_layers <- function(draw) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  device_id <- grDevices::dev.cur()
  if (maidr:::has_device_calls(device_id)) {
    maidr:::clear_device_storage(device_id)
  }
  draw()
  schema <- maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()
  schema$subplots[[1]][[1]]$layers
}

bar_layer <- function(draw) {
  bar_layers(draw)[[1]]
}

FRUIT <- local({
  h <- c(30, 70, 50)
  names(h) <- c("apple", "banana", "cherry")
  h
})

GROUPED <- matrix(
  c(30, 20, 70, 40, 50, 35),
  nrow = 2,
  dimnames = list(c("u", "v"), c("apple", "banana", "cherry"))
)

# `label:value` per bar, read by orientation for the reason the ggplot2
# helpers are: MAIDR takes `x` as the magnitude and `y` as the category when
# `orientation` is `"horz"`, so reading the fields positionally would pass on a
# layer that had the pair backwards.
bar_pairs <- function(layer) {
  horizontal <- identical(layer$orientation, "horz")
  points <- layer$data
  if (length(points) && is.list(points[[1]]) && is.null(names(points[[1]]))) {
    points <- unlist(points, recursive = FALSE)
  }
  vapply(
    points,
    function(d) {
      if (horizontal) {
        sprintf("%s:%s", d$y, d$x)
      } else {
        sprintf("%s:%s", d$x, d$y)
      }
    },
    character(1)
  )
}

for (spec in list(
  list(name = "stacked", args = list()),
  list(name = "dodged", args = list(beside = TRUE))
)) {
  local({
    name <- spec$name
    extra <- spec$args

    upright <- function() do.call(barplot, c(list(GROUPED), extra))
    sideways <- function() do.call(barplot, c(list(GROUPED, horiz = TRUE), extra))

    test_that(sprintf("a base R %s bar chart says which way round it is", name), {
      # Neither processor emitted the key at all, so a chart drawn across the
      # page was announced as a vertical one and panned along the wrong axis.
      testthat::expect_equal(bar_layer(upright)$orientation, "vert")
      testthat::expect_equal(bar_layer(sideways)$orientation, "horz")
    })

    test_that(sprintf("a horizontal base R %s bar puts the measure in x", name), {
      # `bar_pairs` reads the fields by orientation, so one test has to name
      # them outright or the helper and the processor could agree on the wrong
      # arrangement and nothing above would notice.
      first <- bar_layer(sideways)$data[[1]]
      if (is.null(names(first))) {
        first <- first[[1]]
      }

      testthat::expect_type(first$x, "double")
      testthat::expect_type(first$y, "character")
    })

    test_that(sprintf("both orientations of a %s bar describe one chart", name), {
      # The key and the layout are set from one answer, so the reading has to
      # come out the same either way. A key set without the swap -- or a swap
      # without the key -- shows up here as a difference.
      testthat::expect_equal(
        sort(bar_pairs(bar_layer(sideways))),
        sort(bar_pairs(bar_layer(upright)))
      )
    })
  })
}

test_that("a plain base R bar chart is unchanged", {
  # This processor was already right: it reports `horz` and reads the drawn
  # rectangles, so its points arrive swapped without a swap step. It must not
  # acquire a second one.
  upright <- bar_layer(function() barplot(FRUIT))
  sideways <- bar_layer(function() barplot(FRUIT, horiz = TRUE))

  testthat::expect_equal(sideways$orientation, "horz")
  testthat::expect_equal(sideways$data[[1]]$x, 30)
  testthat::expect_identical(sideways$data[[1]]$y, "apple")
  testthat::expect_identical(upright$data[[1]]$x, "apple")
  testthat::expect_equal(upright$data[[1]]$y, 30)
})
