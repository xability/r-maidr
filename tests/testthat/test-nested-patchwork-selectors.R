# Non-violin geoms inside a NESTED patchwork (issue #64).
#
# `(b1 | b2) / s` keeps the inner row's panels inside a child gtable, so a
# panel lookup that scanned only the top level of the composition found
# nothing and the nested leaves emitted `selectors: []`. That is not a
# cosmetic loss: MAIDR.js hands an empty selector list to
# `querySelectorAll("")`, which throws and leaves the WHOLE figure inert.
#
# These tests pin the emitted payload for the geoms that were affected:
# every layer must carry selectors, every selector must address an element
# of the exported SVG, and the marks it addresses must be the leaf's own —
# a lookup that lands on a neighbour's panel resolves just as happily.

skip_if_no_patchwork <- function() {
  testthat::skip_if_not_installed("patchwork")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

# mpg$class has 7 levels and mpg$drv has 3, so the two bar leaves are told
# apart by their mark counts alone.
nested_bar_a <- function() {
  ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) + ggplot2::geom_bar()
}

nested_bar_b <- function() {
  ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(drv)) + ggplot2::geom_bar()
}

nested_point <- function() {
  ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(displ, hwy)) + ggplot2::geom_point()
}

nested_box <- function() {
  ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) + ggplot2::geom_boxplot()
}

nested_line <- function() {
  ggplot2::ggplot(
    data.frame(x = 1:20, y = (1:20)^1.5),
    ggplot2::aes(x, y)
  ) + ggplot2::geom_line()
}

# A full render is several seconds (ggplot_build + patchworkGrob + grid.draw
# + gridSVG) and several tests interrogate the same composition, so results
# are cached per named composition for the duration of the file.
nested_cache <- new.env(parent = emptyenv())

render_nested <- function(plot, key) {
  if (!is.null(nested_cache[[key]])) {
    return(nested_cache[[key]])
  }

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(plot, file))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  raw <- regmatches(
    html, gregexpr('maidr-data="([^"]*)"', html, perl = TRUE)
  )[[1]]
  expect_gt(length(raw), 0)

  json <- sub('"$', "", sub('^maidr-data="', "", raw[1]))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  out <- list(
    data = jsonlite::fromJSON(json, simplifyVector = FALSE),
    doc = xml2::read_html(html)
  )
  assign(key, out, envir = nested_cache)
  out
}

# Selectors are CSS ("#geom_rect\\.rect\\.2\\.1 rect"); the SVG is addressed
# by id, so strip the element part and the CSS escaping.
selector_ids <- function(layer) {
  flat <- unlist(layer$selectors, use.names = FALSE)
  flat <- flat[vapply(flat, is.character, logical(1))]
  ids <- sub(" .*$", "", flat)
  ids <- sub("^[a-zA-Z]*#", "", ids)
  unique(gsub("\\\\", "", ids))
}

expect_selectors_resolve <- function(payload, layer, label) {
  ids <- selector_ids(layer)
  expect_gt(length(ids), 0)
  for (id in ids) {
    found <- xml2::xml_find_all(payload$doc, sprintf("//*[@id='%s']", id))
    expect_gt(length(found), 0)
  }
  invisible(ids)
}

# Number of drawn marks under everything this layer's selectors address.
# Comparing it with the layer's own data length is what catches a lookup
# that resolved to a NEIGHBOUR's panel: those selectors resolve too, they
# just describe the wrong number of bars or points.
selector_mark_count <- function(payload, layer) {
  total <- 0L
  for (id in selector_ids(layer)) {
    node <- xml2::xml_find_first(payload$doc, sprintf("//*[@id='%s']", id))
    if (inherits(node, "xml_missing")) {
      next
    }
    marks <- xml2::xml_find_all(
      node, ".//*[local-name()='rect' or local-name()='use']"
    )
    total <- total + length(marks)
  }
  total
}

cell <- function(payload, row, col) {
  payload$data$subplots[[row]][[col]]
}

test_that("every layer of a nested patchwork emits resolving selectors", {
  skip_if_no_patchwork()

  payload <- render_nested(
    (nested_bar_a() | nested_bar_b()) / nested_point(),
    "bars_over_point"
  )

  positions <- list(c(1, 1), c(1, 2), c(2, 1))
  for (pos in positions) {
    subplot <- cell(payload, pos[1], pos[2])
    label <- sprintf("subplot[%d][%d]", pos[1], pos[2])
    expect_gt(length(subplot$layers), 0)
    for (layer in subplot$layers) {
      expect_selectors_resolve(payload, layer, label)
    }
  }
})

