# Reading ComplexHeatmap dendrograms as trees (#390)
#
# Each tree is checked against the `dendrogram` the same draw returned
# (`row_dend()`, `column_dend()`, and the dendrogram drawn over the slices),
# walked here by recursion as R's own dendrogram methods walk it, rather
# than by the processor's stack; its leaves against the heat layer's labels.

skip_if_not_installed("ComplexHeatmap")

cht_matrix <- function(names = TRUE) {
  set.seed(390)
  m <- matrix(rnorm(48, sd = 2), 8, 6)
  if (names) {
    dimnames(m) <- list(paste0("gene", 1:8), paste0("sample", 1:6))
  }
  m
}

cht_drawn <- function(x) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  ComplexHeatmap::draw(x)
}

cht_data <- function(x) {
  orchestrator <- get_global_registry()$get_adapter_for_plot(x)$create_orchestrator(x)
  expect_identical(orchestrator$unsupported_reasons(), character(0))
  orchestrator$generate_maidr_data()
}

cht_layers <- function(x) {
  unlist(lapply(unlist(cht_data(x)$subplots, recursive = FALSE), `[[`, "layers"), recursive = FALSE)
}

cht_trees <- function(x) {
  Filter(function(l) identical(l$type, "tree"), cht_layers(x))
}

cht_heat <- function(x) {
  Filter(function(l) identical(l$type, "heat"), cht_layers(x))[[1]]
}

# Each subplot as the titles of its layers, rows as written (bottom first)
cht_grid <- function(x) {
  lapply(cht_data(x)$subplots, function(row) {
    vapply(row, function(s) {
      paste(vapply(s$layers, function(l) if (identical(l$type, "heat")) "heat" else l$title, ""),
        collapse = " | "
      )
    }, character(1))
  })
}

cht_height <- function(h) trimws(formatC(h, digits = 3, format = "fg"))

# The leaves of a dendrogram, in branch order
cht_dend_leaves <- function(node) {
  if (stats::is.leaf(node)) {
    return(attr(node, "label"))
  }
  unlist(lapply(seq_along(node), function(i) cht_dend_leaves(node[[i]])))
}

# The nodes a dendrogram holds, root first, children in branch order, named
# by `names` in leaf order (leaves met in a walk of the branches).
cht_expected <- function(dend, names) {
  at <- 0L
  walk <- function(node, path) {
    if (stats::is.leaf(node)) {
      at <<- at + 1L
      own <- names[at]
      return(list(list(own = own, path = path, first = at, last = at, leaf = TRUE)))
    }
    kids <- list()
    for (i in seq_along(node)) {
      kids <- c(kids, walk(node[[i]], c(path, "?")))
    }
    first <- kids[[1]]$first
    last <- kids[[length(kids)]]$last
    height <- cht_height(attr(node, "height"))
    own <- sprintf("%s to %s (height %s)", names[first], names[last], height)
    c(list(list(own = own, path = path, first = first, last = last, leaf = FALSE)), kids)
  }
  flat <- walk(dend, character(0))
  # Paths: each node's ancestors' names. The "?" placeholders are filled in
  # depth first: a node's depth is its path length, its parent the last
  # node before it one shallower.
  stack <- character(0)
  lapply(flat, function(n) {
    depth <- length(n$path)
    stack <<- c(stack[seq_len(depth)], n$own)
    if (depth) list(x = n$own, path = as.list(stack[seq_len(depth)])) else list(x = n$own)
  })
}

# The slices' dendrograms put in place of the leaves of the one over them,
# in drawn order, as ComplexHeatmap's merge_dendrogram() joins them (with
# the parent's own heights, which merge_dendrogram() lifts for drawing).
cht_join <- function(parent, slices) {
  at <- 0L
  join <- function(node) {
    if (stats::is.leaf(node)) {
      at <<- at + 1L
      return(slices[[at]])
    }
    for (i in seq_along(node)) {
      node[[i]] <- join(node[[i]])
    }
    node
  }
  join(parent)
}

