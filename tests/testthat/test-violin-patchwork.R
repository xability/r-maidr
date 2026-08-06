# Violin plots combined with patchwork (issue #52).
#
# A violin leaf used to emit a subplot with zero layers, leaving that panel
# completely silent. These tests pin the emitted payload: two layers, panel
# scoped selectors that resolve against the exported SVG, and KDE highlight
# coordinates that land on the violin they describe.

skip_if_no_patchwork <- function() {
  testthat::skip_if_not_installed("patchwork")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

violin_plot <- function() {
  ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) + ggplot2::geom_violin()
}

bar_plot <- function() {
  ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) + ggplot2::geom_bar()
}

point_plot <- function() {
  ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(displ, hwy)) + ggplot2::geom_point()
}

# Render through the real pipeline and return both the parsed maidr-data and
# the exported SVG, so selectors can be checked against the document they are
# meant to address.
render_payload <- function(plot) {
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

  list(
    data = jsonlite::fromJSON(json, simplifyVector = FALSE),
    doc = xml2::read_html(html),
    json = json
  )
}

layer_types <- function(subplot) {
  vapply(subplot$layers, function(l) as.character(l$type), character(1))
}

selector_ids <- function(layer) {
  flat <- unlist(layer$selectors, use.names = FALSE)
  flat <- flat[vapply(flat, is.character, logical(1))]
  ids <- sub(" .*$", "", flat)
  ids <- sub("^[a-zA-Z]*#", "", ids)
  gsub("\\\\", "", ids)
}

expect_selectors_resolve <- function(payload, layer) {
  ids <- selector_ids(layer)
  expect_gt(length(ids), 0)
  for (id in ids) {
    found <- xml2::xml_find_all(payload$doc, sprintf("//*[@id='%s']", id))
    expect_gt(length(found), 0)
  }
}

# Bounding box of the first <polygon> under the element a selector addresses.
selector_polygon_bbox <- function(payload, id) {
  node <- xml2::xml_find_first(payload$doc, sprintf("//*[@id='%s']", id))
  if (inherits(node, "xml_missing")) {
    return(NULL)
  }
  poly <- xml2::xml_find_first(node, ".//*[local-name()='polygon']")
  if (inherits(poly, "xml_missing")) {
    return(NULL)
  }
  pts <- xml2::xml_attr(poly, "points")
  nums <- as.numeric(regmatches(pts, gregexpr("-?[0-9.]+", pts))[[1]])
  list(
    x0 = min(nums[c(TRUE, FALSE)]), x1 = max(nums[c(TRUE, FALSE)]),
    y0 = min(nums[c(FALSE, TRUE)]), y1 = max(nums[c(FALSE, TRUE)])
  )
}

# Every KDE point must sit on the violin its own selector points at. This is
# what catches a panel-blind coordinate mapping: the numbers stay plausible,
# they just describe the wrong panel.
expect_kde_coords_on_own_violin <- function(payload, kde_layer) {
  ids <- selector_ids(kde_layer)
  expect_equal(length(ids), length(kde_layer$data))

  for (group_idx in seq_along(kde_layer$data)) {
    points <- kde_layer$data[[group_idx]]
    expect_gt(length(points), 0)

    xs <- vapply(points, function(p) as.numeric(p$svg_x %||% NA_real_), numeric(1))
    ys <- vapply(points, function(p) as.numeric(p$svg_y %||% NA_real_), numeric(1))
    expect_false(any(is.na(xs)))
    expect_false(any(is.na(ys)))

    bbox <- selector_polygon_bbox(payload, ids[group_idx])
    expect_false(is.null(bbox))

    tol <- 0.05 * max(bbox$x1 - bbox$x0, bbox$y1 - bbox$y0, 1)
    expect_true(all(xs >= bbox$x0 - tol & xs <= bbox$x1 + tol))
    expect_true(all(ys >= bbox$y0 - tol & ys <= bbox$y1 + tol))
  }
}

# Recursively collect every key in the payload, so internal fields cannot slip
# through on a path nobody thought to assert on.
all_keys <- function(x) {
  if (!is.list(x)) {
    return(character(0))
  }
  keys <- names(x)
  if (is.null(keys)) keys <- character(0)
  c(keys, unlist(lapply(x, all_keys), use.names = FALSE))
}

`%||%` <- function(a, b) if (is.null(a)) b else a


test_that("a violin leaf emits violin_box and violin_kde", {
  skip_if_no_patchwork()

  payload <- render_payload(violin_plot() | bar_plot())

  violin_cell <- payload$data$subplots[[1]][[1]]
  expect_equal(layer_types(violin_cell), c("violin_box", "violin_kde"))
  expect_equal(
    vapply(violin_cell$layers, function(l) l$id, character(1)),
    c("maidr-layer-1-1", "maidr-layer-1-2")
  )

  # The other leaf is untouched, and its single-layer id keeps the old form
  bar_cell <- payload$data$subplots[[1]][[2]]
  expect_equal(layer_types(bar_cell), "bar")
  expect_equal(bar_cell$layers[[1]]$id, "maidr-layer-1")
})

test_that("violin layers carry their processor fields into the payload", {
  skip_if_no_patchwork()

  payload <- render_payload(violin_plot() | bar_plot())
  layers <- payload$data$subplots[[1]][[1]]$layers

  box <- layers[[1]]
  expect_equal(box$orientation, "vert")
  expect_equal(box$domMapping$iqrDirection, "reverse")
  expect_true(isTRUE(box$violinOptions$showMedian))

  kde <- layers[[2]]
  expect_equal(kde$orientation, "vert")
  expect_equal(length(kde$data), length(box$data))
})

