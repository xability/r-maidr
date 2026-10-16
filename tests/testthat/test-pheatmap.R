# Reading the object pheatmap::pheatmap() returns (#376)
#
# pheatmap() returns the trees and the drawn gtable, not the matrix. maidr's
# own pheatmap() keeps the matrix as drawn with the result, and the reading
# then announces it exactly; a chart drawn by pheatmap::pheatmap() directly
# is read from its colours, approximately, and says so. Each test checks the
# reading against sources it does not compute: the input matrix, scaled and
# reordered here by R's own functions, for the values and labels, and the
# exported SVG for the marks -- every selector must name exactly one cell,
# painted the colour pheatmap gave that cell.

skip_if_not_installed("pheatmap")

# Drawn through maidr's wrapper: a bare pheatmap() in a test resolves to
# maidr's namespace.
ph_draw <- function(...) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  pheatmap(..., silent = TRUE)
}

# Drawn by pheatmap itself, as when 'pheatmap' masks maidr's wrapper.
ph_draw_direct <- function(...) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  pheatmap::pheatmap(..., silent = TRUE)
}

ph_layers <- function(p) {
  orchestrator <- get_global_registry()$get_adapter_for_plot(p)$create_orchestrator(p)
  expect_identical(orchestrator$unsupported_reasons(), character(0))
  subplots <- unlist(orchestrator$generate_maidr_data()$subplots, recursive = FALSE)
  unlist(lapply(subplots, `[[`, "layers"), recursive = FALSE)
}

ph_layer <- function(p) {
  layers <- ph_layers(p)
  layers[vapply(layers, function(l) identical(l$type, "heat"), logical(1))][[1]]
}

ph_points <- function(layer) {
  do.call(rbind, lapply(layer$data$points, function(row) {
    vapply(row, function(v) if (is.null(v)) NA_real_ else v, numeric(1))
  }))
}

ph_matrix <- function() {
  set.seed(376)
  matrix(
    rnorm(20, sd = 2), 4, 5,
    dimnames = list(paste0("gene", 1:4), paste0("sample", 1:5))
  )
}

test_that("a pheatmap is claimed by the pheatmap system and no other", {
  p <- ph_draw(ph_matrix())
  expect_true(is_maidr_plot_object(p))
  expect_identical(get_global_registry()$detect_system(p), "pheatmap")
  expect_false(BaseRAdapter$new()$can_handle(p))
})

test_that("maidr's pheatmap() draws what pheatmap draws and returns it", {
  m <- ph_matrix()
  p <- ph_draw(m, main = "Expression")
  q <- ph_draw_direct(m, main = "Expression")
  expect_s3_class(p, "pheatmap")
  expect_identical(p$tree_row$order, q$tree_row$order)
  expect_identical(p$tree_col$order, q$tree_col$order)
  expect_identical(
    pheatmap_child(pheatmap_grob(p$gtable, "matrix"), "rect")$gp$fill,
    pheatmap_child(pheatmap_grob(q$gtable, "matrix"), "rect")$gp$fill
  )
  expect_null(attr(q, "maidr_matrix"))
})

test_that("the cells are read exactly, in clustered order, rows top first", {
  m <- ph_matrix()
  p <- ph_draw(m, main = "Expression")
  expect_no_message(layer <- ph_layer(p), class = "maidr_pheatmap_values")

  expect_identical(layer$type, "heat")
  expect_identical(layer$title, "Expression")
  drawn <- m[p$tree_row$order, p$tree_col$order]
  expect_identical(unlist(layer$data$y), rownames(drawn))
  expect_identical(unlist(layer$data$x), colnames(drawn))
  expect_identical(ph_points(layer), unname(drawn))
})

test_that("a scaled pheatmap is read as drawn: the scaled matrix, exactly", {
  m <- ph_matrix()

  p <- ph_draw(m, scale = "row")
  rows <- t(scale(t(m)))[p$tree_row$order, p$tree_col$order]
  expect_equal(ph_points(ph_layer(p)), unname(rows), tolerance = 1e-12)

  p <- ph_draw(m, scale = "column", cluster_rows = FALSE)
  columns <- scale(m)[, p$tree_col$order]
  layer <- ph_layer(p)
  expect_identical(unlist(layer$data$y), rownames(m))
  expect_equal(ph_points(layer), unname(columns), tolerance = 1e-12)
})

