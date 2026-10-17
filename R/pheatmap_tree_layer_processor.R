#' What a pheatmap's dendrogram layers are titled, by side
#' @keywords internal
PHEATMAP_TREE_TITLES <- c(row = "Row dendrogram", col = "Column dendrogram")

#' A merge height to three significant figures, never with an exponent
#' @param height A number
#' @return A string: `"2.99"`, `"0.00123"`, `"1230"`
#' @keywords internal
pheatmap_tree_height <- function(height) {
  trimws(formatC(height, digits = 3, format = "fg"))
}

#' A dendrogram as maidr.js's `tree` trace reads it
#'
#' Every node of an `hclust`, root first and depth first, the two halves of
#' each merge in the order they are drawn (`tree$order`). A leaf is named by
#' the row or column it is in the heat layer; a cluster by the first and last
#' leaf it spans in that order and the height it merged at --
#' `"d to e (height 2.99)"` -- so a reader knows where in the matrix it lies.
#' A cluster's leaves are contiguous in the drawn order, so two sibling
#' clusters never share a name; two leaves with one label do, and the second
#' is numbered, `"a (2)"`, as the trace needs a node's name unique among its
#' siblings.
#'
#' No magnitude (`y`) is declared: the trace reads one as a share of the
#' parent, which a merge height is not, and a leaf has none.
#'
#' @param tree An `hclust`: `merge`, `height`, `order`
#' @param names What each leaf is called, in drawn order
#' @return A list of nodes, `list(x = name)` with `path` (the ancestors'
#'   names, root first) on every node but the root; empty when nothing was
#'   merged or the names do not fit the tree
#' @keywords internal
pheatmap_tree_nodes <- function(tree, names) {
  pheatmap_tree_walk(tree, names)$nodes
}

#' [pheatmap_tree_nodes()], each node beside the one of the `hclust` it is
#'
#' @param tree,names As [pheatmap_tree_nodes()] takes them
#' @return A list: `nodes`, as [pheatmap_tree_nodes()] returns them, and
#'   `ids`, the `hclust`'s number for each in the same order -- `-i` for
#'   the leaf of input row `i`, `k` for the merge in row `k` of `merge`
#' @keywords internal
pheatmap_tree_walk <- function(tree, names) {
  merge <- tree$merge
  order <- tree$order
  count <- length(order)
  if (!is.matrix(merge) || nrow(merge) == 0L || nrow(merge) != count - 1L ||
    length(names) != count || length(tree$height) != nrow(merge)) {
    return(list(nodes = list(), ids = integer(0)))
  }
  names <- as.character(names)

  # A node is a leaf `-i` (input row i) or a merge `k` (row k of `merge`).
  # Each spans a run of drawn positions; a merge only names nodes made
  # before it, so one pass in order finds every child's span first.
  position <- integer(count)
  position[order] <- seq_len(count)
  span <- function(node) if (node < 0) rep(position[-node], 2L) else spans[node, ]
  spans <- matrix(0L, nrow(merge), 2L)
  halves <- matrix(0L, nrow(merge), 2L)
  for (k in seq_len(nrow(merge))) {
    pair <- merge[k, ]
    left <- span(pair[1])
    right <- span(pair[2])
    if (left[1] > right[1]) {
      pair <- rev(pair)
      tmp <- left
      left <- right
      right <- tmp
    }
    halves[k, ] <- pair
    spans[k, ] <- c(left[1], right[2])
  }

  name_of <- function(node) {
    at <- span(node)
    if (node < 0) {
      return(names[at[1]])
    }
    sprintf(
      "%s to %s (height %s)",
      names[at[1]], names[at[2]], pheatmap_tree_height(tree$height[node])
    )
  }

  # Depth first from the root, with a stack rather than recursion: a tree of
  # thousands of rows can be thousands of merges deep.
  nodes <- vector("list", count + nrow(merge))
  ids <- integer(length(nodes))
  root <- nrow(merge)
  stack <- list(list(node = root, own = name_of(root), path = character(0)))
  at <- 0L
  while (length(stack)) {
    top <- stack[[length(stack)]]
    stack[[length(stack)]] <- NULL
    at <- at + 1L
    ids[at] <- top$node
    nodes[[at]] <- if (length(top$path)) {
      list(x = top$own, path = as.list(top$path))
    } else {
      list(x = top$own)
    }
    if (top$node < 0) {
      next
    }
    taken <- character(0)
    children <- list()
    for (child in halves[top$node, ]) {
      base <- name_of(child)
      label <- base
      suffix <- 2L
      while (label %in% taken) {
        label <- sprintf("%s (%d)", base, suffix)
        suffix <- suffix + 1L
      }
      taken <- c(taken, label)
      children[[length(children) + 1L]] <- list(
        node = child, own = label, path = c(top$path, top$own)
      )
    }
    # Pushed last first, so the first half in drawn order is taken first.
    stack <- c(stack, rev(children))
  }
  list(nodes = nodes, ids = ids)
}

