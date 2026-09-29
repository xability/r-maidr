# Reading the xyplot family of lattice charts (#333)
#
# xyplot(), stripplot(), qqmath(), qq() and densityplot() draw their data as
# points, lines, staircases, spikes and curves, and each is read as a MAIDR
# layer: the values a reader hears, and a selector for the marks those
# values are highlighted on. Both halves are checked against something the
# code under test does not compute:
#
#   * the values against the data the chart was drawn from, or against the
#     statistic lattice drew -- recomputed here with the function lattice's
#     panel function calls (`loess.smooth()`, `density()`, `quantile()`);
#   * the selectors against the SVG the chart is exported as. A selector
#     must match exactly the marks the layer's values are, one each and in
#     the same order, and the order is checked from the marks' own
#     coordinates: an axis maps a value to a position linearly, so the marks
#     drawn at a layer's values lie on one straight line through them, and a
#     mark drawn for another value -- or matched out of order -- does not.

skip_slow_file_on_cran()

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

#' Render a chart that must be read interactively rather than as an image
xy_render <- function(plot) {
  # A chart of a time series asks lattice for its theme as it is built,
  # which opens a device when none is: it is built on a null one, closed
  # after, so the reading still starts with no device open.
  grDevices::pdf(NULL)
  plot <- tryCatch(plot, finally = grDevices::dev.off())
  rendered <- render_lattice(plot)
  testthat::expect_false(
    rendered$fallback,
    label = paste(
      "fell back:",
      paste(rendered$orchestrator$unsupported_reasons(), collapse = "; ")
    )
  )
  rendered
}

#' Points as a two-column matrix; a gap (`null`) reads as NA
xy_matrix <- function(points) {
  value <- function(point, field) {
    if (is.null(point[[field]])) NA_real_ else as.numeric(point[[field]])
  }
  cbind(
    x = vapply(points, value, numeric(1), field = "x"),
    y = vapply(points, value, numeric(1), field = "y")
  )
}

#' One string field of every point, NA where a point has none
xy_field <- function(points, field) {
  vapply(points, function(point) {
    if (is.null(point[[field]])) NA_character_ else as.character(point[[field]])
  }, character(1))
}

#' Where every `<use>` a selector matches is drawn, in document order
xy_use_positions <- function(doc, selector) {
  nodes <- lattice_selector_nodes(doc, selector)
  cbind(
    x = as.numeric(xml2::xml_attr(nodes, "x")),
    y = as.numeric(xml2::xml_attr(nodes, "y"))
  )
}

#' The vertices of one polyline element
xy_vertices_of <- function(node) {
  pairs <- strsplit(strsplit(trimws(xml2::xml_attr(node, "points")), "\\s+")[[1]], ",")
  vertices <- matrix(as.numeric(unlist(pairs)), ncol = 2, byrow = TRUE)
  colnames(vertices) <- c("x", "y")
  vertices
}

#' The vertices of every polyline a selector matches, in document order
xy_polyline_vertices <- function(doc, selector) {
  nodes <- lattice_selector_nodes(doc, selector)
  do.call(rbind, lapply(seq_along(nodes), function(i) xy_vertices_of(nodes[[i]])))
}

#' Expect device coordinates to be one increasing linear function of values
#'
#' The exporter rounds a coordinate to a hundredth of a pixel.
xy_expect_drawn_at <- function(px, values) {
  testthat::expect_identical(length(px), length(values))
  fit <- stats::lm(px ~ values)
  testthat::expect_gt(unname(stats::coef(fit)[2]), 0)
  testthat::expect_lt(max(abs(stats::residuals(fit))), 0.02)
}

#' The map from device coordinates back to data units, fitted on marks
#' drawn at known values
xy_scale <- function(px, values) {
  fit <- stats::coef(stats::lm(px ~ values))
  function(p) (p - fit[[1]]) / fit[[2]]
}

#' The one rectangle a selector matches, as numbers
xy_rect <- function(doc, selector) {
  nodes <- lattice_selector_nodes(doc, selector)
  testthat::expect_length(nodes, 1L)
  vapply(
    c(x = "x", y = "y", width = "width", height = "height"),
    function(attr) as.numeric(xml2::xml_attr(nodes[[1]], attr)),
    numeric(1)
  )
}

#' The device positions of one panel's tick marks on one side
xy_ticks <- function(doc, side, column = 1, row = 1) {
  selector <- lattice_grob_selector_for(sprintf("ticks.%s.panel.%d.%d", side, column, row))
  nodes <- lattice_selector_nodes(doc, selector)
  along <- if (side %in% c("bottom", "top")) "x" else "y"
  vapply(seq_along(nodes), function(i) xy_vertices_of(nodes[[i]])[1, along], numeric(1))
}

#' The device positions and text of one panel's tick labels on one side
xy_ticklabels <- function(doc, side, column = 1, row = 1) {
  id <- sprintf("maidr.ticklabels.%s.panel.%d.%d.1", side, column, row)
  groups <- xml2::xml_find_all(doc, sprintf("//*[@id='%s']/*", id))
  at <- regmatches(
    xml2::xml_attr(groups, "transform"),
    regexec("translate\\(([-0-9.]+), *([-0-9.]+)\\)", xml2::xml_attr(groups, "transform"))
  )
  along <- if (side %in% c("bottom", "top")) 2L else 3L
  data.frame(
    px = vapply(at, function(m) as.numeric(m[along]), numeric(1)),
    text = xml2::xml_text(groups),
    stringsAsFactors = FALSE
  )
}

#' The selector of every shape of one lattice grob, by its name without the
#' prefix
lattice_grob_selector_for <- function(name, element = "polyline") {
  maidr:::lattice_grob_selector(paste0("maidr.", name), element)
}

#' Whether the chart's SVG holds a grob of this name (without the prefix)
xy_has_grob <- function(doc, name) {
  length(xml2::xml_find_all(doc, sprintf("//*[@id='maidr.%s.1']", name))) == 1L
}

# A chart's data, shared by several tests: x is not sorted, so a reading
# that sorted it would show.
xy_data <- data.frame(
  x = c(3, 1, 4, 1.5, 5, 9, 2, 6, 7, 8, 2.5, 5.5),
  y = c(2, 7, 1, 8, 2, 8, 1, 8, 5, 6, 3, 4)
)

# ------------------------------------------------------------------------------
# type = "p": points
# ------------------------------------------------------------------------------

test_that("xyplot() points are read as the data, one mark each, in the data's order", {
  skip_if_no_lattice()
  # A missing value on each axis: a point missing either coordinate is not
  # drawn, and the exporter numbers the marks it does draw by their row, so
  # the reading has to leave out exactly those rows to pair with the marks.
  d <- data.frame(
    x = c(3, 1, 4, NA, 5, 9, 2, 6, 7),
    y = c(2, 7, 1, 8, NA, 8, 1.5, 8, 5)
  )
  r <- xy_render(lattice::xyplot(y ~ x, d))
  layers <- lattice_rendered_layers(r)

  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "point")
  kept <- stats::complete.cases(d)
  testthat::expect_equal(unname(xy_matrix(layer$data)), unname(as.matrix(d[kept, ])))
  testthat::expect_null(layer$name)

  testthat::expect_identical(lattice_selector_counts(r$doc, layer$selectors), sum(kept))
  nodes <- lattice_selector_nodes(r$doc, layer$selectors)
  testthat::expect_identical(
    xml2::xml_attr(nodes, "id"),
    sprintf("maidr.xyplot.points.panel.1.1.1.%d", which(kept))
  )
  drawn <- xy_use_positions(r$doc, layer$selectors)
  xy_expect_drawn_at(drawn[, "x"], d$x[kept])
  xy_expect_drawn_at(drawn[, "y"], d$y[kept])
})