test_that("a nested leaf's selectors address its own panel, not a sibling's", {
  skip_if_no_patchwork()

  payload <- render_nested(
    (nested_bar_a() | nested_bar_b()) / nested_point(),
    "bars_over_point"
  )

  # class has 7 levels, drv has 3, mpg has 234 rows: a selector that landed
  # on the wrong panel would come back with the neighbour's count.
  expected <- list(
    list(pos = c(1, 1), n = 7),
    list(pos = c(1, 2), n = 3),
    list(pos = c(2, 1), n = nrow(ggplot2::mpg))
  )

  for (want in expected) {
    subplot <- cell(payload, want$pos[1], want$pos[2])
    layer <- subplot$layers[[1]]
    expect_equal(length(layer$data), want$n)
    expect_equal(selector_mark_count(payload, layer), want$n)
  }
})

test_that("both rows of a 2x2 nested patchwork resolve", {
  skip_if_no_patchwork()

  payload <- render_nested(
    (nested_bar_a() | nested_bar_b()) / (nested_point() | nested_bar_b()),
    "two_by_two"
  )

  # Before the fix every cell of this layout emitted an empty selector list,
  # because the top level holds only nested-patchwork placeholders.
  expected <- list(
    list(pos = c(1, 1), n = 7),
    list(pos = c(1, 2), n = 3),
    list(pos = c(2, 1), n = nrow(ggplot2::mpg)),
    list(pos = c(2, 2), n = 3)
  )

  for (want in expected) {
    subplot <- cell(payload, want$pos[1], want$pos[2])
    layer <- subplot$layers[[1]]
    expect_selectors_resolve(
      payload, layer,
      sprintf("subplot[%d][%d]", want$pos[1], want$pos[2])
    )
    expect_equal(selector_mark_count(payload, layer), want$n)
  }
})

test_that("box and line leaves resolve inside a nested row", {
  skip_if_no_patchwork()

  payload <- render_nested(
    (nested_box() | nested_line()) / nested_point(),
    "box_line_over_point"
  )

  box_layer <- cell(payload, 1, 1)$layers[[1]]
  expect_equal(box_layer$type, "box")
  expect_selectors_resolve(payload, box_layer, "subplot[1][1]")

  line_layer <- cell(payload, 1, 2)$layers[[1]]
  expect_equal(line_layer$type, "line")
  expect_selectors_resolve(payload, line_layer, "subplot[1][2]")

  point_layer <- cell(payload, 2, 1)$layers[[1]]
  expect_equal(point_layer$type, "point")
  expect_selectors_resolve(payload, point_layer, "subplot[2][1]")
})

test_that("the remaining panel-scoped geoms resolve inside a nested row", {
  skip_if_no_patchwork()

  # These four fell into a different failure mode than the bar and point
  # leaves: instead of an empty list they fabricated a plausible-looking
  # fallback selector, so the payload looked healthy while addressing an
  # element that does not exist.
  heat_df <- expand.grid(a = letters[1:4], b = LETTERS[1:3])
  heat_df$v <- seq_len(nrow(heat_df))

  heat <- ggplot2::ggplot(heat_df, ggplot2::aes(a, b, fill = v)) +
    ggplot2::geom_tile()
  hist <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(hwy)) +
    ggplot2::geom_histogram(bins = 10)
  smooth <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(displ, hwy)) +
    ggplot2::geom_smooth(method = "lm", se = FALSE)
  stacked <- ggplot2::ggplot(
    ggplot2::mpg, ggplot2::aes(class, fill = drv)
  ) + ggplot2::geom_bar()
  dodged <- ggplot2::ggplot(
    ggplot2::mpg, ggplot2::aes(class, fill = drv)
  ) + ggplot2::geom_bar(position = "dodge")

  payload <- render_nested(
    (heat | hist) / (smooth | stacked) / (dodged | nested_point()),
    "three_by_two"
  )

  expected <- list(
    list(pos = c(1, 1), type = "heat"),
    list(pos = c(1, 2), type = "hist"),
    list(pos = c(2, 1), type = "smooth"),
    list(pos = c(2, 2), type = "stacked_bar"),
    list(pos = c(3, 1), type = "dodged_bar"),
    list(pos = c(3, 2), type = "point")
  )

  for (want in expected) {
    layer <- cell(payload, want$pos[1], want$pos[2])$layers[[1]]
    expect_equal(layer$type, want$type)
    expect_selectors_resolve(
      payload, layer,
      sprintf("subplot[%d][%d]", want$pos[1], want$pos[2])
    )
  }
})

test_that("a flat patchwork keeps resolving each leaf's own panel", {
  skip_if_no_patchwork()

  payload <- render_nested(nested_bar_a() | nested_bar_b(), "flat_bars")

  first <- cell(payload, 1, 1)$layers[[1]]
  second <- cell(payload, 1, 2)$layers[[1]]

  expect_equal(selector_mark_count(payload, first), 7)
  expect_equal(selector_mark_count(payload, second), 3)
  expect_false(identical(selector_ids(first), selector_ids(second)))
})