test_that("with kmeans_k the cluster centres it draws are read", {
  set.seed(1)
  m <- matrix(rnorm(200), 40, 5)
  set.seed(2)
  p <- ph_draw(m, kmeans_k = 3)
  layer <- ph_layer(p)
  centres <- p$kmeans$centers[p$tree_row$order, p$tree_col$order]
  expect_identical(ph_points(layer), unname(centres))
  expect_match(unlist(layer$data$y), "^Cluster: [0-9]+ Size: [0-9]+$")
})

test_that("a missing cell is a hole, and an unnamed matrix is named by position", {
  m <- unname(ph_matrix())
  m[2, 3] <- NA
  layer <- ph_layer(ph_draw(m, cluster_rows = FALSE, cluster_cols = FALSE))

  expect_identical(unlist(layer$data$y), as.character(1:4))
  expect_identical(unlist(layer$data$x), as.character(1:5))
  expect_identical(ph_points(layer), m)
})

test_that("each selector names the one cell drawn for it", {
  m <- ph_matrix()
  p <- ph_draw(m)
  orchestrator <- get_global_registry()$get_adapter_for_plot(p)$create_orchestrator(p)
  svg <- xml2::read_xml(paste(build_interactive_svg(orchestrator), collapse = "\n"))
  layer <- orchestrator$generate_maidr_data()$subplots[[1]][[2]]$layers[[1]]
  expect_identical(layer$type, "heat")

  fill <- pheatmap_child(pheatmap_grob(p$gtable, "matrix"), "rect")$gp$fill
  n <- nrow(fill)
  expect_length(layer$selectors, n)
  for (r in seq_len(n)) {
    # The selector grid runs bottom row first; the fill matrix top first.
    top_row <- n - r + 1L
    for (c in seq_len(ncol(fill))) {
      id <- gsub("\\\\", "", sub("^#", "", layer$selectors[[r]][[c]]))
      cell <- xml2::xml_find_all(svg, sprintf("//*[@id='%s']", id))
      expect_length(cell, 1L)
      rgb <- grDevices::col2rgb(fill[top_row, c])
      expect_identical(
        xml2::xml_attr(cell, "fill"),
        sprintf("rgb(%d,%d,%d)", rgb[1], rgb[2], rgb[3])
      )
    }
  }
})

test_that("drawn by pheatmap itself, values are read from the legend and said to be approximate", {
  m <- ph_matrix()
  p <- ph_draw_direct(m, main = "Expression")
  expect_message(layer <- ph_layer(p), "approximate", class = "maidr_pheatmap_values")

  expect_match(layer$title, "^Expression \\(approximate values")
  drawn <- m[p$tree_row$order, p$tree_col$order]
  expect_identical(unlist(layer$data$y), rownames(drawn))
  # The middle of each cell's legend band: within a band's width (1/100 of
  # the range) of the input.
  band <- diff(range(m)) / 100
  expect_lt(max(abs(ph_points(layer) - drawn)), band)
})

test_that("a kept matrix that does not match the colours is not trusted", {
  m <- ph_matrix()
  p <- ph_draw(m)
  attr(p, "maidr_matrix") <- attr(p, "maidr_matrix") * 10
  expect_message(layer <- ph_layer(p), "approximate", class = "maidr_pheatmap_values")
  drawn <- m[p$tree_row$order, p$tree_col$order]
  expect_lt(max(abs(ph_points(layer) - drawn)), diff(range(m)) / 100)
})

test_that("without the matrix, printed numbers are read only when they are the values", {
  m <- ph_matrix()
  p <- ph_draw_direct(m, scale = "row", display_numbers = TRUE, cluster_rows = FALSE)
  expect_message(layer <- ph_layer(p), "as printed", class = "maidr_pheatmap_values")
  scaled <- t(scale(t(m)))[, p$tree_col$order]
  expect_equal(ph_points(layer), unname(round(scaled, 2)), ignore_attr = TRUE)

  # Numbers printed over the cells that are not their values -- p-values --
  # are not announced as them.
  p_values <- matrix(round(stats::runif(20), 3), 4, 5)
  p <- ph_draw_direct(m, display_numbers = p_values)
  expect_message(layer <- ph_layer(p), "approximate", class = "maidr_pheatmap_values")
  drawn <- m[p$tree_row$order, p$tree_col$order]
  expect_lt(max(abs(ph_points(layer) - drawn)), diff(range(m)) / 100)
})