test_that("a point layer's axes are labelled as drawn, span the panel and step as its ticks", {
  skip_if_no_lattice()
  r <- xy_render(lattice::xyplot(y ~ x, xy_data, xlab = "Width", ylab = list("Height", cex = 2)))
  layer <- lattice_rendered_layers(r)[[1]]

  testthat::expect_identical(layer$axes$x$label, "Width")
  testthat::expect_identical(layer$axes$y$label, "Height")

  # The panel border is drawn at the axis limits and the ticks at the
  # positions lattice labels; both are read back into data units through
  # the scale the points were drawn on.
  drawn <- xy_use_positions(r$doc, layer$selectors)
  to_x <- xy_scale(drawn[, "x"], xy_data$x)
  to_y <- xy_scale(drawn[, "y"], xy_data$y)
  border <- xy_rect(r$doc, lattice_grob_selector_for("border.panel.1.1", "rect"))
  testthat::expect_equal(layer$axes$x$min, to_x(border[["x"]]), tolerance = 1e-3)
  testthat::expect_equal(
    layer$axes$x$max, to_x(border[["x"]] + border[["width"]]),
    tolerance = 1e-3
  )
  testthat::expect_equal(layer$axes$y$min, to_y(border[["y"]]), tolerance = 1e-3)
  testthat::expect_equal(
    layer$axes$y$max, to_y(border[["y"]] + border[["height"]]),
    tolerance = 1e-3
  )

  x_steps <- diff(to_x(xy_ticks(r$doc, "bottom")))
  y_steps <- diff(to_y(xy_ticks(r$doc, "left")))
  testthat::expect_equal(rep(layer$axes$x$tickStep, length(x_steps)), x_steps, tolerance = 1e-3)
  testthat::expect_equal(rep(layer$axes$y$tickStep, length(y_steps)), y_steps, tolerance = 1e-3)
})

test_that("a point layer's tick step follows the ticks the chart asked for", {
  skip_if_no_lattice()
  drawn_steps <- function(r, layer) {
    drawn <- xy_use_positions(r$doc, layer$selectors)
    to_x <- xy_scale(drawn[, "x"], xy_data$x)
    diff(to_x(xy_ticks(r$doc, "bottom")))
  }

  # `tick.number` asks lattice's pretty() for more ticks, `at` places them.
  scales <- list(list(x = list(tick.number = 10)), list(x = list(at = seq(0, 10, 2.5))))
  for (scale in scales) {
    r <- xy_render(lattice::xyplot(y ~ x, xy_data, scales = scale))
    layer <- lattice_rendered_layers(r)[[1]]
    steps <- drawn_steps(r, layer)
    testthat::expect_gte(length(steps), 2L)
    testthat::expect_equal(
      rep(layer$axes$x$tickStep, length(steps)), steps,
      tolerance = 1e-3
    )
  }

  # Ticks placed unevenly have no one step: the grid keeps its range but is
  # given no step the axis does not show.
  r <- xy_render(lattice::xyplot(y ~ x, xy_data, scales = list(x = list(at = c(1, 2, 5, 9)))))
  layer <- lattice_rendered_layers(r)[[1]]
  steps <- drawn_steps(r, layer)
  testthat::expect_gt(max(steps) - min(steps), 1)
  testthat::expect_null(layer$axes$x$tickStep)
  testthat::expect_true(is.numeric(layer$axes$x$min) && is.numeric(layer$axes$x$max))
})

test_that("points on a factor axis are read at their level's position, named by the level", {
  skip_if_no_lattice()
  # A level no row uses is dropped from the axis, so the positions are the
  # codes of the levels lattice keeps, not of the factor as given.
  d <- data.frame(
    f = factor(c("lo", "hi", "mid", "lo", "hi", "mid"), levels = c("none", "lo", "mid", "hi")),
    y = c(3, 9, 5, 2, 8, 6)
  )
  r <- xy_render(lattice::xyplot(y ~ f, d))
  layer <- lattice_rendered_layers(r)[[1]]
  kept <- droplevels(d$f)

  testthat::expect_equal(unname(xy_matrix(layer$data)[, "x"]), as.integer(kept))
  testthat::expect_equal(unname(xy_matrix(layer$data)[, "y"]), d$y)
  testthat::expect_identical(xy_field(layer$data, "xLabel"), as.character(kept))
  testthat::expect_true(all(is.na(xy_field(layer$data, "yLabel"))))
  # A category axis has no numeric grid to navigate.
  testthat::expect_null(layer$axes$x$min)
  testthat::expect_null(layer$axes$x$tickStep)

  # Each mark stands where the axis prints the name it is read with.
  drawn <- xy_use_positions(r$doc, layer$selectors)
  labels <- xy_ticklabels(r$doc, "bottom")
  testthat::expect_identical(labels$text, levels(kept))
  label_px <- labels$px[match(xy_field(layer$data, "xLabel"), labels$text)]
  testthat::expect_equal(drawn[, "x"], label_px, tolerance = 0.02)
  xy_expect_drawn_at(drawn[, "y"], d$y)
})

test_that("lines and spikes on a factor axis are read by the level's name", {
  skip_if_no_lattice()
  d <- data.frame(
    v = c(1, 2, 3, 4, 5),
    f = factor(c("low", "high", "mid", "low", "high"), levels = c("low", "mid", "high"))
  )

  # A line's x may be a name; its y drives the sonification and stays the
  # level's position, with the name beside it.
  r <- xy_render(lattice::xyplot(f ~ v, d, type = "l"))
  line <- lattice_rendered_layers(r)[[1]]
  series <- line$data[[1]]
  testthat::expect_equal(unname(xy_matrix(series)), cbind(d$v, as.integer(d$f)))
  testthat::expect_identical(xy_field(series, "label"), as.character(d$f))
  # Drawn at the levels' positions, which the axis names bottom up in order.
  vertices <- xy_polyline_vertices(r$doc, line$selectors[[1]])
  xy_expect_drawn_at(vertices[, "y"], as.integer(d$f))
  labels <- xy_ticklabels(r$doc, "left")
  testthat::expect_identical(labels$text[order(labels$px)], levels(d$f))

  r <- xy_render(lattice::xyplot(v ~ f, d, type = c("p", "l")))
  line <- lattice_rendered_layers(r)[[2]]$data[[1]]
  testthat::expect_identical(xy_field(line, "x"), as.character(d$f))
  testthat::expect_equal(vapply(line, function(p) as.numeric(p$y), numeric(1)), d$v)

  # A spike stands at its level, named by it, and is read in the order the
  # levels run along the axis.
  r <- xy_render(lattice::xyplot(v ~ f, d, type = "h"))
  spikes <- lattice_rendered_layers(r)[[1]]
  along <- d[order(as.integer(d$f)), ]
  testthat::expect_identical(xy_field(spikes$data, "x"), as.character(along$f))
  testthat::expect_equal(vapply(spikes$data, function(p) as.numeric(p$y), numeric(1)), along$v)
  nodes <- lattice_selector_nodes(r$doc, spikes$selectors)
  tops <- do.call(rbind, lapply(seq_along(nodes), function(i) xy_vertices_of(nodes[[i]])[1, ]))
  at <- xy_ticklabels(r$doc, "bottom")
  testthat::expect_equal(
    tops[, "x"],
    at$px[match(as.character(along$f), at$text)],
    tolerance = 0.02
  )
})

test_that("points on a log scale are read on the data's own scale", {
  skip_if_no_lattice()
  d <- data.frame(x = c(1, 3, 10, 30, 100, 300), y = c(2, 5, 3, 8, 13, 21))
  cases <- list(
    list(scales = list(x = list(log = 10)), x = log10, y = identity),
    list(scales = list(x = list(log = 2)), x = log2, y = identity),
    list(scales = list(log = "e"), x = log, y = log),
    list(scales = list(y = list(log = TRUE)), x = identity, y = log10)
  )
  for (case in cases) {
    r <- xy_render(lattice::xyplot(y ~ x, d, scales = case$scales))
    layer <- lattice_rendered_layers(r)[[1]]

    testthat::expect_equal(unname(xy_matrix(layer$data)), unname(as.matrix(d)))
    # lattice drew them in log units: the marks lie on a line through the
    # logarithms, not through the values read.
    drawn <- xy_use_positions(r$doc, layer$selectors)
    xy_expect_drawn_at(drawn[, "x"], case$x(d$x))
    xy_expect_drawn_at(drawn[, "y"], case$y(d$y))
    # A log axis has no one step in the data's units, and no grid is given.
    for (axis in c("x", "y")) {
      logged <- !identical(case[[axis]], identity)
      testthat::expect_identical(is.null(layer$axes[[axis]]$tickStep), logged)
    }
  }
})

