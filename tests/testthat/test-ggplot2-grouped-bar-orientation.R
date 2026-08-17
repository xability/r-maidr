# A horizontal grouped bar chart came out with no data in it (#186).
#
# `ggplot(df, aes(n, g, fill = h)) + geom_col(...)` is the ordinary spelling.
# `ggplot_build()` marks the layer `flipped_aes` and swaps which computed
# column holds what; the plain bar processor learned to ask (#162), and the
# dodged and stacked processors never did -- neither file contained the string
# `flipped_aes` at all.
#
# So the category names went into `discrete_level_order()` as if they were the
# measure, and the measures went into `as.numeric()` as if they were the
# categories. On a chart of apple/banana/cherry against u and v:
#
#   dodged     every y `null`, six columns per series named "20" "30" "35"
#              "40" "50" "70" -- the chart's own numbers, sorted, with every
#              category label gone
#   stacked    the same six columns, with a category *name* sitting in the
#              slot the magnitude is read from
#   fill       the computed proportions as category names ("0.00", "0.25")
#
# None of the three emitted an `orientation` key either, so even correct data
# would have been read as a vertical chart.

grouped_schema <- function(plot) {
  maidr:::Ggplot2PlotOrchestrator$new(plot)$generate_maidr_data()
}

grouped_layer <- function(plot) {
  grouped_schema(plot)$subplots[[1]][[1]]$layers[[1]]
}

# `label:value` per bar, series by series, in emitted order.
#
# Read by orientation for the reason the plain bar's helper is: MAIDR takes
# `x` as the magnitude and `y` as the category when `orientation` is `"horz"`,
# so reading the fields positionally would pass on a layer that had the pair
# backwards -- which is the defect itself.
grouped_pairs <- function(layer) {
  horizontal <- identical(layer$orientation, "horz")
  unlist(lapply(layer$data, function(series) {
    vapply(
      series,
      function(d) {
        if (horizontal) {
          sprintf("%s:%s", d$y, d$x)
        } else {
          sprintf("%s:%s", d$x, d$y)
        }
      },
      character(1)
    )
  }))
}

fruit_by_group <- function() {
  data.frame(
    g = rep(c("apple", "banana", "cherry"), each = 2),
    h = rep(c("u", "v"), 3),
    n = c(30, 20, 70, 40, 50, 35),
    stringsAsFactors = FALSE
  )
}

upright <- function(position) {
  ggplot2::ggplot(
    fruit_by_group(),
    ggplot2::aes(x = g, y = n, fill = h)
  ) + ggplot2::geom_col(position = position)
}

sideways <- function(position) {
  ggplot2::ggplot(
    fruit_by_group(),
    ggplot2::aes(x = n, y = g, fill = h)
  ) + ggplot2::geom_col(position = position)
}

for (spec in list(
  list(name = "dodged", position = "dodge"),
  list(name = "stacked", position = "stack")
)) {
  local({
    position <- spec$position
    name <- spec$name

    test_that(sprintf("a horizontal %s bar chart carries its values", name), {
      testthat::skip_if_not_installed("ggplot2")

      # The strongest form: the same data drawn both ways has to come out
      # identical apart from the orientation key. Every way the old code went
      # wrong -- lost labels, `null` values, six columns instead of three,
      # rows resorted by the measure -- shows up as a difference here.
      testthat::expect_equal(
        sort(grouped_pairs(grouped_layer(sideways(position)))),
        sort(grouped_pairs(grouped_layer(upright(position))))
      )
    })

    test_that(sprintf("a %s bar chart says which way round it is", name), {
      testthat::skip_if_not_installed("ggplot2")

      # Neither processor emitted the key at all, so a horizontal chart was
      # read as a vertical one whatever its data said.
      testthat::expect_equal(grouped_layer(upright(position))$orientation, "vert")
      testthat::expect_equal(grouped_layer(sideways(position))$orientation, "horz")
    })

    test_that(sprintf("a horizontal %s bar has a magnitude on every bar", name), {
      testthat::skip_if_not_installed("ggplot2")

      # The sharpest form of the dodged symptom, and the one a reader met
      # first: `as.numeric()` on the category names produced `NA` for every
      # cell, so the chart navigated normally and announced "missing" at each
      # bar. Stated on its own rather than left to the comparison above,
      # because "the two orientations differ" does not say that one of them
      # had no data in it.
      magnitudes <- unlist(lapply(
        grouped_layer(sideways(position))$data,
        function(series) vapply(series, function(d) d$x, numeric(1))
      ))

      testthat::expect_false(anyNA(magnitudes))
      testthat::expect_setequal(magnitudes, c(30, 20, 70, 40, 50, 35))
    })

    test_that(sprintf("a horizontal %s bar puts the measure in x", name), {
      testthat::skip_if_not_installed("ggplot2")

      # `grouped_pairs` reads the fields by orientation, which is what makes
      # the comparison above meaningful -- so one test has to name them
      # outright, or the helper and the processor could agree on the wrong
      # arrangement and nothing would notice.
      first <- grouped_layer(sideways(position))$data[[1]][[1]]

      testthat::expect_type(first$x, "double")
      testthat::expect_type(first$y, "character")
    })
  })
}

test_that("a horizontal filled bar keeps its categories, not its proportions", {
  testthat::skip_if_not_installed("ggplot2")

  # `position = "fill"` reaches its category names by a different route than
  # the other two: it reads the break labels off the panel's scales. Those
  # sit on the y axis for a horizontal layer, so reading x gave every bar one
  # of the chart's own computed shares as its name.
  layer <- grouped_layer(sideways("fill"))
  labels <- vapply(layer$data[[1]], function(d) d$y, character(1))

  testthat::expect_setequal(labels, c("apple", "banana", "cherry"))
})

test_that("a filled bar chart reports the same shares whichever way it is drawn", {
  testthat::skip_if_not_installed("ggplot2")

  testthat::expect_equal(
    sort(grouped_pairs(grouped_layer(sideways("fill")))),
    sort(grouped_pairs(grouped_layer(upright("fill"))))
  )
  testthat::expect_equal(grouped_layer(sideways("fill"))$orientation, "horz")
})

test_that("a vertical grouped bar chart is unchanged", {
  testthat::skip_if_not_installed("ggplot2")

  # The swap must be reached only by a flipped layer. These are the readings
  # the processors already produced, written out so a regression in the
  # untouched direction cannot hide behind the comparisons above.
  testthat::expect_setequal(
    grouped_pairs(grouped_layer(upright("dodge"))),
    c("apple:30", "banana:70", "cherry:50", "apple:20", "banana:40", "cherry:35")
  )
})