#' The radius, in big points, of the unseen mark at each dendrogram node
#'
#' And so of the dot maidr.js paints when it highlights the node.
#'
#' @keywords internal
PHEATMAP_NODE_RADIUS <- 4

#' The grob name of the mark at one node of a pheatmap dendrogram
#'
#' The mark is exported as the SVG element `#<name>.1.1`.
#'
#' @param side `"row"` or `"col"`
#' @param k The node's position in the layer's node order
#' @return A string, `"maidr-pheatmap-row-node-3"`
#' @keywords internal
pheatmap_node_name <- function(side, k) {
  paste0("maidr-pheatmap-", side, "-node-", k)
}

#' Measure grid units in two viewports of different sizes
#'
#' The positions pheatmap draws are sums of `npc` and `bigpts`, so two
#' measurements at different sizes tell any two of them apart.
#'
#' @param units A list of units, each named `"x"` or `"y"` for the axis it
#'   is measured along
#' @return A list of matrices in big points, one row per value of the unit
#'   and one column per viewport
#' @keywords internal
pheatmap_measure_units <- function(units) {
  current <- grDevices::dev.cur()
  grDevices::pdf(NULL)
  scratch <- grDevices::dev.cur()
  on.exit(
    {
      grDevices::dev.off(scratch)
      if (current > 1L && current %in% grDevices::dev.list()) {
        grDevices::dev.set(current)
      }
    },
    add = TRUE
  )
  sizes <- PHEATMAP_MEASURE_SIZES
  measured <- lapply(sizes, function(size) {
    grid::pushViewport(grid::viewport(
      width = grid::unit(size[[1]], "bigpts"),
      height = grid::unit(size[[2]], "bigpts")
    ))
    on.exit(grid::popViewport())
    lapply(names(units), function(axis) {
      convert <- if (identical(axis, "x")) grid::convertX else grid::convertY
      convert(units[[axis]], "bigpts", valueOnly = TRUE)
    })
  })
  lapply(seq_along(units), function(i) {
    do.call(cbind, lapply(measured, `[[`, i))
  })
}

#' The viewports units are measured in, width and height in big points
#' @keywords internal
PHEATMAP_MEASURE_SIZES <- list(c(1000, 700), c(613, 1291))

#' The gaps cut into a pheatmap dendrogram, from where its leaves are drawn
#'
#' Along the tree, pheatmap draws a position `m` (in leaves, `0` to `n`) at
#' `m / n * (L - 4G) + 4g` big points in a length of `L`, `G` being the
#' number of gaps and `g` the number before `m`. The last leaf has every gap
#' before it, which gives `G`; each leaf then gives its `g`, and a gap lies
#' wherever `g` steps up.
#'
#' @param leaf_m Each leaf's position along the tree, in leaves
#' @param drawn Where each leaf is drawn along the tree, in big points, in
#'   a length of `length_along`
#' @param length_along The length the leaves were measured in
#' @return The gaps, as pheatmap takes `gaps_row`: after how many leaves
#'   each lies, in drawn order; NULL when the leaves are not drawn so
#' @keywords internal
pheatmap_tree_gaps <- function(leaf_m, drawn, length_along) {
  n <- length(leaf_m)
  offset <- drawn - leaf_m / n * length_along
  last <- which.max(leaf_m)
  total <- offset[last] * n / (4 * (n - leaf_m[last]))
  before <- offset / 4 + total * leaf_m / n
  if (anyNA(before) || abs(total - round(total)) > 1e-3 ||
    any(abs(before - round(before)) > 1e-3)) {
    return(NULL)
  }
  steps <- diff(c(0, round(before)[order(leaf_m)]))
  if (any(steps < 0) || sum(steps) != round(total)) {
    return(NULL)
  }
  rep(seq_len(n) - 1L, steps)
}

