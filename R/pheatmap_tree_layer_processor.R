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
  merge <- tree$merge
  order <- tree$order
  count <- length(order)
  if (!is.matrix(merge) || nrow(merge) == 0L || nrow(merge) != count - 1L ||
    length(names) != count || length(tree$height) != nrow(merge)) {
    return(list())
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
  root <- nrow(merge)
  stack <- list(list(node = root, own = name_of(root), path = character(0)))
  at <- 0L
  while (length(stack)) {
    top <- stack[[length(stack)]]
    stack[[length(stack)]] <- NULL
    at <- at + 1L
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
  nodes
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
#' **Selectors.** None. pheatmap draws a dendrogram as one polyline per merge
#' -- `n - 1` marks for `2n - 1` nodes, nothing at a leaf -- and the trace
#' needs one element per node, in node order; a highlight that cannot be
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

    #' @description No selectors; see the class description
    #' @param plot Unused
    #' @param gt Unused
    #' @param grob_id Unused
    #' @param panel_ctx Unused
    #' @return NULL
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      NULL
    }
  )
)
