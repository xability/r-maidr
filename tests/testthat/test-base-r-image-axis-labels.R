# An image() heat map is read by the names its axis() calls give its cells
#
# `image(m, axes = FALSE)` followed by `axis(1, at = seq(0, 1, length.out =
# 5), labels = c("Mon", ...))` and `axis(2, ...)` is how Base R names the
# rows and columns of an image: image() itself writes no names. The cells
# were read by index -- "Day is 2, Hour is 1, value is 35" for the cell the
# chart shows as Tue at 9am, "Highest cell: 3, 4" -- because the axis()
# calls were never consulted.

visitors <- matrix(
  c(
    20, 35, 50, 45, 30,
    25, 40, 60, 55, 35,
    30, 55, 75, 70, 45,
    40, 65, 90, 85, 60,
    35, 50, 70, 65, 40,
    30, 45, 60, 55, 38,
    25, 40, 55, 50, 32,
    15, 30, 40, 35, 22
  ),
  nrow = 5
)
days <- c("Mon", "Tue", "Wed", "Thu", "Fri")
hours <- c("9am", "10am", "11am", "12pm", "1pm", "2pm", "3pm", "4pm")

test_that("the cells are named by the axis() labels at their centres", {
  layer <- base_r_layers(function() {
    image(visitors, xlab = "Day", ylab = "Hour", axes = FALSE)
    axis(1, at = seq(0, 1, length.out = 5), labels = days)
    axis(2, at = seq(0, 1, length.out = 8), labels = hours)
  })[[1]]

  expect_equal(layer$type, "heat")
  expect_equal(unlist(layer$data$x), days)
  # Rows top first, as the points are.
  expect_equal(unlist(layer$data$y), rev(hours))
  # Tue at 9am: column 2 of the bottom row, which is the points' last.
  rows <- layer$data$points
  expect_equal(rows[[length(rows)]][[2]], visitors[2, 1])
})

test_that("an axis() that does not name every cell names none", {
  layer <- base_r_layers(function() {
    image(visitors, axes = FALSE)
    axis(1, at = c(0, 0.5, 1), labels = c("Mon", "Wed", "Fri"))
  })[[1]]

  expect_equal(unlist(layer$data$x), as.character(1:5))
})

test_that("an image with no axis() calls is read as before", {
  layer <- base_r_layers(function() image(visitors))[[1]]

  expect_equal(unlist(layer$data$x), as.character(1:5))
  expect_equal(unlist(layer$data$y), as.character(8:1))
})