test_that("points on a date axis are read as the instants they stand for, announced as dates", {
  skip_if_no_lattice()
  d <- data.frame(day = as.Date("2024-01-01") + c(0, 31, 60, 91, 121), y = c(3, 5, 2, 8, 6))
  r <- xy_render(lattice::xyplot(y ~ day, d, type = "b"))
  layers <- lattice_rendered_layers(r)
  testthat::expect_identical(vapply(layers, `[[`, "", "type"), c("point", "line"))

  # maidr.js reads a time as milliseconds since 1970 -- its date format is
  # `new Date(value)` -- and a date is its calendar day at midnight UTC.
  instants <- as.numeric(as.POSIXct(format(d$day), tz = "UTC")) * 1000
  points <- layers[[1]]
  testthat::expect_equal(unname(xy_matrix(points$data)[, "x"]), instants)
  testthat::expect_equal(unname(xy_matrix(layers[[2]]$data[[1]])[, "x"]), instants)
  date_format <- list(
    type = "date",
    dateOptions = list(year = "numeric", month = "short", day = "numeric", timeZone = "UTC")
  )
  testthat::expect_identical(points$axes$x$format, date_format)
  testthat::expect_identical(layers[[2]]$axes$x$format, date_format)
  testthat::expect_null(points$axes$y$format)
  # The months between lattice's date ticks differ in length: no one step.
  testthat::expect_null(points$axes$x$tickStep)

  drawn <- xy_use_positions(r$doc, points$selectors)
  xy_expect_drawn_at(drawn[, "x"], as.numeric(d$day))
})

test_that("a date-time axis is announced in the time zone lattice labels it in", {
  skip_if_no_lattice()
  # lattice labels a date-time axis in the session's zone, which `TZ` sets
  # without `Sys.timezone()` reporting it; a zone neither the data's nor
  # UTC shows which one the reading follows.
  old_tz <- Sys.getenv("TZ", unset = NA)
  on.exit(if (is.na(old_tz)) Sys.unsetenv("TZ") else Sys.setenv(TZ = old_tz), add = TRUE)
  Sys.setenv(TZ = "Asia/Tokyo")
  d <- data.frame(
    at = as.POSIXct("2024-03-01 00:00", tz = "America/New_York") + 3600 * c(0, 1, 2, 5, 7),
    y = c(1, 4, 2, 3, 5)
  )
  r <- xy_render(lattice::xyplot(y ~ at, d))
  layer <- lattice_rendered_layers(r)[[1]]

  testthat::expect_equal(unname(xy_matrix(layer$data)[, "x"]), as.numeric(d$at) * 1000)
  zone <- layer$axes$x$format$dateOptions$timeZone
  testthat::expect_identical(zone, "Asia/Tokyo")

  # Read each tick label's instant off the scale the points were drawn on,
  # and the zone announced must print it as lattice labelled it.
  drawn <- xy_use_positions(r$doc, layer$selectors)
  to_seconds <- xy_scale(drawn[, "x"], as.numeric(d$at))
  labels <- xy_ticklabels(r$doc, "bottom")
  testthat::expect_gt(nrow(labels), 1L)
  instants <- as.POSIXct(round(to_seconds(labels$px)), origin = "1970-01-01", tz = zone)
  testthat::expect_identical(format(instants, "%H:%M"), labels$text)
})

test_that("a jittered axis is read at the data's values, not at the random offsets drawn", {
  skip_if_no_lattice()
  d <- data.frame(x = rep(1:3, each = 3), y = c(2, 4, 3, 5, 7, 6, 9, 8, 10))
  set.seed(42)
  r <- xy_render(lattice::xyplot(y ~ x, d, jitter.x = TRUE))
  layer <- lattice_rendered_layers(r)[[1]]

  testthat::expect_equal(unname(xy_matrix(layer$data)), unname(as.matrix(d)))
  # The marks were jittered along x, and only along x.
  drawn <- xy_use_positions(r$doc, layer$selectors)
  testthat::expect_identical(nrow(drawn), nrow(d))
  jitter <- stats::residuals(stats::lm(drawn[, "x"] ~ d$x))
  testthat::expect_gt(max(abs(jitter)), 1)
  xy_expect_drawn_at(drawn[, "y"], d$y)

  # Grouped, each group's rows are its marks.
  d$g <- factor(rep(c("a", "b", "c"), 3))
  set.seed(7)
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g, jitter.x = TRUE, jitter.y = TRUE))
  for (layer in lattice_rendered_layers(r)) {
    rows <- d$g == layer$name
    testthat::expect_equal(unname(xy_matrix(layer$data)), unname(as.matrix(d[rows, c("x", "y")])))
  }
})

# ------------------------------------------------------------------------------
# groups
# ------------------------------------------------------------------------------

test_that("grouped points are one layer per group, named by its level and holding its rows", {
  skip_if_no_lattice()
  # Level "b" has no rows, and a row with no group is not drawn.
  d <- data.frame(
    x = c(1, 2, 3, 4, 5, 6, 7, 8, 9),
    y = c(5, 3, 8, 1, 9, 2, 7, 4, 6),
    g = factor(c("a", "c", "a", "c", NA, "a", "c", "a", "c"), levels = c("a", "b", "c"))
  )
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g))
  layers <- lattice_rendered_layers(r)

  testthat::expect_identical(vapply(layers, `[[`, "", "name"), c("a", "c"))
  for (layer in layers) {
    rows <- which(d$g == layer$name)
    testthat::expect_equal(unname(xy_matrix(layer$data)), unname(as.matrix(d[rows, 1:2])))
    testthat::expect_identical(lattice_selector_counts(r$doc, layer$selectors), length(rows))
  }
  # lattice numbers a group by its level over the whole factor, so "c" is
  # drawn as group 3 even with "b" unused.
  testthat::expect_true(grepl("group\\.3\\.panel", layers[[2]]$selectors, fixed = TRUE))

  # Every mark of the panel lies on the panel's one scale, each at its row.
  drawn <- do.call(rbind, lapply(layers, function(l) xy_use_positions(r$doc, l$selectors)))
  rows <- unlist(lapply(layers, function(l) which(d$g == l$name)))
  xy_expect_drawn_at(drawn[, "x"], d$x[rows])
  xy_expect_drawn_at(drawn[, "y"], d$y[rows])
})

test_that("numeric groups are named by their sorted values", {
  skip_if_no_lattice()
  r <- xy_render(lattice::xyplot(mpg ~ wt, mtcars, groups = gear))
  layers <- lattice_rendered_layers(r)

  testthat::expect_identical(
    vapply(layers, `[[`, "", "name"),
    as.character(sort(unique(mtcars$gear)))
  )
  for (layer in layers) {
    rows <- mtcars$gear == as.numeric(layer$name)
    testthat::expect_equal(
      unname(xy_matrix(layer$data)),
      unname(as.matrix(mtcars[rows, c("wt", "mpg")]))
    )
    drawn <- xy_use_positions(r$doc, layer$selectors)
    xy_expect_drawn_at(drawn[, "x"], mtcars$wt[rows])
  }
})

# ------------------------------------------------------------------------------
# type = "l", "b", "o": lines
# ------------------------------------------------------------------------------

test_that("a line is read in the order it was drawn, a missing value as a gap", {
  skip_if_no_lattice()
  # Unsorted x draws a zigzag, and the missing values break it in three.
  d <- data.frame(
    x = c(3, 1, 4, 2, 6, 5, 8, 7, 9, 10),
    y = c(2, 7, NA, 8, 2, NA, NA, 8, 3, 4)
  )
  r <- xy_render(lattice::xyplot(y ~ x, d, type = "l"))
  layers <- lattice_rendered_layers(r)

  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "line")
  testthat::expect_length(layer$data, 1L)
  testthat::expect_equal(unname(xy_matrix(layer$data[[1]])), unname(as.matrix(d)))

  # The one selector matches every piece the gaps broke the line into, and
  # their vertices, in document order, are the values drawn.
  testthat::expect_length(layer$selectors, 1L)
  pieces <- lattice_selector_nodes(r$doc, layer$selectors[[1]])
  testthat::expect_length(pieces, 3L)
  vertices <- xy_polyline_vertices(r$doc, layer$selectors[[1]])
  drawn <- !is.na(d$y)
  xy_expect_drawn_at(vertices[, "x"], d$x[drawn])
  xy_expect_drawn_at(vertices[, "y"], d$y[drawn])
})

test_that("a row with no x is left out of a line, which has no position to put a gap at", {
  skip_if_no_lattice()
  # lattice breaks the line at the row, as at a missing y, but a line's
  # points are placed by their x, and this one has none: the pieces on
  # either side are read as one, as py-maidr reads matplotlib's.
  d <- data.frame(x = c(1, 2, NA, 4, 5), y = c(1, 3, 2, 5, 4))
  r <- xy_render(lattice::xyplot(y ~ x, d, type = "l"))
  layer <- lattice_rendered_layers(r)[[1]]

  kept <- !is.na(d$x)
  testthat::expect_equal(unname(xy_matrix(layer$data[[1]])), unname(as.matrix(d[kept, ])))
  testthat::expect_false(anyNA(xy_matrix(layer$data[[1]])))
  testthat::expect_length(lattice_selector_nodes(r$doc, layer$selectors[[1]]), 2L)
  vertices <- xy_polyline_vertices(r$doc, layer$selectors[[1]])
  xy_expect_drawn_at(vertices[, "x"], d$x[kept])
})