test_that("a tree is the dendrogram drawn, its leaves the heat layer's labels", {
  ht <- ComplexHeatmap::Heatmap(cht_matrix())
  drawn <- cht_drawn(ht)
  heat <- cht_heat(ht)
  trees <- cht_trees(ht)
  expect_identical(vapply(trees, `[[`, "", "title"), c("Row dendrogram", "Column dendrogram"))

  row <- ComplexHeatmap::row_dend(drawn)
  expect_identical(cht_dend_leaves(row), unlist(heat$data$y))
  expect_identical(trees[[1]]$data, cht_expected(row, unlist(heat$data$y)))
  expect_length(trees[[1]]$data, 2L * nrow(cht_matrix()) - 1L)

  col <- ComplexHeatmap::column_dend(drawn)
  expect_identical(cht_dend_leaves(col), unlist(heat$data$x))
  expect_identical(trees[[2]]$data, cht_expected(col, unlist(heat$data$x)))

  # Nothing to highlight a node with: no selectors.
  for (tree in trees) {
    expect_null(tree$selectors)
    expect_identical(tree$axes, list(x = list(label = tree$title)))
  }
})

test_that("a dendrogram is read as pheatmap's hclust is", {
  set.seed(1)
  m <- matrix(rnorm(70), 14, 5)
  hc <- stats::hclust(stats::dist(m))
  # Repeated labels among siblings are numbered alike.
  names <- rep(c("a", "b", "a", "c", "a", "a", "d"), 2)
  expect_identical(
    complexheatmap_tree_nodes(list(stats::as.dendrogram(hc)), names),
    pheatmap_tree_nodes(hc, names)
  )
  # Too few names, or a single leaf, is no tree.
  expect_identical(complexheatmap_tree_nodes(list(stats::as.dendrogram(hc)), names[-1]), list())
  leaf <- stats::as.dendrogram(stats::hclust(stats::dist(m[1:2, ])))[[1]]
  expect_identical(complexheatmap_tree_nodes(list(leaf), "a"), list())
})

test_that("an unnamed matrix's trees are named by position, as its heat layer is", {
  ht <- ComplexHeatmap::Heatmap(cht_matrix(names = FALSE))
  heat <- cht_heat(ht)
  trees <- cht_trees(ht)
  drawn <- cht_drawn(ht)
  expect_identical(unlist(heat$data$y), as.character(ComplexHeatmap::row_order(drawn)))
  expect_identical(
    trees[[1]]$data,
    cht_expected(ComplexHeatmap::row_dend(drawn), unlist(heat$data$y))
  )
})

test_that("clustered slices are one tree, joined under the dendrogram drawn over them", {
  m <- cht_matrix()
  for (ht in list(
    # Split by a factor, by k-means and by cutting the dendrogram.
    ComplexHeatmap::Heatmap(m, row_split = rep(c("x", "y", "z"), length.out = 8)),
    ComplexHeatmap::Heatmap(m, row_km = 2, row_km_repeats = 1),
    ComplexHeatmap::Heatmap(m, row_split = 3, column_split = 2)
  )) {
    drawn <- cht_drawn(ht)
    heat <- cht_data(drawn)
    heat_layer <- Filter(function(l) identical(l$type, "heat"), unlist(lapply(
      unlist(heat$subplots, recursive = FALSE), `[[`, "layers"
    ), recursive = FALSE))[[1]]
    trees <- cht_trees(drawn)
    expect_identical(vapply(trees, `[[`, "", "title"), c("Row dendrogram", "Column dendrogram"))
    h <- drawn@ht_list[[1]]
    for (side in c("row", "column")) {
      tree <- trees[[match(side, c("row", "column"))]]
      slices <- unname(methods::slot(h, paste0(side, "_dend_list")))
      labels <- unlist(if (side == "row") heat_layer$data$y else heat_layer$data$x)
      dend <- if (length(slices) > 1L) {
        cht_join(methods::slot(h, paste0(side, "_dend_slice")), slices)
      } else {
        slices[[1]]
      }
      expect_identical(cht_dend_leaves(dend), labels)
      expect_identical(tree$data, cht_expected(dend, labels))
    }
  }
})

