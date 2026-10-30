# A facet subplot is named as its strips name it
#
# The vignette's `facet_grid(vs ~ am, labeller = labeller(vs = c("0" =
# "V-engine", "1" = "Straight"), am = c("0" = "Automatic", "1" = "Manual")))`
# writes "V-engine", "Straight", "Automatic" and "Manual" on its strips, but
# the subplots were named by the raw values, "0 & 0" to "1 & 1": nothing the
# chart shows, and no word of which number was the engine and which the
# transmission. A panel is now named by the facet's labeller, as ggplot2
# writes its strips.

# The title of every subplot, row by row.
subplot_titles <- function(plot) {
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(plot)
  grid <- orchestrator$generate_maidr_data()$subplots
  lapply(grid, function(row) {
    vapply(row, function(cell) cell$layers[[1]]$title, character(1))
  })
}

engine_plot <- function(labeller) {
  ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    ggplot2::facet_grid(vs ~ am, labeller = labeller)
}

test_that("a grid's panels are named by the labels its labeller writes", {
  titles <- subplot_titles(engine_plot(ggplot2::labeller(
    vs = c("0" = "V-engine", "1" = "Straight"),
    am = c("0" = "Automatic", "1" = "Manual")
  )))

  expect_equal(titles, list(
    c("V-engine & Automatic", "V-engine & Manual"),
    c("Straight & Automatic", "Straight & Manual")
  ))
})

test_that("label_both names the variable with its value", {
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~cyl, labeller = ggplot2::label_both)

  expect_equal(unlist(subplot_titles(plot)), c("cyl: 4", "cyl: 6", "cyl: 8"))
})

test_that("the default labeller names a panel by its values, as before", {
  expect_equal(
    subplot_titles(engine_plot("label_value")),
    list(c("0 & 0", "0 & 1"), c("1 & 0", "1 & 1"))
  )
})

test_that("a parsed label is written out as text", {
  frame <- data.frame(x = 1:4, y = 1:4, f = rep(c("alpha^2", "beta"), 2))
  plot <- ggplot2::ggplot(frame, ggplot2::aes(x, y)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~f, labeller = ggplot2::label_parsed)

  expect_equal(unlist(subplot_titles(plot)), c("alpha^2", "beta"))
})

test_that("a wrap of two variables is named by every line of its strip", {
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(~ vs + am, labeller = ggplot2::label_both)

  expect_equal(
    unlist(subplot_titles(plot)),
    c("vs: 0 & am: 0", "vs: 0 & am: 1", "vs: 1 & am: 0", "vs: 1 & am: 1")
  )
})

test_that("a strip written on one line is that line", {
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    ggplot2::facet_wrap(
      ~ vs + am,
      labeller = ggplot2::labeller(.default = ggplot2::label_both, .multi_line = FALSE)
    )

  expect_equal(
    unlist(subplot_titles(plot)),
    c("vs: 0, am: 0", "vs: 0, am: 1", "vs: 1, am: 0", "vs: 1, am: 1")
  )
})

test_that("a line with no text for the panel gives none", {
  # Any of these sends the title back to the facet values.
  expect_equal(maidr:::strip_label_text(c("a", "b"), 2), "b")
  expect_true(is.na(maidr:::strip_label_text(c("a", ""), 2)))
  expect_true(is.na(maidr:::strip_label_text(c("a", NA), 2)))
  expect_true(is.na(maidr:::strip_label_text("a", 2)))
  expect_equal(maidr:::strip_label_text(list(quote(alpha^2)), 1), "alpha^2")
  expect_equal(maidr:::strip_label_text(list(expression(beta)), 1), "beta")
})
