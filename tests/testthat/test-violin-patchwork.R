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
#
# A full render is ~4 s (ggplot_build + patchworkGrob + grid.draw + gridSVG),
# and several tests assert different things about the same composition, so
# results are cached per named composition for the duration of the file.
payload_cache <- new.env(parent = emptyenv())

render_payload <- function(plot, key = NULL) {
  if (!is.null(key) && !is.null(payload_cache[[key]])) {
    return(payload_cache[[key]])
  }
  out <- render_payload_uncached(plot)
  if (!is.null(key)) {
    assign(key, out, envir = payload_cache)
  }
  out
}

render_payload_uncached <- function(plot) {
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

  payload <- render_payload(violin_plot() | bar_plot(), "v_bar")

  violin_cell <- payload$data$subplots[[1]][[1]]
  expect_equal(layer_types(violin_cell), c("violin_box", "violin_kde"))
  expect_equal(
    vapply(violin_cell$layers, function(l) l$id, character(1)),
    c("maidr-layer-1-1-1-1", "maidr-layer-1-1-1-2")
  )

  # The other leaf is untouched, and its single layer is still one layer --
  # only the cell it sits in tells the two leaves' ids apart
  bar_cell <- payload$data$subplots[[1]][[2]]
  expect_equal(layer_types(bar_cell), "bar")
  expect_equal(bar_cell$layers[[1]]$id, "maidr-layer-1-2-1")
})

test_that("violin layers carry their processor fields into the payload", {
  skip_if_no_patchwork()

  payload <- render_payload(violin_plot() | bar_plot(), "v_bar")
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

  payload <- render_payload(bar_plot() | violin_plot(), "bar_v")

  expect_equal(layer_types(payload$data$subplots[[1]][[1]]), "bar")
  expect_equal(
    layer_types(payload$data$subplots[[1]][[2]]),
    c("violin_box", "violin_kde")
  )
})

test_that("violin selectors resolve against the exported SVG", {
  skip_if_no_patchwork()

  payload <- render_payload(violin_plot() | bar_plot(), "v_bar")
  for (layer in payload$data$subplots[[1]][[1]]$layers) {
    expect_selectors_resolve(payload, layer)
  }
})

test_that("two violins in one composition get disjoint selectors", {
  skip_if_no_patchwork()

  other <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(drv, cty)) +
    ggplot2::geom_violin()
  payload <- render_payload(violin_plot() | other, "two_violins")

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
  payload <- render_payload((violin_plot() | bar_plot()) / point_plot(), "nested")

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

  compositions <- list(
    two_violins = violin_plot() | other,
    nested = (violin_plot() | bar_plot()) / point_plot()
  )
  for (idx in seq_along(compositions)) {
    payload <- render_payload(compositions[[idx]], names(compositions)[idx])
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
    standalone = violin_plot(),
    v_bar = violin_plot() | bar_plot(),
    nested = (violin_plot() | bar_plot()) / point_plot(),
    faceted = violin_plot() + ggplot2::facet_wrap(~drv)
  )

  internal <- c(
    ".panel_x_range", ".panel_y_range", ".is_horizontal",
    ".panel_index", ".panel_name",
    "data_left_x", "data_right_x", "data_y"
  )

  for (idx in seq_along(compositions)) {
    payload <- render_payload(compositions[[idx]], names(compositions)[idx])
    keys <- unique(all_keys(payload$data))
    expect_length(intersect(keys, internal), 0)
    expect_false(any(startsWith(keys, ".")))
  }
})

