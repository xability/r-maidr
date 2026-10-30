# `barplot()` draws its bars in the order the author gives them.
#
# maidr's `barplot()` wrapper sorted the categories, and a matrix's series,
# alphabetically before it drew them. A chart scripted North, South, East,
# West was drawn and read East, North, South, West, and a vector named Jan to
# Apr was drawn Apr, Feb, Jan, Mar. The rows were sorted without the
# `legend.text` and `col` that go with them, so every series of a stacked or
# dodged chart was named, and coloured, as another: the legend's "Solar"
# stood over Hydro's numbers, and the reader heard them as Solar's.
#
# The chart is now drawn from the arguments as written, and the arguments
# recorded are those, so the SVG maidr exports, drawn again from the record,
# and the bars it reads from it follow the author's order too.

#' The arguments maidr recorded for the one call `draw` makes
#'
#' The exported chart is drawn again from these, and its bars are read from
#' them, so they are the arguments the bars are drawn and read with.
recorded_barplot_args <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )
  clear_base_r_device(device_id)

  draw()
  calls <- maidr:::get_plot_calls(device_id)
  testthat::expect_length(calls, 1)
  calls[[1]]$args
}

SALES <- matrix(
  c(150, 180, 200, 220, 130, 160, 170, 190),
  nrow = 2,
  byrow = TRUE,
  dimnames = list(c("Q2", "Q1"), c("North", "South", "East", "West"))
)

ENERGY <- matrix(
  c(40, 30, 50, 55, 45, 48, 70, 60, 52),
  nrow = 3,
  dimnames = list(c("Solar", "Wind", "Hydro"), c("2022", "2023", "2024"))
)

#' Each bar of a layer as `category:value`, or `series/category:value`, in
#' the order the layer reads them. A horizontal layer carries the value as
#' `x` and the category as `y`.
bar_readings <- function(layer) {
  horizontal <- identical(layer$orientation, "horz")
  points <- layer$data
  if (length(points) && is.list(points[[1]]) && is.null(names(points[[1]]))) {
    points <- unlist(points, recursive = FALSE)
  }
  vapply(points, function(point) {
    category <- if (horizontal) point$y else point$x
    value <- if (horizontal) point$x else point$y
    if (!is.null(point$z)) {
      category <- paste0(point$z, "/", category)
    }
    paste0(category, ":", value)
  }, character(1))
}

test_that("barplot() records a named vector as written, not sorted", {
  heights <- c(Jan = 5, Feb = 7, Mar = 3, Apr = 9)
  args <- recorded_barplot_args(function() barplot(heights))

  testthat::expect_identical(maidr:::recorded_barplot_height(args), heights)
  testthat::expect_equal(
    bar_readings(base_r_layers(function() barplot(heights))[[1]]),
    c("Jan:5", "Feb:7", "Mar:3", "Apr:9")
  )
})

test_that("barplot() keeps names.arg with the heights it names", {
  draw <- function() barplot(c(5, 7, 3, 9), names.arg = c("Jan", "Feb", "Mar", "Apr"))
  args <- recorded_barplot_args(draw)

  testthat::expect_identical(maidr:::recorded_barplot_height(args), c(5, 7, 3, 9))
  testthat::expect_identical(args$names.arg, c("Jan", "Feb", "Mar", "Apr"))
  testthat::expect_equal(
    bar_readings(base_r_layers(draw)[[1]]),
    c("Jan:5", "Feb:7", "Mar:3", "Apr:9")
  )
})

test_that("a dodged barplot() keeps its regions and its series in order", {
  draw <- function() {
    barplot(
      SALES,
      beside = TRUE,
      col = c("steelblue", "coral"),
      legend.text = rownames(SALES)
    )
  }
  args <- recorded_barplot_args(draw)

  testthat::expect_identical(maidr:::recorded_barplot_height(args), SALES)
  testthat::expect_identical(args$legend.text, c("Q2", "Q1"))
  testthat::expect_identical(args$col, c("steelblue", "coral"))

  # Right walks North, South, East, West, and each quarter is read with its
  # own row: the first row is Q2's.
  testthat::expect_equal(
    bar_readings(base_r_layers(draw)[[1]]),
    c(
      "Q2/North:150", "Q2/South:180", "Q2/East:200", "Q2/West:220",
      "Q1/North:130", "Q1/South:160", "Q1/East:170", "Q1/West:190"
    )
  )
})

test_that("a horizontal dodged barplot() keeps its series with their names", {
  draw <- function() barplot(SALES, beside = TRUE, horiz = TRUE, legend.text = rownames(SALES))
  args <- recorded_barplot_args(draw)

  testthat::expect_identical(maidr:::recorded_barplot_height(args), SALES)
  testthat::expect_identical(args$legend.text, c("Q2", "Q1"))

  layer <- base_r_layers(draw)[[1]]
  testthat::expect_equal(layer$orientation, "horz")
  testthat::expect_equal(
    bar_readings(layer),
    c(
      "Q2/North:150", "Q2/South:180", "Q2/East:200", "Q2/West:220",
      "Q1/North:130", "Q1/South:160", "Q1/East:170", "Q1/West:190"
    )
  )
})

test_that("a stacked barplot() reads each series with its own numbers", {
  draw <- function() {
    barplot(
      ENERGY,
      col = c("#2ecc71", "#3498db", "#9b59b6"),
      legend.text = rownames(ENERGY)
    )
  }
  args <- recorded_barplot_args(draw)

  testthat::expect_identical(maidr:::recorded_barplot_height(args), ENERGY)
  testthat::expect_identical(args$legend.text, c("Solar", "Wind", "Hydro"))
  testthat::expect_identical(args$col, c("#2ecc71", "#3498db", "#9b59b6"))

  layer <- base_r_layers(draw)[[1]]
  testthat::expect_equal(layer$type, "stacked_bar")
  testthat::expect_equal(
    bar_readings(layer),
    c(
      "Solar/2022:40", "Solar/2023:55", "Solar/2024:70",
      "Wind/2022:30", "Wind/2023:45", "Wind/2024:60",
      "Hydro/2022:50", "Hydro/2023:48", "Hydro/2024:52"
    )
  )
})