test_that("a line's gaps are where nothing was drawn, and a line drawn through none is left out", {
  skip_if_no_lattice()
  # On a log scale a zero is drawn at -Inf, which is no position: group "b"
  # breaks where it is zero, and group "c" is zero throughout.
  d <- data.frame(
    x = rep(1:5, 3),
    y = c(1, 10, 100, 1000, 10000, 5, 50, 0, 500, 5000, 0, 0, 0, 0, 0),
    g = rep(c("a", "b", "c"), each = 5)
  )
  r <- xy_render(lattice::xyplot(
    y ~ x, d,
    groups = g, type = "l", scales = list(y = list(log = 10))
  ))
  layer <- lattice_rendered_layers(r)[[1]]

  testthat::expect_length(layer$data, 2L)
  testthat::expect_length(layer$selectors, 2L)
  testthat::expect_identical(unique(xy_field(layer$data[[1]], "z")), "a")
  testthat::expect_equal(unname(xy_matrix(layer$data[[1]])), cbind(1:5, 10^(0:4)))
  testthat::expect_identical(unique(xy_field(layer$data[[2]], "z")), "b")
  testthat::expect_equal(unname(xy_matrix(layer$data[[2]])), cbind(1:5, c(5, 50, NA, 500, 5000)))

  # "b" is drawn as the two runs either side of its zero, "c" as nothing.
  testthat::expect_identical(lattice_selector_counts(r$doc, layer$selectors), c(1L, 2L))
  runs <- xy_polyline_vertices(r$doc, layer$selectors[[2]])
  xy_expect_drawn_at(runs[, "y"], log10(c(5, 50, 500, 5000)))
  testthat::expect_true(xy_has_grob(r$doc, "xyplot.lines.group.3.panel.1.1"))
  testthat::expect_length(
    lattice_selector_nodes(r$doc, lattice_grob_selector_for("xyplot.lines.group.3.panel.1.1")),
    0L
  )
})

test_that("grouped lines are one series per group, named by the group", {
  skip_if_no_lattice()
  d <- data.frame(
    x = rep(1:4, 3),
    y = c(1, 3, 2, 4, 5, 4, 6, 5, 9, 7, 8, 9),
    g = rep(c("u", "v", "w"), each = 4)
  )
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g, type = "l"))
  layers <- lattice_rendered_layers(r)

  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$axes$z$label, "g")
  testthat::expect_length(layer$data, 3L)
  testthat::expect_length(layer$selectors, 3L)
  for (i in seq_along(layer$data)) {
    level <- c("u", "v", "w")[i]
    rows <- d$g == level
    testthat::expect_identical(unique(xy_field(layer$data[[i]], "z")), level)
    testthat::expect_equal(unname(xy_matrix(layer$data[[i]])), unname(as.matrix(d[rows, 1:2])))
    testthat::expect_identical(lattice_selector_counts(r$doc, layer$selectors[[i]]), 1L)
    vertices <- xy_polyline_vertices(r$doc, layer$selectors[[i]])
    xy_expect_drawn_at(vertices[, "y"], d$y[rows])
  }
})

test_that("grouped lines that share no x value are a layer each; one shared x keeps them whole", {
  skip_if_no_lattice()
  d <- data.frame(
    x = c(1, 2, 3, 1.5, 2.5, 3.5),
    y = c(1, 3, 2, 5, 4, 6),
    g = rep(c("a", "b"), each = 3)
  )
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g, type = "l"))
  layers <- lattice_rendered_layers(r)

  testthat::expect_identical(vapply(layers, `[[`, "", "type"), c("line", "line"))
  testthat::expect_identical(vapply(layers, `[[`, "", "name"), c("a", "b"))
  testthat::expect_false(anyDuplicated(vapply(layers, `[[`, "", "id")) > 0L)
  for (i in 1:2) {
    rows <- d$g == c("a", "b")[i]
    testthat::expect_length(layers[[i]]$data, 1L)
    testthat::expect_equal(
      unname(xy_matrix(layers[[i]]$data[[1]])),
      unname(as.matrix(d[rows, 1:2]))
    )
    testthat::expect_identical(lattice_selector_counts(r$doc, layers[[i]]$selectors), 1L)
    vertices <- xy_polyline_vertices(r$doc, layers[[i]]$selectors[[1]])
    xy_expect_drawn_at(vertices[, "y"], d$y[rows])
  }

  # From an x every series passes through, Up and Down reach each of them.
  d$x[4] <- 2
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g, type = "l"))
  layers <- lattice_rendered_layers(r)
  testthat::expect_length(layers, 1L)
  testthat::expect_length(layers[[1]]$data, 2L)
  testthat::expect_null(layers[[1]]$name)
})

test_that("a group's layers say what kind they are only where a panel mixes kinds", {
  skip_if_no_lattice()
  d <- data.frame(
    x = c(1, 2, 3, 1.5, 2.5, 3.5),
    y = c(1, 3, 2, 5, 4, 6),
    g = rep(c("a", "b"), each = 3)
  )
  # Points and the lines through them: four layers named a, b, a, b would
  # not say which are the lines.
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g, type = "b"))
  layers <- lattice_rendered_layers(r)
  testthat::expect_identical(
    vapply(layers, function(layer) paste(layer$type, layer$name), ""),
    c("point a (point)", "point b (point)", "line a (line)", "line b (line)")
  )

  # One kind of layer: the group is all a name has to say.
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g))
  testthat::expect_identical(vapply(lattice_rendered_layers(r), `[[`, "", "name"), c("a", "b"))
})

test_that("type 'b' and 'o' are read as the points and then the line through them", {
  skip_if_no_lattice()
  for (type in c("b", "o")) {
    r <- xy_render(lattice::xyplot(y ~ x, xy_data, type = type))
    layers <- lattice_rendered_layers(r)

    testthat::expect_identical(vapply(layers, `[[`, "", "type"), c("point", "line"))
    data <- unname(as.matrix(xy_data))
    testthat::expect_equal(unname(xy_matrix(layers[[1]]$data)), data)
    testthat::expect_equal(unname(xy_matrix(layers[[2]]$data[[1]])), data)
    testthat::expect_identical(lattice_selector_counts(r$doc, layers[[1]]$selectors), nrow(xy_data))
    vertices <- xy_polyline_vertices(r$doc, layers[[2]]$selectors[[1]])
    xy_expect_drawn_at(vertices[, "x"], xy_data$x)
  }

  # Grouped, every group's points come before the lines.
  d <- data.frame(x = rep(1:4, 2), y = c(1, 3, 2, 4, 5, 4, 6, 5), g = rep(c("a", "b"), each = 4))
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g, type = "b"))
  layers <- lattice_rendered_layers(r)
  testthat::expect_identical(vapply(layers, `[[`, "", "type"), c("point", "point", "line"))
  # Beside a line, a group's points say what they are.
  testthat::expect_identical(vapply(layers[1:2], `[[`, "", "name"), c("a (point)", "b (point)"))
})

# ------------------------------------------------------------------------------
# type = "s", "S": staircases
# ------------------------------------------------------------------------------

#' The way a drawn staircase's risers run, from the corner after each sample
#'
#' Level first (`"hv"`), the corner keeps the sample's height; rising first
#' (`"vh"`), it keeps its x.
xy_drawn_direction <- function(vertices) {
  samples <- vertices[seq(1, nrow(vertices), by = 2), , drop = FALSE]
  corners <- vertices[seq(2, nrow(vertices), by = 2), , drop = FALSE]
  before <- samples[-nrow(samples), , drop = FALSE]
  if (all(abs(corners[, "y"] - before[, "y"]) < 0.01)) {
    "hv"
  } else if (all(abs(corners[, "x"] - before[, "x"]) < 0.01)) {
    "vh"
  } else {
    "neither"
  }
}