test_that("a pheatmap with no legend is read from its kept matrix, or falls back", {
  m <- ph_matrix()
  p <- ph_draw(m, legend = FALSE)
  expect_identical(ph_points(ph_layer(p)), unname(m[p$tree_row$order, p$tree_col$order]))

  p <- ph_draw_direct(m, legend = FALSE)
  orchestrator <- get_global_registry()$get_adapter_for_plot(p)$create_orchestrator(p)
  expect_match(orchestrator$unsupported_reasons(), "cannot be read")
  expect_true(orchestrator$has_unsupported_layers())
})

test_that("save_html() writes a heat layer for a pheatmap", {
  file <- withr::local_tempfile(fileext = ".html")
  save_html(ph_draw(ph_matrix()), file = file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_match(html, "&quot;type&quot;:&quot;heat&quot;", fixed = TRUE)
  expect_match(html, "id=\"maidr-pheatmap-cells.1.20\"", fixed = TRUE)
})

test_that("pheatmap attached after maidr is reported as masking its wrapper", {
  local_mocked_bindings(package_masks_maidr = function(package) identical(package, "pheatmap"))
  expect_message(.maidr_pheatmap_attach_hook(), "maidr::pheatmap\\(\\)")
  withr::local_options(maidr.startup_message = FALSE)
  expect_silent(.maidr_pheatmap_attach_hook())
})

# The dendrograms (#383) ---------------------------------------------------
#
# Each tree is checked against `stats::as.dendrogram()` of the same hclust:
# R's own walk of the merges, in the drawn order, rather than the one the
# processor makes.

ph_grid <- function(p) {
  orchestrator <- get_global_registry()$get_adapter_for_plot(p)$create_orchestrator(p)
  lapply(orchestrator$generate_maidr_data()$subplots, function(row) {
    vapply(row, function(s) if (length(s$layers)) s$layers[[1]]$type else "", character(1))
  })
}

ph_tree <- function(p, title) {
  layers <- ph_layers(p)
  layers[vapply(layers, function(l) identical(l$title, title), logical(1))][[1]]
}

# A tree's leaves, depth first: the nodes no other node is a child of
tree_leaves <- function(nodes) {
  address <- function(n) c(unlist(n$path), n$x)
  parents <- unique(lapply(nodes, function(n) unlist(n$path)))
  leaf <- vapply(nodes, function(n) {
    !any(vapply(parents, identical, logical(1), address(n)))
  }, logical(1))
  vapply(nodes[leaf], `[[`, "", "x")
}

# The nodes a dendrogram holds, root first, each child named as the
# processor is expected to name it.
dendrogram_expected <- function(node, path = character(0), own = NULL) {
  leaves <- base::labels(node)
  if (is.null(own)) {
    own <- if (stats::is.leaf(node)) {
      leaves
    } else {
      sprintf(
        "%s to %s (height %s)", leaves[1], leaves[length(leaves)],
        trimws(formatC(attr(node, "height"), digits = 3, format = "fg"))
      )
    }
  }
  out <- list(if (length(path)) list(x = own, path = as.list(path)) else list(x = own))
  if (!stats::is.leaf(node)) {
    # node[[i]], not `for (child in node)`, which drops each child's class.
    for (i in seq_along(node)) {
      out <- c(out, dendrogram_expected(node[[i]], c(path, own)))
    }
  }
  out
}

test_that("a pheatmap's trees are placed where pheatmap draws them", {
  m <- ph_matrix()
  # Rows bottom first: the row tree left of the matrix, the column tree
  # above it, the corner above the row tree empty.
  expect_identical(ph_grid(ph_draw(m)), list(c("tree", "heat"), c("", "tree")))
  expect_identical(ph_grid(ph_draw(m, cluster_rows = FALSE)), list("heat", "tree"))
  expect_identical(ph_grid(ph_draw(m, cluster_cols = FALSE)), list(c("tree", "heat")))
  expect_identical(
    ph_grid(ph_draw(m, cluster_rows = FALSE, cluster_cols = FALSE)), list("heat")
  )
  # Clustered but not drawn: the order is the tree's, and there is no tree.
  expect_identical(
    ph_grid(ph_draw(m, treeheight_row = 0, treeheight_col = 0)), list("heat")
  )
})

test_that("each tree is the hclust pheatmap drew, its leaves the heat layer's", {
  m <- ph_matrix()
  p <- ph_draw(m, main = "Expression")
  heat <- ph_layer(p)

  for (side in c("row", "col")) {
    title <- if (side == "row") "Row dendrogram" else "Column dendrogram"
    layer <- ph_tree(p, title)
    tree <- p[[paste0("tree_", side)]]
    expect_identical(layer$type, "tree")
    expect_identical(layer$axes, list(x = list(label = title)))
    expect_null(layer$selectors)
    expect_false("selectors" %in% names(layer))
    expect_identical(layer$data, dendrogram_expected(stats::as.dendrogram(tree)))
    expect_length(layer$data, 2L * length(tree$order) - 1L)

    expect_identical(
      tree_leaves(layer$data),
      unlist(if (side == "row") heat$data$y else heat$data$x)
    )
  }
})

test_that("a tree is built depth first, halves in drawn order", {
  # Leaves 1..4; 1+2 merge at 1, 3+4 at 2, both at 3. Drawn order 2, 1, 4, 3.
  tree <- list(
    merge = rbind(c(-1L, -2L), c(-3L, -4L), c(1L, 2L)),
    height = c(1, 2, 3),
    order = c(2L, 1L, 4L, 3L)
  )
  root <- "b to c (height 3)"
  left <- "b to a (height 1)"
  right <- "d to c (height 2)"
  expect_identical(pheatmap_tree_nodes(tree, c("b", "a", "d", "c")), list(
    list(x = root),
    list(x = left, path = list(root)),
    list(x = "b", path = list(root, left)),
    list(x = "a", path = list(root, left)),
    list(x = right, path = list(root)),
    list(x = "d", path = list(root, right)),
    list(x = "c", path = list(root, right))
  ))
})

test_that("sibling leaves with one label are told apart", {
  tree <- list(merge = rbind(c(-1L, -2L)), height = 0.5, order = 1:2)
  nodes <- pheatmap_tree_nodes(tree, c("same", "same"))
  expect_identical(vapply(nodes[-1], function(n) n$x, character(1)), c("same", "same (2)"))
  expect_identical(nodes[[1]]$x, "same to same (height 0.5)")
})

test_that("a merge height is said to three figures, never as an exponent", {
  expect_identical(pheatmap_tree_height(2.98765), "2.99")
  expect_identical(pheatmap_tree_height(1230.4), "1230")
  expect_identical(pheatmap_tree_height(0.00123456), "0.00123")
  expect_identical(pheatmap_tree_height(0), "0")
})

test_that("with kmeans_k the row tree is the one over the cluster centres", {
  set.seed(1)
  m <- matrix(rnorm(200), 40, 5)
  set.seed(2)
  p <- ph_draw(m, kmeans_k = 3)
  layer <- ph_tree(p, "Row dendrogram")
  expect_length(layer$data, 2L * 3L - 1L)
  expect_identical(tree_leaves(layer$data), unlist(ph_layer(p)$data$y))
  # Its hclust names the centres 1 to 3; the leaves are named as drawn.
  tree <- p$tree_row
  tree$labels[tree$order] <- unlist(ph_layer(p)$data$y)
  expect_identical(layer$data, dendrogram_expected(stats::as.dendrogram(tree)))
  expect_match(layer$data[[1]]$x, "^Cluster: [0-9]+ Size: [0-9]+ to Cluster")
})

test_that("gaps cut into a tree do not change it", {
  m <- ph_matrix()
  whole <- ph_layers(ph_draw(m))
  cut <- ph_layers(ph_draw(m, cutree_rows = 2, cutree_cols = 3))
  trees <- function(layers) Filter(function(l) identical(l$type, "tree"), layers)
  expect_identical(trees(cut), trees(whole))
})

test_that("an unnamed matrix's tree is named by position, as its heat layer is", {
  p <- ph_draw(unname(ph_matrix()))
  layer <- ph_tree(p, "Row dendrogram")
  expect_identical(layer$data[[1]]$x, sprintf(
    "%d to %d (height %s)", p$tree_row$order[1], p$tree_row$order[4],
    pheatmap_tree_height(max(p$tree_row$height))
  ))
})

test_that("save_html() writes the trees beside the heat layer", {
  file <- withr::local_tempfile(fileext = ".html")
  save_html(ph_draw(ph_matrix()), file = file)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_match(html, "&quot;type&quot;:&quot;tree&quot;", fixed = TRUE)
  expect_match(html, "Row dendrogram", fixed = TRUE)
  expect_match(html, "Column dendrogram", fixed = TRUE)
})