test_that("leaf/panel pairing does not depend on composition order", {
  skip_if_no_patchwork()

  payload <- render_payload(bar_plot() | violin_plot())

  expect_equal(layer_types(payload$data$subplots[[1]][[1]]), "bar")
  expect_equal(
    layer_types(payload$data$subplots[[1]][[2]]),
    c("violin_box", "violin_kde")
  )
})

test_that("violin selectors resolve against the exported SVG", {
  skip_if_no_patchwork()

  payload <- render_payload(violin_plot() | bar_plot())
  for (layer in payload$data$subplots[[1]][[1]]$layers) {
    expect_selectors_resolve(payload, layer)
  }
})

test_that("two violins in one composition get disjoint selectors", {
  skip_if_no_patchwork()

  other <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(drv, cty)) +
    ggplot2::geom_violin()
  payload <- render_payload(violin_plot() | other)

  left <- payload$data$subplots[[1]][[1]]
  right <- payload$data$subplots[[1]][[2]]
  expect_equal(layer_types(left), c("violin_box", "violin_kde"))
  expect_equal(layer_types(right), c("violin_box", "violin_kde"))

  left_ids <- unlist(lapply(left$layers, function(l) selector_ids(l)))
  right_ids <- unlist(lapply(right$layers, function(l) selector_ids(l)))
  expect_length(intersect(left_ids, right_ids), 0)
})

test_that("a violin nested inside a patchwork row is still processed", {
  skip_if_no_patchwork()

  # (v | b) / s puts the violin's panel inside a CHILD gtable, which a
  # top-level-only panel lookup cannot reach.
  payload <- render_payload((violin_plot() | bar_plot()) / point_plot())

  violin_cell <- payload$data$subplots[[1]][[1]]
  expect_equal(layer_types(violin_cell), c("violin_box", "violin_kde"))
  for (layer in violin_cell$layers) {
    expect_selectors_resolve(payload, layer)
  }
})

test_that("KDE coordinates describe each violin's own panel", {
  skip_if_no_patchwork()

  other <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(drv, cty)) +
    ggplot2::geom_violin()

  for (composition in list(
    violin_plot() | other,
    (violin_plot() | bar_plot()) / point_plot()
  )) {
    payload <- render_payload(composition)
    for (row in payload$data$subplots) {
      for (cell in row) {
        for (layer in cell$layers) {
          if (identical(layer$type, "violin_kde")) {
            expect_kde_coords_on_own_violin(payload, layer)
          }
        }
      }
    }
  }
})

test_that("horizontal violins work inside a patchwork", {
  skip_if_no_patchwork()

  horizontal <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(hwy, class)) +
    ggplot2::geom_violin()
  payload <- render_payload(horizontal | bar_plot())

  layers <- payload$data$subplots[[1]][[1]]$layers
  expect_equal(layer_types(payload$data$subplots[[1]][[1]]),
    c("violin_box", "violin_kde")
  )
  expect_equal(layers[[1]]$orientation, "horz")
  expect_equal(layers[[1]]$domMapping$iqrDirection, "forward")
  expect_kde_coords_on_own_violin(payload, layers[[2]])
})

test_that("no internal metadata reaches the emitted JSON", {
  skip_if_no_patchwork()

  compositions <- list(
    violin_plot(),
    violin_plot() | bar_plot(),
    (violin_plot() | bar_plot()) / point_plot(),
    violin_plot() + ggplot2::facet_wrap(~drv)
  )

  internal <- c(
    ".panel_x_range", ".panel_y_range", ".is_horizontal",
    ".panel_index", ".panel_name",
    "data_left_x", "data_right_x", "data_y"
  )

  for (composition in compositions) {
    payload <- render_payload(composition)
    keys <- unique(all_keys(payload$data))
    expect_length(intersect(keys, internal), 0)
    expect_false(any(startsWith(keys, ".")))
  }
})

test_that("faceted violins remain unsupported and stay quiet", {
  skip_if_no_patchwork()

  faceted <- violin_plot() + ggplot2::facet_wrap(~drv)

  expect_no_error({
    payload <- render_payload(faceted)
  })
  for (row in payload$data$subplots) {
    for (cell in row) {
      expect_length(cell$layers, 0)
    }
  }
})

test_that("a faceted violin nested in a patchwork is skipped, not mangled", {
  skip_if_no_patchwork()

  faceted <- violin_plot() + ggplot2::facet_wrap(~drv)
  payload <- render_payload(faceted | bar_plot())

  emitted <- unlist(lapply(payload$data$subplots, function(row) {
    unlist(lapply(row, layer_types))
  }))
  expect_length(intersect(emitted, c("violin_box", "violin_kde", "violin")), 0)
})

test_that("the standalone violin payload is unchanged", {
  skip_if_no_patchwork()

  payload <- render_payload(violin_plot())
  cell <- payload$data$subplots[[1]][[1]]

  expect_equal(layer_types(cell), c("violin_box", "violin_kde"))
  # Single-plot ids stay numeric, not the patchwork "maidr-layer-N" form
  expect_equal(vapply(cell$layers, function(l) l$id, numeric(1)), c(1, 2))
  expect_kde_coords_on_own_violin(payload, cell$layers[[2]])
})

test_that("non-violin patchwork payloads keep their layer ids", {
  skip_if_no_patchwork()

  payload <- render_payload(bar_plot() | point_plot())

  ids <- unlist(lapply(payload$data$subplots, function(row) {
    unlist(lapply(row, function(cell) {
      vapply(cell$layers, function(l) as.character(l$id), character(1))
    }))
  }))
  expect_true(all(ids == "maidr-layer-1"))
})