#' Where pheatmap draws each node of a dendrogram
#'
#' pheatmap draws a dendrogram with its own `draw_dendrogram()`: leaf `i`
#' of the drawn order at `i - 0.5` of `n` along the tree and at height 0;
#' a merge midway between its two halves, at its height over the highest
#' times 1.05, in `npc`; each merge a link up from one half, across at its
#' height and down to the other. Along the tree, a position `m` is drawn at
#' `m / n` of the space the gaps (`cutree_rows`, `gaps_row`, ...) leave,
#' each gap before it adding 4 big points. The column tree is drawn so; the
#' row tree on its side, `x = 1npc - height` and `y = 1npc - along`.
#'
#' A node is placed at the tip of its leaf or the apex of its link -- where
#' its parent's link meets it. The gaps are read from where the leaves are
#' drawn ([pheatmap_tree_gaps()]), and then every link is checked, point by point, against the
#' polyline pheatmap drew: a layout this does not foresee places nothing
#' rather than a mark beside the link it names.
#'
#' @param tree The `hclust` the dendrogram was drawn from
#' @param drawn The polyline grob pheatmap drew for it
#' @param horizontal `TRUE` for the column tree, `FALSE` for the row tree
#' @return A list of `x` and `y` units, one value per node in the order of
#'   [pheatmap_tree_nodes()], or NULL when a node cannot be placed on the
#'   drawn links
#' @keywords internal
pheatmap_tree_marks <- function(tree, drawn, horizontal) {
  merge <- tree$merge
  n <- length(tree$order)
  ids <- pheatmap_tree_walk(tree, seq_len(n))$ids
  k <- if (is.matrix(merge)) nrow(merge) else 0L
  if (!length(ids) || !inherits(drawn, "polyline") ||
    length(drawn$x) != 4L * k || length(drawn$y) != 4L * k ||
    !identical(as.integer(drawn$id), rep(seq_len(k), each = 4L))) {
    return(NULL)
  }
  if (!all(is.finite(tree$height)) || max(tree$height) <= 0) {
    return(NULL)
  }

  # Each node's position along the tree, in leaves, and its height in npc:
  # leaf i at row i, merge j at row n + j. Computed in pheatmap's own steps,
  # to the last bit: a merge midway between two leaves either side of a gap
  # sits on the gap, and which side of it pheatmap draws it is decided by
  # the rounding.
  row_of <- function(node) ifelse(node < 0, -node, n + node)
  along <- numeric(n + k)
  height <- numeric(n + k)
  along[seq_len(n)] <- 1 / n / 2 + (1 / n) * (match(seq_len(n), tree$order) - 1)
  lifted <- tree$height / max(tree$height) / 1.05
  for (j in seq_len(k)) {
    along[n + j] <- (along[row_of(merge[j, 1])] + along[row_of(merge[j, 2])]) / 2
    height[n + j] <- lifted[j]
  }
  along <- along * n

  # Each drawn point's node: points 1-2 of link j rise from its first half,
  # points 3-4 from its second.
  point_rows <- as.vector(rbind(
    row_of(merge[, 1]), row_of(merge[, 1]), row_of(merge[, 2]), row_of(merge[, 2])
  ))
  point_heights <- as.vector(rbind(
    height[row_of(merge[, 1])], lifted, lifted, height[row_of(merge[, 2])]
  ))

  drawn_at <- pheatmap_measure_units(list(x = drawn$x, y = drawn$y))
  length_along <- PHEATMAP_MEASURE_SIZES[[1]][[if (horizontal) 1L else 2L]]
  drawn_along <- if (horizontal) drawn_at[[1]][, 1] else length_along - drawn_at[[2]][, 1]
  gaps <- pheatmap_tree_gaps(
    along[seq_len(n)], drawn_along[match(seq_len(n), point_rows)], length_along
  )
  if (is.null(gaps)) {
    return(NULL)
  }

  # Positions along the tree, as pheatmap's find_coordinates() makes them
  coord <- function(m) {
    if (!length(gaps)) {
      return(grid::unit(m / n, "npc"))
    }
    size <- (1 / n) * (grid::unit(1, "npc") - length(gaps) * grid::unit(4, "bigpts"))
    m * size + vapply(m, function(v) sum(v > gaps), numeric(1)) * grid::unit(4, "bigpts")
  }
  place <- function(m, h) {
    if (horizontal) {
      list(x = coord(m), y = grid::unit(h, "npc"))
    } else {
      list(
        x = grid::unit(1, "npc") - grid::unit(h, "npc"),
        y = grid::unit(1, "npc") - coord(m)
      )
    }
  }

  links <- place(along[point_rows], point_heights)
  nodes <- place(along[row_of(ids)], height[row_of(ids)])
  expected <- pheatmap_measure_units(list(x = links$x, y = links$y))
  same <- function(a, b) isTRUE(all(abs(a - b) < 1e-3))
  if (!same(expected[[1]], drawn_at[[1]]) || !same(expected[[2]], drawn_at[[2]])) {
    return(NULL)
  }
  nodes
}

