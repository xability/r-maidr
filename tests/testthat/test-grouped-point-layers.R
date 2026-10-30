# Points drawn in a colour per group are read as one layer per group
#
# `ggplot(d, aes(x, y, colour = group)) + geom_point()` and Base R's
# `plot(x, y, col = colours[group])` with a `legend()` naming the colours draw
# groups of points. Both were read as one cloud, each point carrying the group
# in a `color` field maidr.js does not read: a reader never heard which group
# a point was in, and PageUp said "No additional layer". A grouped lattice
# `xyplot()` was already read as one layer per group, named after it; these
# are now read that way too, each layer named as the legend names its group,
# and highlighted through its own points.

skip_slow_file_on_cran()
skip_if_not_installed("xml2")
skip_if_not_installed("jsonlite")

# The layers of a rendering's only cell, and its SVG.
grouped_render <- function(html) {
  list(
    layers = layers_from(html),
    doc = xml2::read_html(html)
  )
}

# The `<use>` elements a `#id, #id, ...` selector names.
named_marks <- function(doc, selector) {
  ids <- trimws(strsplit(gsub("\\", "", selector, fixed = TRUE), ",", fixed = TRUE)[[1]])
  lapply(sub("^#", "", ids), function(id) {
    xml2::xml_find_first(doc, sprintf("//*[@id='%s']", id))
  })
}

# Each layer's marks are its own points, all drawn in one colour, and the
# layers' colours differ.
expect_layer_marks <- function(rendered) {
  colours <- character(0)
  for (layer in rendered$layers) {
    marks <- named_marks(rendered$doc, layer$selectors)
    expect_length(marks, length(layer$data))
    expect_false(any(vapply(marks, inherits, logical(1), "xml_missing")))
    stroke <- unique(vapply(marks, xml2::xml_attr, "", "stroke"))
    expect_length(stroke, 1L)
    colours <- c(colours, stroke)
  }
  expect_length(unique(colours), length(rendered$layers))
}

layer_names <- function(layers) {
  vapply(layers, function(layer) layer$name, character(1))
}

test_that("a ggplot2 scatter coloured by group is one layer per group", {
  skip_if_no_render()
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = factor(cyl))) +
    ggplot2::geom_point() +
    ggplot2::labs(colour = "Cylinders")
  rendered <- grouped_render(rendered(plot))

  expect_equal(layer_names(rendered$layers), c("Cylinders 4", "Cylinders 6", "Cylinders 8"))
  for (k in seq_along(rendered$layers)) {
    layer <- rendered$layers[[k]]
    rows <- mtcars[mtcars$cyl == c(4, 6, 8)[k], ]
    expect_equal(layer$type, "point")
    expect_equal(vapply(layer$data, function(p) p$x, 0), rows$wt)
    expect_equal(vapply(layer$data, function(p) p$y, 0), rows$mpg)
    expect_null(layer$data[[1]]$color)
  }
  expect_layer_marks(rendered)
})

test_that("a group whose name begins with the legend's title is named by itself", {
  skip_if_no_render()
  frame <- data.frame(
    x = 1:6, y = c(3, 1, 4, 1, 5, 9),
    group = rep(c("Group A", "Group B"), 3)
  )
  plot <- ggplot2::ggplot(frame, ggplot2::aes(x, y, colour = group)) +
    ggplot2::geom_point() +
    ggplot2::labs(colour = "Group")

  expect_equal(layer_names(layers_from(rendered(plot))), c("Group A", "Group B"))
})

test_that("a colour mapped to a continuous value is not a group", {
  skip_if_no_render()
  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = hp)) +
    ggplot2::geom_point()
  layers <- layers_from(rendered(plot))

  expect_length(layers, 1)
  expect_length(layers[[1]]$data, nrow(mtcars))
})