test_that("a staircase is read as its samples in x order, with the way its risers run", {
  skip_if_no_lattice()
  d <- data.frame(x = c(3, 1, 4, 2, 6, 5), y = c(2, 7, 1, 8, 3, 5))
  sorted <- d[order(d$x), ]
  for (type in c("s", "S")) {
    r <- xy_render(lattice::xyplot(y ~ x, d, type = type))
    layers <- lattice_rendered_layers(r)

    testthat::expect_length(layers, 1L)
    layer <- layers[[1]]
    testthat::expect_identical(layer$type, "step")
    testthat::expect_equal(unname(xy_matrix(layer$data[[1]])), unname(as.matrix(sorted)))

    vertices <- xy_polyline_vertices(r$doc, layer$selectors[[1]])
    testthat::expect_identical(nrow(vertices), 2L * nrow(d) - 1L)
    samples <- vertices[seq(1, nrow(vertices), by = 2), , drop = FALSE]
    xy_expect_drawn_at(samples[, "x"], sorted$x)
    xy_expect_drawn_at(samples[, "y"], sorted$y)
    testthat::expect_identical(layer$stepDirection, xy_drawn_direction(vertices))
  }
})

test_that("distribute.type gives each group its own kind of layer", {
  skip_if_no_lattice()
  d <- data.frame(
    x = rep(c(1, 3, 2, 5, 4), 3),
    y = c(3, 1, 4, 2, 5, 6, 8, 7, 9, 8, 2, 4, 3, 5, 1),
    g = rep(c("a", "b", "c"), each = 5)
  )

  # A staircase each way: one layer per direction, each read with the
  # direction its own staircase is drawn with.
  r <- xy_render(lattice::xyplot(
    y ~ x, d,
    groups = g, type = c("s", "S", "s"), distribute.type = TRUE
  ))
  layers <- lattice_rendered_layers(r)
  testthat::expect_identical(vapply(layers, `[[`, "", "type"), c("step", "step"))
  for (layer in layers) {
    for (i in seq_along(layer$data)) {
      level <- unique(xy_field(layer$data[[i]], "z"))
      rows <- d[d$g == level, ]
      rows <- rows[order(rows$x), ]
      testthat::expect_equal(unname(xy_matrix(layer$data[[i]])), unname(as.matrix(rows[, 1:2])))
      vertices <- xy_polyline_vertices(r$doc, layer$selectors[[i]])
      testthat::expect_identical(layer$stepDirection, xy_drawn_direction(vertices))
    }
  }
  directions <- vapply(layers, `[[`, "", "stepDirection")
  testthat::expect_setequal(directions, c("hv", "vh"))

  # Points, a line and spikes: each group is read as what it was drawn as.
  r <- xy_render(lattice::xyplot(
    y ~ x, d,
    groups = g, type = c("p", "l", "h"), distribute.type = TRUE
  ))
  layers <- lattice_rendered_layers(r)
  types <- vapply(layers, `[[`, "", "type")
  testthat::expect_setequal(types, c("point", "line", "lollipop"))
  point <- layers[[which(types == "point")]]
  testthat::expect_identical(point$name, "a (point)")
  line <- layers[[which(types == "line")]]
  testthat::expect_identical(unique(xy_field(line$data[[1]], "z")), "b")
  spikes <- layers[[which(types == "lollipop")]]
  testthat::expect_identical(spikes$name, "c (lollipop)")
  testthat::expect_equal(unname(xy_matrix(spikes$data)), unname(as.matrix(d[d$g == "c", 1:2])))
})

# ------------------------------------------------------------------------------
# type = "h": spikes
# ------------------------------------------------------------------------------

test_that("spikes are read as their values, one per spike drawn", {
  skip_if_no_lattice()
  d <- data.frame(x = c(1, 2, 3, 4, 5, 6), y = c(3, -1, NA, 4, 2, 5))
  r <- xy_render(lattice::xyplot(y ~ x, d, type = "h"))
  layers <- lattice_rendered_layers(r)

  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "lollipop")
  testthat::expect_null(layer$orientation)
  kept <- !is.na(d$y)
  testthat::expect_equal(unname(xy_matrix(layer$data)), unname(as.matrix(d[kept, ])))

  # One two-vertex polyline per spike drawn: the value end first, then the
  # baseline, at 0 where 0 is on the axis.
  nodes <- lattice_selector_nodes(r$doc, layer$selectors)
  testthat::expect_length(nodes, sum(kept))
  spikes <- lapply(seq_along(nodes), function(i) xy_vertices_of(nodes[[i]]))
  tops <- do.call(rbind, lapply(spikes, function(v) v[1, ]))
  bases <- do.call(rbind, lapply(spikes, function(v) v[2, ]))
  xy_expect_drawn_at(tops[, "x"], d$x[kept])
  xy_expect_drawn_at(tops[, "y"], d$y[kept])
  to_y <- xy_scale(tops[, "y"], d$y[kept])
  testthat::expect_equal(to_y(bases[, "y"]), rep(0, sum(kept)), tolerance = 1e-3)
})

test_that("spikes are read along the axis whatever order the rows are in", {
  skip_if_no_lattice()
  d <- data.frame(x = c(3, 1, 2, 5), y = c(5, 6, 7, 2))
  colours <- c("red", "blue", "green", "black")
  r <- xy_render(lattice::xyplot(y ~ x, d, type = "h", col = colours))
  layer <- lattice_rendered_layers(r)[[1]]
  along <- order(d$x)
  testthat::expect_equal(unname(xy_matrix(layer$data)), unname(as.matrix(d[along, ])))

  # The marks the selector matches, in document order, stand at those
  # values, and each spike keeps the colour its row was given.
  nodes <- lattice_selector_nodes(r$doc, layer$selectors)
  tops <- do.call(rbind, lapply(seq_along(nodes), function(i) xy_vertices_of(nodes[[i]])[1, ]))
  xy_expect_drawn_at(tops[, "x"], d$x[along])
  xy_expect_drawn_at(tops[, "y"], d$y[along])
  rgb <- grDevices::col2rgb(colours[along])
  testthat::expect_identical(
    xml2::xml_attr(nodes, "stroke"),
    sprintf("rgb(%d,%d,%d)", rgb[1, ], rgb[2, ], rgb[3, ])
  )
})

test_that("grouped spikes are one layer per group, and sideways spikes are read sideways", {
  skip_if_no_lattice()
  d <- data.frame(x = 1:6, y = c(3, 1, 4, 1, 5, 9), g = rep(c("odd", "even"), 3))
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g, type = "h"))
  layers <- lattice_rendered_layers(r)
  testthat::expect_identical(vapply(layers, `[[`, "", "name"), c("even", "odd"))
  for (layer in layers) {
    rows <- d$g == layer$name
    testthat::expect_equal(unname(xy_matrix(layer$data)), unname(as.matrix(d[rows, 1:2])))
    testthat::expect_identical(lattice_selector_counts(r$doc, layer$selectors), sum(rows))
  }

  # horizontal = TRUE draws each spike from the left edge at its level.
  f <- data.frame(
    level = factor(c("low", "mid", "high"), levels = c("low", "mid", "high")),
    v = c(2, 5, 3)
  )
  r <- xy_render(lattice::xyplot(level ~ v, f, type = "h", horizontal = TRUE))
  layer <- lattice_rendered_layers(r)[[1]]
  testthat::expect_identical(layer$orientation, "horz")
  testthat::expect_equal(vapply(layer$data, function(p) as.numeric(p$x), numeric(1)), f$v)
  testthat::expect_identical(xy_field(layer$data, "y"), as.character(f$level))
  nodes <- lattice_selector_nodes(r$doc, layer$selectors)
  tops <- do.call(rbind, lapply(seq_along(nodes), function(i) xy_vertices_of(nodes[[i]])[1, ]))
  bases <- do.call(rbind, lapply(seq_along(nodes), function(i) xy_vertices_of(nodes[[i]])[2, ]))
  xy_expect_drawn_at(tops[, "x"], f$v)
  # Level with each other: the spikes run along x.
  testthat::expect_equal(tops[, "y"], bases[, "y"])
})

# ------------------------------------------------------------------------------
# type = "r", "smooth", "spline", "a": fitted and averaged lines
# ------------------------------------------------------------------------------