test_that("a cluster of slices is named by the height its slices merged at", {
  ht <- ComplexHeatmap::Heatmap(cht_matrix(), row_split = rep(c("x", "y"), 4))
  drawn <- cht_drawn(ht)
  parent <- drawn@ht_list[[1]]@row_dend_slice
  root <- cht_trees(drawn)[[1]]$data[[1]]$x
  expect_match(root, sprintf("(height %s)", cht_height(attr(parent, "height"))), fixed = TRUE)
})

test_that("slices not clustered are a tree each, titled by their slice", {
  m <- cht_matrix()
  ht <- ComplexHeatmap::Heatmap(m, row_split = rep(c("x", "y"), 4), cluster_row_slices = FALSE)
  drawn <- cht_drawn(ht)
  trees <- cht_trees(drawn)
  expect_identical(
    vapply(trees, `[[`, "", "title"),
    c("Row dendrogram, slice x", "Row dendrogram, slice y", "Column dendrogram")
  )
  for (k in 1:2) {
    dend <- drawn@ht_list[[1]]@row_dend_list[[k]]
    expect_identical(trees[[k]]$data, cht_expected(dend, cht_dend_leaves(dend)))
  }
  # Both row trees share the subplot left of the heat map.
  expect_identical(
    cht_grid(drawn),
    list(c("Row dendrogram, slice x | Row dendrogram, slice y", "heat"), c("", "Column dendrogram"))
  )

  # A slice of one row draws no dendrogram; untitled slices are numbered.
  ht <- ComplexHeatmap::Heatmap(
    m,
    row_split = c(rep("a", 7), "b"), cluster_row_slices = FALSE, row_title = NULL,
    cluster_columns = FALSE
  )
  expect_identical(vapply(cht_trees(ht), `[[`, "", "title"), "Row dendrogram, slice 1")
})

test_that("a tree is placed where it is drawn, and a side not drawn has none", {
  m <- cht_matrix()
  # Rows bottom first: the row tree left of the matrix, the column tree
  # above it, the corner above the row tree empty.
  expect_identical(
    cht_grid(ComplexHeatmap::Heatmap(m)),
    list(c("Row dendrogram", "heat"), c("", "Column dendrogram"))
  )
  expect_identical(
    cht_grid(ComplexHeatmap::Heatmap(m, row_dend_side = "right", column_dend_side = "bottom")),
    list(c("Column dendrogram", ""), c("heat", "Row dendrogram"))
  )
  expect_identical(
    cht_grid(ComplexHeatmap::Heatmap(m, cluster_rows = FALSE)),
    list("heat", "Column dendrogram")
  )
  expect_identical(
    cht_grid(ComplexHeatmap::Heatmap(m, show_column_dend = FALSE)),
    list(c("Row dendrogram", "heat"))
  )
  # Clustered but not shown: the order is the dendrogram's, and no tree.
  expect_identical(
    cht_grid(ComplexHeatmap::Heatmap(m, show_row_dend = FALSE, show_column_dend = FALSE)),
    list("heat")
  )
})

test_that("a dendrogram given to cluster_rows is read as drawn", {
  m <- cht_matrix()
  dend <- stats::as.dendrogram(stats::hclust(stats::dist(m), method = "average"))
  ht <- ComplexHeatmap::Heatmap(m, cluster_rows = dend, row_dend_reorder = FALSE)
  drawn <- cht_drawn(ht)
  labels <- unlist(cht_heat(drawn)$data$y)
  expect_identical(
    cht_trees(drawn)[[1]]$data,
    cht_expected(ComplexHeatmap::row_dend(drawn), labels)
  )
})

