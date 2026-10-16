#' What a ComplexHeatmap's dendrogram layers are titled, by side
#' @keywords internal
COMPLEXHEATMAP_TREE_TITLES <- c(row = "Row dendrogram", column = "Column dendrogram")

#' Dendrograms as maidr.js's `tree` trace reads them
#'
#' The nodes a ComplexHeatmap draws for one dendrogram, in the shape
#' [pheatmap_tree_nodes()] gives a pheatmap's: root first and depth first,
#' each node's children in the order they are drawn (the order of the
#' `dendrogram`'s branches, whose leaves run in the order of the rows or
#' columns drawn), a leaf named by its row or column, a cluster by the first
#' and last leaf it spans and the height it merged at --
#' `"d to e (height 2.99)"` -- and a name repeated among siblings numbered,
#' `"a (2)"`.
#'
#' A heat map split into slices has a dendrogram per slice. When
#' 'ComplexHeatmap' clusters the slices too (`cluster_row_slices = TRUE`,
#' the default), it draws a dendrogram over them, its leaves the slices in
#' drawn order; that is `parent`, and each of its leaves is replaced by the
#' slice's own dendrogram, as `ComplexHeatmap::merge_dendrogram()` joins
#' them. A cluster of slices is named by its own height: where the slices'
#' means merged when `row_split`, `row_km` and the like split the heat map,
#' or the height in the dendrogram that was cut when `row_split` cut it. The
#' drawing lifts the parent above the tallest slice, which is a place to draw
#' it, not a height anything merged at.
#'
#' A leaf is matched to its row or column by where it is drawn, not by its
#' value, which indexes the whole matrix for a cut dendrogram and only the
#' slice for one clustered within a slice.
#'
#' @param dends The dendrograms, one per slice, in drawn order
#' @param names What each leaf of all of them is called, in drawn order
#' @param parent The dendrogram drawn over the slices, or NULL
#' @return A list of nodes, `list(x = name)` with `path` (the ancestors'
#'   names, root first) on every node but the root; empty when nothing was
#'   merged or the names do not fit the dendrograms
#' @keywords internal
complexheatmap_tree_nodes <- function(dends, names, parent = NULL) {
  if (is.null(parent) && length(dends) != 1L) {
    return(list())
  }
  names <- as.character(names)
  is_leaf <- function(node) isTRUE(attr(node, "leaf")) || !is.list(node)

  # Flatten the tree, depth first with a stack rather than by recursion (a
  # tree of thousands of rows can be thousands of merges deep): a node's id
  # is its place in that walk, so the root is 1 and a child comes after its
  # parent, and the leaves are met in drawn order.
  height <- numeric(0)
  leaf <- integer(0)
  kids <- list()
  slices <- 0L
  leaves <- 0L
  id <- 0L
  stack <- list(list(node = parent %||% dends[[1]], up = 0L, slice = !is.null(parent)))
  while (length(stack)) {
    top <- stack[[length(stack)]]
    stack[[length(stack)]] <- NULL
    node <- top$node
    slice <- top$slice
    if (slice && is_leaf(node)) {
      slices <- slices + 1L
      if (slices > length(dends)) {
        return(list())
      }
      node <- dends[[slices]]
      slice <- FALSE
    }
    id <- id + 1L
    kids[id] <- list(integer(0))
    if (top$up > 0L) {
      kids[[top$up]] <- c(kids[[top$up]], id)
    }
    if (is_leaf(node)) {
      leaves <- leaves + 1L
      leaf[id] <- leaves
      height[id] <- NA_real_
      next
    }
    h <- attr(node, "height")
    if (length(node) == 0L || !is.numeric(h) || length(h) != 1L || !is.finite(h)) {
      return(list())
    }
    leaf[id] <- NA_integer_
    height[id] <- h
    # Pushed last first, so the first branch is taken first.
    for (i in rev(seq_along(node))) {
      stack[[length(stack) + 1L]] <- list(node = node[[i]], up = id, slice = slice)
    }
  }
  if (leaves != length(names) || (!is.null(parent) && slices != length(dends)) ||
    all(!is.na(leaf))) {
    return(list())
  }

  # The first and last leaf each node spans: a child comes after its parent.
  first <- leaf
  last <- leaf
  for (k in rev(seq_len(id))) {
    if (is.na(leaf[k])) {
      first[k] <- first[kids[[k]][1]]
      last[k] <- last[kids[[k]][length(kids[[k]])]]
    }
  }
  name_of <- function(k) {
    if (!is.na(leaf[k])) {
      return(names[leaf[k]])
    }
    sprintf(
      "%s to %s (height %s)",
      names[first[k]], names[last[k]], pheatmap_tree_height(height[k])
    )
  }

  label <- character(id)
  path <- vector("list", id)
  label[1] <- name_of(1L)
  path[1] <- list(character(0))
  nodes <- vector("list", id)
  for (k in seq_len(id)) {
    nodes[[k]] <- if (length(path[[k]])) {
      list(x = label[k], path = as.list(path[[k]]))
    } else {
      list(x = label[k])
    }
    taken <- character(0)
    for (child in kids[[k]]) {
      base <- name_of(child)
      own <- base
      suffix <- 2L
      while (own %in% taken) {
        own <- sprintf("%s (%d)", base, suffix)
        suffix <- suffix + 1L
      }
      taken <- c(taken, own)
      label[child] <- own
      path[[child]] <- c(path[[k]], label[k])
    }
  }
  nodes
}