#' Draw an unseen mark at each node of one of a pheatmap's dendrograms
#'
#' maidr.js highlights a `tree` node by an element drawn for it, one per
#' node in the layer's order, and pheatmap draws one link per merge and
#' nothing at a leaf. So a small circle is drawn at each node
#' ([pheatmap_tree_marks()]), named [pheatmap_node_name()] in the layer's
#' node order: no fill and no stroke, so the chart looks as it did, and the
#' highlight paints a copy of it, a dot on the apex of a link or the tip of
#' a leaf. They are drawn after the links and unclipped, so a leaf's mark on
#' the edge of the dendrogram's cell is whole.
#'
#' The dendrogram's cell then holds a gTree named
#' `"maidr-pheatmap-<side>-tree"`: the links as drawn, then the marks.
#'
#' @param plot The pheatmap object
#' @param gt Its gtable
#' @param side `"row"` or `"col"`
#' @return The gtable, marked; unchanged when that side has no drawn tree or
#'   its nodes cannot be placed on the drawn links
#' @keywords internal
pheatmap_mark_tree <- function(plot, gt, side) {
  tree <- plot[[paste0("tree_", side)]]
  at <- match(paste0(side, "_tree"), gt$layout$name)
  if (!inherits(tree, "hclust") || is.na(at)) {
    return(gt)
  }
  drawn <- gt$grobs[[at]]
  marks <- tryCatch(
    pheatmap_tree_marks(tree, drawn, horizontal = identical(side, "col")),
    error = function(e) NULL
  )
  if (is.null(marks)) {
    return(gt)
  }
  circles <- lapply(seq_along(marks$x), function(k) {
    grid::circleGrob(
      x = marks$x[k], y = marks$y[k],
      r = grid::unit(PHEATMAP_NODE_RADIUS, "bigpts"),
      gp = grid::gpar(fill = "transparent", col = NA),
      name = pheatmap_node_name(side, k)
    )
  })
  nodes <- grid::gTree(
    children = do.call(grid::gList, circles),
    vp = grid::viewport(clip = "off", name = paste0("maidr-pheatmap-", side, "-nodes-vp")),
    name = paste0("maidr-pheatmap-", side, "-nodes")
  )
  gt$grobs[[at]] <- grid::gTree(
    children = grid::gList(drawn, nodes),
    name = paste0("maidr-pheatmap-", side, "-tree")
  )
  gt
}