test_that("a least-squares fit is read as the ends of the line drawn, which lie on lm()", {
  skip_if_no_lattice()
  d <- data.frame(x = 1:8, y = c(2.1, 3.9, 6.2, 7.8, 10.1, 12.2, 13.8, 16.1))
  chart <- lattice::xyplot(y ~ x, d, type = c("p", "r"))
  r <- xy_render(chart)
  layers <- lattice_rendered_layers(r)

  testthat::expect_identical(vapply(layers, `[[`, "", "type"), c("point", "smooth"))
  fit <- layers[[2]]
  ends <- xy_matrix(fit$data[[1]])
  testthat::expect_identical(nrow(ends), 2L)
  model <- stats::lm(y ~ x, d)
  testthat::expect_equal(
    unname(ends[, "y"]),
    unname(stats::predict(model, data.frame(x = ends[, "x"]))),
    tolerance = 1e-8
  )
  # The line is drawn across the panel, from border to border: each end on
  # an edge of lattice's own limits.
  on_edge <- function(value, limits) {
    abs(value - limits[1]) < 1e-8 | abs(value - limits[2]) < 1e-8
  }
  testthat::expect_true(all(
    on_edge(ends[, "x"], chart$x.limits) | on_edge(ends[, "y"], chart$y.limits)
  ))

  vertices <- xy_polyline_vertices(r$doc, fit$selectors[[1]])
  testthat::expect_identical(nrow(vertices), 2L)
  points <- xy_use_positions(r$doc, layers[[1]]$selectors)
  to_x <- xy_scale(points[, "x"], d$x)
  testthat::expect_equal(to_x(vertices[, "x"]), unname(ends[, "x"]), tolerance = 1e-3)
})

test_that("a loess smooth is the curve loess.smooth() computes, one series per group", {
  skip_if_no_lattice()
  r <- xy_render(lattice::xyplot(y ~ x, xy_data, type = c("p", "smooth")))
  layers <- lattice_rendered_layers(r)
  testthat::expect_identical(vapply(layers, `[[`, "", "type"), c("point", "smooth"))

  # panel.loess()'s own defaults.
  expected <- stats::loess.smooth(
    xy_data$x, xy_data$y,
    span = 2 / 3, degree = 1, family = "symmetric", evaluation = 50
  )
  curve <- layers[[2]]
  testthat::expect_equal(unname(xy_matrix(curve$data[[1]])), cbind(expected$x, expected$y))
  vertices <- xy_polyline_vertices(r$doc, curve$selectors[[1]])
  testthat::expect_identical(nrow(vertices), 50L)
  xy_expect_drawn_at(vertices[, "x"], expected$x)

  # A span given to the chart reaches the fit, and each group has its own.
  set.seed(3)
  d <- data.frame(x = rep(1:15, 2), g = rep(c("a", "b"), each = 15))
  d$y <- ifelse(d$g == "a", sin(d$x / 3), cos(d$x / 4)) + stats::rnorm(30, sd = 0.1)
  r <- xy_render(lattice::xyplot(y ~ x, d, groups = g, type = "smooth", span = 0.8))
  curve <- lattice_rendered_layers(r)[[1]]
  testthat::expect_identical(curve$type, "smooth")
  testthat::expect_identical(curve$axes$z$label, "g")
  for (i in 1:2) {
    level <- c("a", "b")[i]
    rows <- d$g == level
    expected <- stats::loess.smooth(
      d$x[rows], d$y[rows],
      span = 0.8, degree = 1, family = "symmetric", evaluation = 50
    )
    testthat::expect_identical(unique(xy_field(curve$data[[i]], "z")), level)
    testthat::expect_equal(unname(xy_matrix(curve$data[[i]])), cbind(expected$x, expected$y))
  }
})

test_that("a spline is smooth.spline() predicted where panel.spline() predicts it", {
  skip_if_no_lattice()
  r <- xy_render(lattice::xyplot(y ~ x, xy_data, type = c("p", "spline")))
  curve <- lattice_rendered_layers(r)[[2]]
  testthat::expect_identical(curve$type, "smooth")

  fit <- stats::smooth.spline(xy_data$x, xy_data$y)
  at <- seq(min(xy_data$x), max(xy_data$x), length.out = 102)
  expected <- stats::predict(fit, x = at)
  testthat::expect_equal(unname(xy_matrix(curve$data[[1]])), cbind(expected$x, expected$y))
  testthat::expect_identical(
    nrow(xy_polyline_vertices(r$doc, curve$selectors[[1]])),
    length(at)
  )
})

test_that("a fit over a factor axis is shown as an image, not read by the levels' positions", {
  skip_if_no_lattice()
  # lattice fits the curve to the levels' positions, 1..5, and draws it
  # between them and out to the panel's edges, 0.4 and 5.6, where the axis
  # names nothing: read as drawn, the first point would be "f is 1" where
  # the axis says "lo".
  levels <- c("lo", "mid", "hi", "top", "max")
  d <- data.frame(
    f = factor(rep(levels, each = 3), levels = levels),
    v = c(2, 3, 4, 5, 6, 5, 7, 9, 8, 6, 8, 7, 9, 12, 10),
    g = rep(c("a", "b", "c"), 5)
  )
  charts <- list(
    lattice::stripplot(v ~ f, d, type = c("p", "smooth")),
    lattice::stripplot(v ~ f, d, groups = g, type = c("p", "r")),
    lattice::stripplot(f ~ v, d, type = c("p", "r")),
    lattice::dotplot(f ~ v, d, type = c("p", "spline")),
    lattice::xyplot(v ~ f, d, type = c("p", "smooth"))
  )
  for (chart in charts) {
    r <- render_lattice(chart)
    testthat::expect_true(r$fallback)
    testthat::expect_identical(
      r$orchestrator$unsupported_reasons(),
      "its smooth marks could not be read"
    )
  }

  # The average of type "a" has a value at each level, and is read, named
  # by the level.
  r <- xy_render(lattice::stripplot(v ~ f, d, type = c("p", "a")))
  average <- lattice_rendered_layers(r)[[2]]
  testthat::expect_identical(average$type, "line")
  testthat::expect_identical(xy_field(average$data[[1]], "x"), levels)
})

test_that("the average line of type 'a' is the mean of y at each x", {
  skip_if_no_lattice()
  set.seed(5)
  d <- data.frame(x = rep(c(2, 1, 3, 5, 4), each = 3), y = round(stats::rnorm(15, 10, 2), 2))
  r <- xy_render(lattice::xyplot(y ~ x, d, type = c("p", "a")))
  layers <- lattice_rendered_layers(r)

  testthat::expect_identical(vapply(layers, `[[`, "", "type"), c("point", "line"))
  means <- stats::aggregate(y ~ x, d, mean)
  testthat::expect_equal(unname(xy_matrix(layers[[2]]$data[[1]])), unname(as.matrix(means)))
  vertices <- xy_polyline_vertices(r$doc, layers[[2]]$selectors[[1]])
  xy_expect_drawn_at(vertices[, "y"], means$y)
})

test_that("grids and reference lines are drawn but not read", {
  skip_if_no_lattice()
  plain <- lattice_rendered_layers(xy_render(lattice::xyplot(y ~ x, xy_data)))

  decorated <- list(
    list(
      chart = lattice::xyplot(y ~ x, xy_data, type = c("p", "g")),
      grobs = c("grid.h", "grid.v")
    ),
    list(chart = lattice::xyplot(y ~ x, xy_data, grid = TRUE), grobs = c("grid.h", "grid.v")),
    list(chart = lattice::xyplot(y ~ x, xy_data, abline = c(0, 1)), grobs = "abline.segments"),
    list(
      chart = lattice::xyplot(y ~ x, xy_data, abline = list(h = 4, v = 5)),
      grobs = c("abline.h", "abline.v")
    )
  )
  for (case in decorated) {
    r <- xy_render(case$chart)
    for (grob in case$grobs) {
      testthat::expect_true(xy_has_grob(r$doc, paste0(grob, ".panel.1.1")))
    }
    layers <- lattice_rendered_layers(r)
    testthat::expect_length(layers, 1L)
    testthat::expect_identical(layers[[1]]$type, "point")
    testthat::expect_identical(layers[[1]]$data, plain[[1]]$data)
    testthat::expect_identical(layers[[1]]$selectors, plain[[1]]$selectors)
  }
})