test_that("faceted violins remain unsupported and stay quiet", {
  skip_if_no_patchwork()

  faceted <- violin_plot() + ggplot2::facet_wrap(~drv)

  expect_no_error({
    payload <- render_payload(faceted, "faceted")
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

  # Both positions: patchwork keeps the last-added plot on the object itself,
  # so the two orders take different code paths.
  for (composition in list(faceted | bar_plot(), bar_plot() | faceted)) {
    payload <- render_payload(composition)
    emitted <- unlist(lapply(payload$data$subplots, function(row) {
      unlist(lapply(row, layer_types))
    }))
    expect_length(intersect(emitted, c("violin_box", "violin_kde", "violin")), 0)
    # The boxplot violin injects to render its selectors must never surface
    # as a layer the user did not write
    expect_length(intersect(emitted, "box"), 0)
  }
})

test_that("a faceted sibling never makes a violin announce an unreachable panel", {
  skip_if_no_patchwork()

  # A faceted leaf occupies several panels, so the leaf-to-panel pairing runs
  # short and a violin can be handed a panel it does not draw into. Every
  # violin layer that IS emitted must be reachable.
  faceted_bar <- bar_plot() + ggplot2::facet_wrap(~drv)

  for (composition in list(faceted_bar | violin_plot(), violin_plot() | faceted_bar)) {
    payload <- render_payload(composition)
    for (row in payload$data$subplots) {
      for (cell in row) {
        for (layer in cell$layers) {
          if (layer$type %in% c("violin_box", "violin_kde")) {
            expect_selectors_resolve(payload, layer)
          }
        }
      }
    }
  }
})

test_that("the standalone violin payload is unchanged", {
  skip_if_no_patchwork()

  payload <- render_payload(violin_plot(), "standalone")
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
  expect_equal(ids, c("maidr-layer-1-1-1", "maidr-layer-1-2-1"))
})

test_that("a faceted sibling does not cost the other plot its selectors", {
  skip_if_no_patchwork()

  # A faceted leaf owns one panel per facet cell but is still one leaf, so
  # naive pairing pushes every later leaf onto someone else's panel.
  faceted_violin <- violin_plot() + ggplot2::facet_wrap(~drv)

  for (composition in list(faceted_violin | bar_plot(), bar_plot() | faceted_violin)) {
    payload <- render_payload(composition)

    bars <- list()
    for (row in payload$data$subplots) {
      for (cell in row) {
        for (layer in cell$layers) {
          if (identical(layer$type, "bar")) bars[[length(bars) + 1]] <- layer
        }
      }
    }
    # Announced exactly once, and reachable
    expect_length(bars, 1)
    expect_selectors_resolve(payload, bars[[1]])
  }
})

test_that("a leaf a processor cannot handle does not abort the composition", {
  skip_if_no_patchwork()

  # Force the violin processor to fail for this render only. `width = 0` used
  # to be a natural trigger; now that it is fixed, the isolation guarantee
  # still needs exercising, so make the failure explicitly.
  original <- Ggplot2ViolinLayerProcessor$public_methods$process
  Ggplot2ViolinLayerProcessor$set(
    "public", "process",
    function(...) stop("processor blew up"),
    overwrite = TRUE
  )
  on.exit(
    Ggplot2ViolinLayerProcessor$set(
      "public", "process", original, overwrite = TRUE
    ),
    add = TRUE
  )

  payload <- expect_no_error(render_payload_uncached(violin_plot() | bar_plot()))
  # The healthy leaf is still described; only the failing one goes quiet.
  expect_equal(layer_types(payload$data$subplots[[1]][[2]]), "bar")
  expect_length(payload$data$subplots[[1]][[1]]$layers, 0)
})

test_that("a degenerate violin renders instead of aborting", {
  skip_if_no_patchwork()

  # geom_violin(width = 0) leaves every KDE width at zero, which used to make
  # the tip-widening step compute min() of an empty vector and abort the
  # whole render (issue #65).
  degenerate <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
    ggplot2::geom_violin(width = 0)

  expect_no_error(render_payload_uncached(degenerate))
  payload <- expect_no_error(render_payload_uncached(degenerate | bar_plot()))
  expect_equal(layer_types(payload$data$subplots[[1]][[2]]), "bar")
})

test_that("a patchwork violin payload matches the standalone one", {
  skip_if_no_patchwork()

  # Quantile lines change the grob tree so the kde selectors come up empty
  # even standalone. The patchwork payload should have the same shape as the
  # standalone one rather than silently dropping the layers that do work.
  # draw_quantiles is deprecated in ggplot2 4.0, but it is the cheapest way
  # to reach a violin whose kde selectors are empty; the deprecation is not
  # what this test is about.
  quantiled <- suppressWarnings(
    ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
      ggplot2::geom_violin(draw_quantiles = c(0.25, 0.5, 0.75))
  )

  alone <- suppressWarnings(render_payload(quantiled))
  composed <- suppressWarnings(render_payload(quantiled | bar_plot()))

  expect_equal(
    layer_types(composed$data$subplots[[1]][[1]]),
    layer_types(alone$data$subplots[[1]][[1]])
  )
  box <- composed$data$subplots[[1]][[1]]$layers[[1]]
  expect_selectors_resolve(composed, box)
})

test_that("a wrapped element beside a violin does not shift its coordinates", {
  skip_if_no_patchwork()

  # wrap_elements() contributes a cell literally named "panel" to the
  # gtable. The panel list a violin's `.panel_index` refers to must be
  # filtered the same way the index was minted, or every violin after that
  # cell maps its highlight coordinates through the wrong panel.
  payload <- render_payload(violin_plot() | patchwork::wrap_elements(full = bar_plot()))

  cell <- payload$data$subplots[[1]][[1]]
  expect_equal(layer_types(cell), c("violin_box", "violin_kde"))
  expect_kde_coords_on_own_violin(payload, cell$layers[[2]])
})

test_that("a wrapped plot does not shift the plots after it", {
  skip_if_no_patchwork()

  # free()/inset_element()/wrap_elements() contribute no discoverable panel.
  # Treating one as if it occupied a panel pushes every later plot onto
  # somebody else's, and the last of them off the end entirely.
  wrapper_first <- render_payload(patchwork::free(violin_plot()) | bar_plot())
  bars <- unlist(lapply(wrapper_first$data$subplots, function(row) {
    unlist(lapply(row, layer_types))
  }))
  expect_equal(bars, "bar")

  wrapper_middle <- render_payload(
    bar_plot() | patchwork::free(point_plot()) | violin_plot()
  )
  emitted <- unlist(lapply(wrapper_middle$data$subplots, function(row) {
    unlist(lapply(row, layer_types))
  }))
  expect_equal(emitted, c("bar", "violin_box", "violin_kde"))

  # ... and the plots that survive are still reachable
  for (row in wrapper_middle$data$subplots) {
    for (cell in row) {
      for (layer in cell$layers) {
        expect_selectors_resolve(wrapper_middle, layer)
      }
    }
  }
})