#' pheatmap Dendrogram Layer Processor
#'
#' @description
#' Reads one of a pheatmap's dendrograms as a `tree` layer, from the
#' `hclust` it was drawn from (`tree_row` or `tree_col`); see
#' [pheatmap_tree_nodes()] for the nodes. Experimental.
#'
#' A side has a tree only when it was clustered and the tree is drawn: not
#' with `cluster_rows = FALSE`, nor with `treeheight_row = 0`, which orders
#' the rows by the tree but draws none. With `kmeans_k` the row tree is the
#' one pheatmap draws, over the cluster centres. `cutree_rows` only spaces
#' the drawing; the tree is unchanged.
#'
#' Each leaf is named as the heat layer names its row or column
#' ([pheatmap_axis_labels()]), in the same order.
#'
#' **Selectors.** One per node, in node order: the unseen mark
#' [pheatmap_mark_tree()] drew at it, which the orchestrator adds before the
#' layer is read. pheatmap draws a dendrogram as one polyline per merge --
#' `n - 1` marks for `2n - 1` nodes, nothing at a leaf -- so the marks are
#' what the highlight lands on. When they could not be placed on the drawn
#' links there are none, and no selectors: a highlight that cannot be
#' aligned is left out rather than placed on the wrong link.
#'
#' @keywords internal
PheatmapTreeLayerProcessor <- R6::R6Class(
  "PheatmapTreeLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Read the layer
    #' @param plot The pheatmap object
    #' @param layout Unused
    #' @param built Unused
    #' @param gt The gtable
    #' @param grob_id Unused
    #' @param panel_id Unused
    #' @param panel_ctx Unused
    #' @param layer_info Unused; the side is the processor's `layer_info$side`
    #' @return The layer, or NULL when that side has no drawn tree
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      nodes <- self$extract_data(plot, gt)
      if (!length(nodes)) {
        return(NULL)
      }
      title <- PHEATMAP_TREE_TITLES[[self$side()]]
      list(
        type = "tree",
        data = nodes,
        selectors = self$generate_selectors(plot, gt),
        title = title,
        axes = build_axes(x = title)
      )
    },

    #' @description `"row"` or `"col"`
    #' @return The side this processor reads
    side = function() {
      side <- self$layer_info$side
      if (!identical(side, "row") && !identical(side, "col")) {
        stop("a pheatmap tree layer is on side 'row' or 'col'")
      }
      side
    },

    #' @description The tree's nodes
    #' @param plot The pheatmap object
    #' @param built The gtable
    #' @return A list of nodes, empty when the side has no drawn tree
    extract_data = function(plot, built = NULL) {
      gt <- built
      side <- self$side()
      tree <- plot[[paste0("tree_", side)]]
      if (!inherits(tree, "hclust") || is.null(pheatmap_grob(gt, paste0(side, "_tree")))) {
        return(list())
      }
      fill <- pheatmap_child(pheatmap_grob(gt, "matrix"), "rect")$gp$fill
      if (is.null(fill) || !is.matrix(fill)) {
        return(list())
      }
      names <- if (identical(side, "row")) {
        pheatmap_axis_labels(gt, "row_names", rownames(fill), tree, nrow(fill))
      } else {
        pheatmap_axis_labels(gt, "col_names", colnames(fill), tree, ncol(fill))
      }
      pheatmap_tree_nodes(tree, names)
    },

    #' @description One selector per node, for the marks
    #'   [pheatmap_mark_tree()] drew; see the class description
    #' @param plot The pheatmap object
    #' @param gt The gtable
    #' @param grob_id Unused
    #' @param panel_ctx Unused
    #' @return A list of selectors in node order, or NULL when the tree's
    #'   cell holds no mark for every node
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      side <- self$side()
      cell <- pheatmap_grob(gt, paste0(side, "_tree"))
      marked <- !is.null(cell) && identical(cell$name, paste0("maidr-pheatmap-", side, "-tree"))
      marks <- if (marked) cell$children[[paste0("maidr-pheatmap-", side, "-nodes")]]$children
      count <- 2L * length(plot[[paste0("tree_", side)]]$order) - 1L
      names <- pheatmap_node_name(side, seq_len(count))
      if (count < 1L || length(marks) != count || !identical(names(marks), names)) {
        return(NULL)
      }
      lapply(names, lattice_shape_selector, index = 1L)
    }
  )
)