test_that("a volcano plot coloured by group stays one volcano layer", {
  skip_if_no_render()
  # Read through the point processor too, but one reading with its
  # threshold; its groups are each point's region.
  genes <- data.frame(
    log2fc = c(-2, -1.5, 0.1, 0.2, 1.8, 2.4),
    padj = c(1e-4, 0.02, 0.6, 0.8, 1e-3, 1e-5),
    gene = paste0("g", 1:6)
  )
  genes$regulation <- ifelse(genes$padj < 0.05, ifelse(genes$log2fc > 0, "up", "down"), "ns")
  plot <- ggplot2::ggplot(
    genes,
    ggplot2::aes(log2fc, -log10(padj), colour = regulation)
  ) +
    maidr_volcano(
      ggplot2::aes(label = gene, region = regulation),
      significance = -log10(0.05)
    )
  layers <- layers_from(rendered(plot))

  expect_length(layers, 1)
  expect_equal(layers[[1]]$type, "volcano")
  expect_length(layers[[1]]$data, nrow(genes))
})

# What `save_html()` exports for a Base R `draw()`.
base_r_grouped <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      clear_base_r_device(device_id)
      if (device_id %in% grDevices::dev.list()) grDevices::dev.off(device_id)
      unlink(file)
    },
    add = TRUE
  )
  draw()
  suppressWarnings(suppressMessages(save_html(file = file)))
  grouped_render(paste(readLines(file, warn = FALSE), collapse = "\n"))
}

test_that("a Base R scatter coloured by group is one layer per legend entry", {
  skip_if_no_render()
  colours <- c("4" = "steelblue", "6" = "coral", "8" = "forestgreen")
  rendered <- base_r_grouped(function() {
    plot(mtcars$wt, mtcars$mpg, pch = 19, col = colours[as.character(mtcars$cyl)])
    legend("topright", legend = c("4 cyl", "6 cyl", "8 cyl"), col = colours, pch = 19)
  })

  expect_equal(layer_names(rendered$layers), c("4 cyl", "6 cyl", "8 cyl"))
  for (k in seq_along(rendered$layers)) {
    rows <- mtcars[mtcars$cyl == c(4, 6, 8)[k], ]
    expect_equal(vapply(rendered$layers[[k]]$data, function(p) p$y, 0), rows$mpg)
  }
  expect_layer_marks(rendered)
})

test_that("a legend's title names the groups with their entries", {
  skip_if_no_render()
  rendered <- base_r_grouped(function() {
    plot(1:6, c(3, 1, 4, 1, 5, 9), col = rep(c("red", "blue"), 3))
    legend("topleft", legend = c("a", "b"), col = c("red", "blue"), pch = 1, title = "Batch")
  })

  expect_equal(layer_names(rendered$layers), c("Batch a", "Batch b"))
})

test_that("Base R points of colours no legend names are read as one layer", {
  skip_if_no_render()
  rendered <- base_r_grouped(function() {
    plot(1:6, c(3, 1, 4, 1, 5, 9), col = rep(c("red", "blue"), 3))
  })

  expect_length(rendered$layers, 1)
  expect_length(rendered$layers[[1]]$data, 6)
})

test_that("points of a colour the legend does not name are read as one layer", {
  skip_if_no_render()
  # Three colours drawn, two named: the third names no group, so no colour
  # is taken for one.
  rendered <- base_r_grouped(function() {
    plot(1:6, c(3, 1, 4, 1, 5, 9), col = rep(c("red", "blue", "darkgreen"), 2))
    legend("topleft", legend = c("a", "b"), col = c("red", "blue"), pch = 1)
  })

  expect_length(rendered$layers, 1)
  expect_length(rendered$layers[[1]]$data, 6)
})

test_that("a lattice key's title names the groups with their levels", {
  skip_if_no_lattice()
  skip_if_no_render()
  plot <- lattice::xyplot(
    mpg ~ wt, data = mtcars, groups = factor(cyl),
    auto.key = list(title = "Cylinders", columns = 3)
  )
  layers <- lattice_rendered_layers(render_lattice(plot))

  expect_equal(layer_names(layers), c("Cylinders 4", "Cylinders 6", "Cylinders 8"))
})

test_that("each group of a strip chart is a layer named after it", {
  skip_if_no_render()
  rendered <- base_r_grouped(function() {
    stripchart(count ~ spray, data = InsectSprays)
  })

  expect_equal(layer_names(rendered$layers), LETTERS[1:6])
  expect_null(rendered$layers[[1]]$fill)
})