test_that("a grid behind a density, strip, dot or quantile plot is drawn but not read", {
  skip_if_no_lattice()
  d <- data.frame(
    v = c(1.2, 2.3, 2.9, 3.4, 4.8, 5.1, 6.2, 6.9),
    f = factor(rep(c("a", "b"), 4))
  )
  charts <- list(
    function(...) lattice::densityplot(~v, d, plot.points = FALSE, ...),
    function(...) lattice::stripplot(f ~ v, d, ...),
    function(...) lattice::dotplot(f ~ v, d, ...),
    function(...) lattice::qq(f ~ v, d, ...)
  )
  for (chart in charts) {
    plain <- lattice_rendered_layers(xy_render(chart()))
    r <- xy_render(chart(grid = TRUE))
    testthat::expect_true(
      xy_has_grob(r$doc, "grid.h.panel.1.1") || xy_has_grob(r$doc, "grid.v.panel.1.1")
    )
    layers <- lattice_rendered_layers(r)
    testthat::expect_identical(lapply(layers, `[[`, "type"), lapply(plain, `[[`, "type"))
    testthat::expect_identical(lapply(layers, `[[`, "data"), lapply(plain, `[[`, "data"))
    testthat::expect_identical(lapply(layers, `[[`, "selectors"), lapply(plain, `[[`, "selectors"))
  }
})

# ------------------------------------------------------------------------------
# Time series
# ------------------------------------------------------------------------------

test_that("a time series is its values at its times, named by the series", {
  skip_if_no_lattice()
  deaths <- stats::window(datasets::ldeaths, end = c(1975, 12))
  r <- xy_render(lattice::xyplot(deaths))
  layers <- lattice_rendered_layers(r)

  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "line")
  testthat::expect_null(layer$name)
  # lattice groups a series by a factor of its own whose one level, "1",
  # nothing on the chart shows: no point is announced as in group "1".
  testthat::expect_true(all(is.na(xy_field(layer$data[[1]], "z"))))
  testthat::expect_equal(
    unname(xy_matrix(layer$data[[1]])),
    cbind(as.numeric(stats::time(deaths)), as.numeric(deaths))
  )
  # lattice titles the time axis and not the values, which it draws
  # through a variable of its own named "x".
  testthat::expect_identical(layer$axes$x$label, "Time")
  testthat::expect_identical(layer$axes$y$label, "deaths")
  testthat::expect_identical(lattice_selector_counts(r$doc, layer$selectors), 1L)
  vertices <- xy_polyline_vertices(r$doc, layer$selectors[[1]])
  xy_expect_drawn_at(vertices[, "x"], as.numeric(stats::time(deaths)))
  xy_expect_drawn_at(vertices[, "y"], as.numeric(deaths))

  # Two decimals keep a monthly series' times apart, and are the default.
  testthat::expect_null(layer$axes$x$format)

  # A title the chart gives the values is the one read.
  r <- xy_render(lattice::xyplot(deaths, ylab = "Deaths"))
  testthat::expect_identical(lattice_rendered_layers(r)[[1]]$axes$y$label, "Deaths")

  # Drawn as points, a layer a group would name, the series is not named "1".
  r <- xy_render(lattice::xyplot(deaths, type = "p"))
  testthat::expect_null(lattice_rendered_layers(r)[[1]]$name)
})

test_that("several series are a panel each, titled by the series, or one layer superposed", {
  skip_if_no_lattice()
  markets <- stats::window(datasets::EuStockMarkets, end = 1991.6)
  names <- colnames(markets)

  # A panel per series, in the order lattice lays them out, top first.
  r <- xy_render(lattice::xyplot(markets))
  grid <- r$schema$subplots
  testthat::expect_identical(lengths(grid), rep(1L, length(names)))
  for (i in seq_along(names)) {
    layers <- grid[[i]][[1]]$layers
    testthat::expect_length(layers, 1L)
    testthat::expect_identical(layers[[1]]$title, names[i])
    testthat::expect_true(all(is.na(xy_field(layers[[1]]$data[[1]], "z"))))
    testthat::expect_equal(
      unname(xy_matrix(layers[[1]]$data[[1]])),
      cbind(as.numeric(stats::time(markets)), as.numeric(markets[, i]))
    )
    testthat::expect_identical(lattice_selector_counts(r$doc, layers[[1]]$selectors), 1L)
  }

  # Superposed, the series share their times: one layer, a series each,
  # between which Up and Down move.
  r <- xy_render(lattice::xyplot(markets, superpose = TRUE))
  layers <- lattice_rendered_layers(r)
  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$axes$y$label, "markets")
  # Trading days, 260 a year, are told apart by the third decimal of a
  # year, as R prints them, where two would read three days as one.
  testthat::expect_identical(layer$axes$x$format, list(type = "fixed", decimals = 3L))
  testthat::expect_length(layer$data, length(names))
  for (i in seq_along(names)) {
    testthat::expect_identical(unique(xy_field(layer$data[[i]], "z")), names[i])
    testthat::expect_equal(unname(xy_matrix(layer$data[[i]]))[, 2], as.numeric(markets[, i]))
    vertices <- xy_polyline_vertices(r$doc, layer$selectors[[i]])
    xy_expect_drawn_at(vertices[, "y"], as.numeric(markets[, i]))
  }
})

test_that("a series handed over as a value, or a formula of the same names, is not renamed", {
  skip_if_no_lattice()
  # No expression names a series passed as a value; the variable name
  # lattice gives it is all there is.
  r <- xy_render(do.call(lattice::xyplot, list(datasets::ldeaths)))
  testthat::expect_identical(lattice_rendered_layers(r)[[1]]$axes$y$label, "x")

  # A formula whose variables happen to be x and tt is not a time series.
  d <- data.frame(x = c(3, 1, 2), tt = 1:3)
  r <- xy_render(lattice::xyplot(x ~ tt, d, type = "l"))
  testthat::expect_identical(lattice_rendered_layers(r)[[1]]$axes$y$label, "x")
})

# ------------------------------------------------------------------------------
# stripplot()
# ------------------------------------------------------------------------------

test_that("a jittered stripplot is read at its levels' positions, named by the level", {
  skip_if_no_lattice()
  d <- data.frame(
    f = factor(c("lo", "mid", "hi", "lo", "mid", "hi", "lo", "mid"), levels = c("lo", "mid", "hi")),
    v = c(2, 7, 1, 8, 2, 8, 5, 6)
  )
  set.seed(11)
  r <- xy_render(lattice::stripplot(f ~ v, d, jitter.data = TRUE))
  layer <- lattice_rendered_layers(r)[[1]]

  testthat::expect_identical(layer$type, "point")
  testthat::expect_equal(unname(xy_matrix(layer$data)), cbind(d$v, as.integer(d$f)))
  testthat::expect_identical(xy_field(layer$data, "yLabel"), as.character(d$f))
  testthat::expect_identical(layer$axes$y$label, "f")

  # The levels were jittered as drawn, the values not.
  drawn <- xy_use_positions(r$doc, layer$selectors)
  testthat::expect_identical(nrow(drawn), nrow(d))
  xy_expect_drawn_at(drawn[, "x"], d$v)
  testthat::expect_gt(max(abs(stats::residuals(stats::lm(drawn[, "y"] ~ as.integer(d$f))))), 0.1)

  # Jittered by more than half a level, a point is drawn nearer the next
  # level than its own; it is still read at its own.
  set.seed(4)
  r <- xy_render(lattice::stripplot(f ~ v, d, jitter.data = TRUE, amount = 0.8))
  layer <- lattice_rendered_layers(r)[[1]]
  drawn <- xy_use_positions(r$doc, layer$selectors)
  # A category axis is drawn without tick marks; its labels stand at the
  # levels, a few pixels off for the text's baseline.
  levels_at <- xy_ticklabels(r$doc, "left")
  testthat::expect_identical(levels_at$text, levels(d$f))
  nearest <- vapply(drawn[, "y"], function(y) which.min(abs(levels_at$px - y)), integer(1))
  testthat::expect_true(any(nearest != as.integer(d$f)))
  testthat::expect_identical(xy_field(layer$data, "yLabel"), as.character(d$f))
  testthat::expect_equal(unname(xy_matrix(layer$data)), cbind(d$v, as.integer(d$f)))

  # Grouped, one layer per group, each at its levels.
  d$g <- rep(c("a", "b"), 4)
  set.seed(12)
  r <- xy_render(lattice::stripplot(v ~ f, d, groups = g, jitter.data = TRUE))
  layers <- lattice_rendered_layers(r)
  testthat::expect_identical(vapply(layers, `[[`, "", "name"), c("a", "b"))
  for (layer in layers) {
    rows <- d$g == layer$name
    testthat::expect_equal(unname(xy_matrix(layer$data)), cbind(as.integer(d$f[rows]), d$v[rows]))
    testthat::expect_identical(xy_field(layer$data, "xLabel"), as.character(d$f[rows]))
    testthat::expect_identical(lattice_selector_counts(r$doc, layer$selectors), sum(rows))
  }
})