#' The dendrograms a ComplexHeatmap draws on one side, as trees
#'
#' Nothing when the side is not clustered (`cluster_rows = FALSE`) or its
#' dendrogram is not shown (`show_row_dend = FALSE`), and nothing for a
#' slice of a single row, which has no dendrogram to draw. A split side
#' whose slices are clustered is one tree, the slices' dendrograms joined
#' under the one drawn over them; one whose slices are not
#' (`cluster_row_slices = FALSE`) draws a dendrogram per slice, unjoined,
#' and each is a tree of its own, titled by its slice: the slice's title,
#' else its number.
#'
#' @param heatmap The drawn `Heatmap`
#' @param side `"row"` or `"column"`
#' @param names What each row or column is called, in drawn order
#' @return A list of trees, each `list(title, nodes)`; empty when none is drawn
#' @keywords internal
complexheatmap_trees <- function(heatmap, side, names) {
  param <- methods::slot(heatmap, paste0(side, "_dend_param"))
  dends <- methods::slot(heatmap, paste0(side, "_dend_list"))
  orders <- methods::slot(heatmap, paste0(side, "_order_list"))
  title <- COMPLEXHEATMAP_TREE_TITLES[[side]]
  drawn <- isTRUE(param$show) && isTRUE(param$cluster) && length(dends) > 0L &&
    length(dends) == length(orders) && all(vapply(dends, inherits, logical(1), "dendrogram"))
  if (!drawn) {
    return(list())
  }
  if (length(dends) > 1L && isTRUE(param$cluster_slices)) {
    parent <- methods::slot(heatmap, paste0(side, "_dend_slice"))
    if (!inherits(parent, "dendrogram")) {
      return(list())
    }
    nodes <- complexheatmap_tree_nodes(unname(dends), names, parent = parent)
    return(if (length(nodes)) list(list(title = title, nodes = nodes)) else list())
  }
  if (length(dends) > 1L) {
    title <- paste0(title, ", slice ", complexheatmap_slice_titles(heatmap, side, length(dends)))
  }
  # Each slice's names: the run of drawn positions its rows or columns take.
  slice_of <- rep(seq_along(orders), lengths(orders))
  trees <- lapply(seq_along(dends), function(k) {
    nodes <- complexheatmap_tree_nodes(dends[k], names[slice_of == k])
    if (length(nodes)) list(title = title[k], nodes = nodes)
  })
  Filter(Negate(is.null), trees)
}