test_that("the trees are written beside the heat layer, and the chart is a heat map", {
  file <- withr::local_tempfile(fileext = ".html")
  save_html(ComplexHeatmap::Heatmap(cht_matrix()), file = file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_match(html, "&quot;type&quot;:&quot;tree&quot;", fixed = TRUE)
  json <- jsonlite::toJSON(cht_data(ComplexHeatmap::Heatmap(cht_matrix())), auto_unbox = TRUE)
  expect_match(knitr_chart_kind(json), "^Heat map")
})

# Lists of heat maps (#391) --------------------------------------------------

cht_list_matrices <- function() {
  set.seed(391)
  list(
    a = matrix(rnorm(48), 8, 6, dimnames = list(paste0("gene", 1:8), paste0("s", 1:6))),
    b = matrix(rnorm(32), 8, 4, dimnames = list(paste0("gene", 1:8), paste0("t", 1:4)))
  )
}

# Each subplot as its heat map's name or its layers' titles
cht_list_grid <- function(x) {
  lapply(cht_data(x)$subplots, function(row) {
    vapply(row, function(s) {
      paste(vapply(s$layers, function(l) {
        if (identical(l$type, "heat")) l$axes$z$label else l$title
      }, ""), collapse = " | ")
    }, character(1))
  })
}

test_that("a horizontal list shares one row tree and has a column tree per heat map", {
  m <- cht_list_matrices()
  x <- ComplexHeatmap::Heatmap(m$a, name = "a") + ComplexHeatmap::Heatmap(m$b, name = "b")
  # Rows bottom first: the main heat map's row tree left of the list, each
  # heat map's column tree above it.
  expect_identical(cht_list_grid(x), list(
    c("Row dendrogram", "a", "b"),
    c("", "Column dendrogram", "Column dendrogram")
  ))
  drawn <- cht_drawn(x)
  layers <- cht_layers(drawn)
  heats <- Filter(function(l) identical(l$type, "heat"), layers)
  trees <- Filter(function(l) identical(l$type, "tree"), layers)
  # The heat layers first, then the trees.
  expect_identical(vapply(layers, `[[`, "", "id"), paste0("maidr-layer-", c(3, 1, 2, 4, 5)))
  expect_identical(
    trees[[1]]$data,
    cht_expected(ComplexHeatmap::row_dend(drawn), unlist(heats[[1]]$data$y))
  )
  columns <- ComplexHeatmap::column_dend(drawn)
  for (k in 1:2) {
    expect_identical(trees[[k + 1L]]$data, cht_expected(columns[[k]], unlist(heats[[k]]$data$x)))
  }

  # The row tree is drawn by the main heat map, wherever it is in the list.
  grDevices::pdf(NULL)
  drawn <- ComplexHeatmap::draw(x, main_heatmap = "b")
  grDevices::dev.off()
  expect_identical(cht_list_grid(drawn), list(
    c("a", "Row dendrogram", "b"),
    c("Column dendrogram", "", "Column dendrogram")
  ))
})

test_that("a vertical list shares one column tree and has a row tree per heat map", {
  m <- lapply(cht_list_matrices(), t)
  x <- ComplexHeatmap::`%v%`(
    ComplexHeatmap::Heatmap(m$a, name = "a"),
    ComplexHeatmap::Heatmap(m$b, name = "b", row_dend_side = "right")
  )
  # Top to bottom as drawn: the column tree, `a` beside its row tree, `b`
  # beside its own on the right -- written bottom first.
  expect_identical(cht_list_grid(x), list(
    c("", "b", "Row dendrogram"),
    c("Row dendrogram", "a", ""),
    c("", "Column dendrogram", "")
  ))
})

test_that("a list's trees follow each heat map's own settings", {
  m <- cht_list_matrices()
  x <- ComplexHeatmap::Heatmap(
    m$a,
    name = "a", show_column_dend = FALSE, row_dend_side = "right"
  ) +
    ComplexHeatmap::Heatmap(m$b, name = "b", column_dend_side = "bottom")
  expect_identical(cht_list_grid(x), list(
    c("", "", "Column dendrogram"),
    c("a", "Row dendrogram", "b")
  ))
  x <- ComplexHeatmap::Heatmap(m$a, name = "a", cluster_rows = FALSE, show_column_dend = FALSE) +
    ComplexHeatmap::Heatmap(m$b, name = "b", show_column_dend = FALSE)
  expect_identical(cht_list_grid(x), list(c("a", "b")))
})

test_that("a list's trees carry no selectors, and its heat maps keep theirs", {
  m <- cht_list_matrices()
  x <- ComplexHeatmap::Heatmap(m$a, name = "a") + ComplexHeatmap::Heatmap(m$b, name = "b")
  layers <- cht_layers(x)
  for (layer in layers) {
    if (identical(layer$type, "tree")) {
      expect_null(layer$selectors)
    } else {
      expect_match(layer$selectors[[1]][[1]], "maidr-complexheatmap-cells-[12]-1-1")
    }
  }
})