# ------------------------------------------------------------------------------
# qqmath() and qq()
# ------------------------------------------------------------------------------

test_that("qqmath() is read as the theoretical quantiles against the sorted sample", {
  skip_if_no_lattice()
  y <- c(4.1, 6.3, NA, 5.2, 9.8, 3.3, 7.7, 5.9, 6.1, 2.4)
  r <- xy_render(lattice::qqmath(~y))
  layer <- lattice_rendered_layers(r)[[1]]

  observed <- sort(y)
  testthat::expect_identical(layer$type, "point")
  testthat::expect_equal(
    unname(xy_matrix(layer$data)),
    unname(cbind(stats::qnorm(stats::ppoints(length(observed))), observed))
  )
  testthat::expect_identical(layer$axes$x$label, "qnorm")
  drawn <- xy_use_positions(r$doc, layer$selectors)
  xy_expect_drawn_at(drawn[, "x"], stats::qnorm(stats::ppoints(length(observed))))
  xy_expect_drawn_at(drawn[, "y"], observed)

  # Another distribution, and a group each.
  g <- rep(c("a", "b"), 5)
  r <- xy_render(lattice::qqmath(~y, groups = g, distribution = stats::qunif))
  layers <- lattice_rendered_layers(r)
  testthat::expect_identical(vapply(layers, `[[`, "", "name"), c("a", "b"))
  for (layer in layers) {
    sample <- sort(y[g == layer$name])
    testthat::expect_equal(
      unname(xy_matrix(layer$data)),
      unname(cbind(stats::qunif(stats::ppoints(length(sample))), sample))
    )
    testthat::expect_identical(lattice_selector_counts(r$doc, layer$selectors), length(sample))
  }
})

test_that("qq() is read as the quantiles lattice pairs, not stats::qqplot()'s", {
  skip_if_no_lattice()
  d <- data.frame(
    v = c(3.1, 4.7, 5.2, 6.8, 7.4, 8.1, NA, 2.2, 4.4, 6.6, 8.8, 9.9),
    g = factor(rep(c("ctl", "trt"), c(7, 5)))
  )
  r <- xy_render(lattice::qq(g ~ v, d))
  layer <- lattice_rendered_layers(r)[[1]]

  # qq() pairs quantiles at ppoints(n, a = 1) for the larger sample's size,
  # its missing value counted, with quantile()'s default type.
  ctl <- d$v[d$g == "ctl"]
  trt <- d$v[d$g == "trt"]
  p <- stats::ppoints(max(length(ctl), length(trt)), a = 1)
  expected <- cbind(
    stats::quantile(ctl, p, type = 7, na.rm = TRUE, names = FALSE),
    stats::quantile(trt, p, type = 7, na.rm = TRUE, names = FALSE)
  )
  testthat::expect_equal(unname(xy_matrix(layer$data)), expected)
  base <- stats::qqplot(ctl[!is.na(ctl)], trt, plot.it = FALSE)
  testthat::expect_false(isTRUE(all.equal(unname(xy_matrix(layer$data)), cbind(base$x, base$y))))

  testthat::expect_identical(layer$axes$x$label, "ctl")
  testthat::expect_identical(layer$axes$y$label, "trt")
  drawn <- xy_use_positions(r$doc, layer$selectors)
  xy_expect_drawn_at(drawn[, "x"], expected[, 1])
  xy_expect_drawn_at(drawn[, "y"], expected[, 2])
})

# ------------------------------------------------------------------------------
# densityplot()
# ------------------------------------------------------------------------------

test_that("a density curve is density() as lattice computes it, within the drawn limits", {
  skip_if_no_lattice()
  x <- c(4.2, 5.1, 5.5, 6.3, 6.8, 7.4, 8.9, 9.6, NA, 7.1, 6.0)
  chart <- lattice::densityplot(~x)
  r <- xy_render(chart)
  layers <- lattice_rendered_layers(r)

  testthat::expect_length(layers, 1L)
  curve <- layers[[1]]
  testthat::expect_identical(curve$type, "smooth")
  testthat::expect_identical(curve$axes$y$label, "Density")
  # panel.densityplot()'s `darg`, keeping what falls strictly inside the
  # panel's x limits -- lattice's own, from the chart.
  h <- stats::density(x, n = 512, na.rm = TRUE)
  inside <- h$x > min(chart$x.limits) & h$x < max(chart$x.limits)
  testthat::expect_equal(unname(xy_matrix(curve$data[[1]])), cbind(h$x[inside], h$y[inside]))
  vertices <- xy_polyline_vertices(r$doc, curve$selectors[[1]])
  testthat::expect_identical(nrow(vertices), sum(inside))
  xy_expect_drawn_at(vertices[, "x"], h$x[inside])

  # Limits narrower than the curve cut it; a bandwidth, kernel and grid
  # given to the chart reach density().
  chart <- lattice::densityplot(~x, xlim = c(5, 8), bw = 0.5, kernel = "rectangular", n = 100)
  curve <- lattice_rendered_layers(xy_render(chart))[[1]]
  h <- stats::density(x, bw = 0.5, kernel = "rectangular", n = 100, na.rm = TRUE)
  inside <- h$x > 5 & h$x < 8
  testthat::expect_lt(sum(inside), 100L)
  testthat::expect_equal(unname(xy_matrix(curve$data[[1]])), cbind(h$x[inside], h$y[inside]))
})

test_that("grouped densities share no x value, so each is a layer of its own", {
  skip_if_no_lattice()
  # Each group's density is evaluated over its own range, and the frontend
  # moves Up and Down only onto a series with a point at the reader's x:
  # kept in one layer, no group but the first could be reached.
  d <- data.frame(
    v = c(1.2, 2.3, 2.9, 3.4, 4.8, 5.1, 6.2, 6.9, 7.7, 8.4, 3.3, 5.5),
    g = rep(c("a", "b", "c"), 4)
  )
  chart <- lattice::densityplot(~v, d, groups = g)
  r <- xy_render(chart)
  layers <- lattice_rendered_layers(r)

  testthat::expect_length(layers, 3L)
  testthat::expect_false(anyDuplicated(vapply(layers, `[[`, "", "id")) > 0L)
  for (i in 1:3) {
    curve <- layers[[i]]
    level <- c("a", "b", "c")[i]
    testthat::expect_identical(curve$type, "smooth")
    testthat::expect_identical(curve$name, level)
    testthat::expect_identical(curve$axes$z$label, "g")
    testthat::expect_length(curve$data, 1L)
    testthat::expect_length(curve$selectors, 1L)
    h <- stats::density(d$v[d$g == level], n = 512)
    inside <- h$x > min(chart$x.limits) & h$x < max(chart$x.limits)
    testthat::expect_identical(unique(xy_field(curve$data[[1]], "z")), level)
    testthat::expect_equal(unname(xy_matrix(curve$data[[1]])), cbind(h$x[inside], h$y[inside]))
    testthat::expect_identical(lattice_selector_counts(r$doc, curve$selectors[[1]]), 1L)
  }
})

test_that("the observations under a density curve are drawn but only the curve is read", {
  skip_if_no_lattice()
  x <- c(4.2, 5.1, 5.5, 6.3, 6.8, 7.4, 8.9, 9.6, 7.1, 6.0)
  curve_of <- function(chart) lattice_rendered_layers(xy_render(chart))

  expected <- curve_of(lattice::densityplot(~x, plot.points = FALSE))
  testthat::expect_length(expected, 1L)

  cases <- list(
    list(points = "jitter", grob = "density.points.panel.1.1"),
    list(points = TRUE, grob = "density.points.panel.1.1"),
    list(points = "rug", grob = "density rug.x.panel.1.1")
  )
  for (case in cases) {
    set.seed(1)
    chart <- lattice::densityplot(~x, plot.points = case$points)
    r <- xy_render(chart)
    testthat::expect_true(xy_has_grob(r$doc, case$grob))
    layers <- lattice_rendered_layers(r)
    testthat::expect_length(layers, 1L)
    testthat::expect_identical(layers[[1]]$type, "smooth")
    testthat::expect_identical(layers[[1]]$data, expected[[1]]$data)
  }

  # The reference line at zero is decoration.
  r <- xy_render(lattice::densityplot(~x, ref = TRUE, plot.points = FALSE))
  testthat::expect_true(xy_has_grob(r$doc, "density abline.h.panel.1.1"))
  layers <- lattice_rendered_layers(r)
  testthat::expect_length(layers, 1L)
  testthat::expect_identical(layers[[1]]$data, expected[[1]]$data)
})