#' What each slice of a split side is called
#' @param heatmap The drawn `Heatmap`
#' @param side `"row"` or `"column"`
#' @param count The number of slices
#' @return The slices' titles, in drawn order, when each has one; else their
#'   numbers
#' @keywords internal
complexheatmap_slice_titles <- function(heatmap, side, count) {
  titles <- as.character(methods::slot(heatmap, paste0(side, "_title")))
  if (length(titles) != count || any(is.na(titles) | !nzchar(titles))) {
    return(as.character(seq_len(count)))
  }
  titles
}

#' ComplexHeatmap Dendrogram Layer Processor
#'
#' @description
#' Reads the dendrograms a ComplexHeatmap heat map draws on one side, rows
#' or columns, as `tree` layers, from the `HeatmapList` its drawing returned
#' ([complexheatmap_capture()]); see [complexheatmap_trees()] for which are
#' read and [complexheatmap_tree_nodes()] for the nodes. Experimental.
#'
#' Each leaf is named as the heat layer names its row or column
#' ([ComplexHeatmapLayerProcessor]), in the same order.
#'
#' **Selectors.** None. 'ComplexHeatmap' draws a dendrogram as segments,
#' several to a merge and nothing at a leaf, with no element per node; a
#' highlight that cannot be aligned with a node is left out rather than
#' placed on the wrong link.
#'
#' @keywords internal
ComplexHeatmapTreeLayerProcessor <- R6::R6Class(
  "ComplexHeatmapTreeLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Read the layers
    #' @param plot The `Heatmap` or `HeatmapList` passed in
    #' @param layout Unused
    #' @param built Unused
    #' @param gt The capture, from [complexheatmap_capture()]
    #' @param grob_id Unused
    #' @param panel_id Unused
    #' @param panel_ctx Unused
    #' @param layer_info Unused; the side is the processor's `layer_info$side`
    #' @return A list of `tree` layers, empty when the side has no drawn tree
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      lapply(self$extract_data(plot, gt), function(tree) {
        list(
          type = "tree",
          data = tree$nodes,
          selectors = self$generate_selectors(plot, gt),
          title = tree$title,
          axes = build_axes(x = tree$title)
        )
      })
    },

    #' @description `"row"` or `"column"`
    #' @return The side this processor reads
    side = function() {
      side <- self$layer_info$side
      if (!identical(side, "row") && !identical(side, "column")) {
        stop("a ComplexHeatmap tree layer is on side 'row' or 'column'")
      }
      side
    },

    #' @description Where the side's dendrograms are drawn
    #' @param gt The capture, from [complexheatmap_capture()]
    #' @return `"left"` or `"right"` for rows, `"top"` or `"bottom"` for
    #'   columns
    drawn_side = function(gt) {
      side <- self$side()
      drawn <- methods::slot(gt$heatmap, paste0(side, "_dend_param"))$side
      if (identical(side, "row")) {
        if (identical(drawn, "right")) "right" else "left"
      } else {
        if (identical(drawn, "bottom")) "bottom" else "top"
      }
    },

    #' @description The trees drawn on the side
    #' @param plot The `Heatmap` or `HeatmapList` passed in
    #' @param built The capture, from [complexheatmap_capture()]
    #' @return A list of `list(title, nodes)`, empty when none is drawn
    extract_data = function(plot, built = NULL) {
      heatmap <- built$heatmap
      side <- self$side()
      heat <- ComplexHeatmapLayerProcessor$new(list())
      names <- if (identical(side, "row")) {
        heat$labels(
          heatmap@row_names_param, rownames(heatmap@matrix),
          unlist(heatmap@row_order_list, use.names = FALSE)
        )
      } else {
        heat$labels(
          heatmap@column_names_param, colnames(heatmap@matrix),
          unlist(heatmap@column_order_list, use.names = FALSE)
        )
      }
      complexheatmap_trees(heatmap, side, names)
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
