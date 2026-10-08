#' Directed Graph Layer Processor
#'
#' @description
#' Reads the nodes of a [ggraph::ggraph()] drawing of a directed graph as the
#' `directed_graph` trace: one node per drawn point, each naming the nodes
#' whose edges arrive at it, so a reader walks the graph by its edges -- what
#' feeds a node, what it feeds, where the graph branches and merges.
#'
#' A ggraph chart is an edge layer (`geom_edge_link()` and its siblings,
#' ggraph's own geoms), a node layer (`geom_node_point()`, a `GeomPoint`
#' over the node layout) and labels. The edge geoms matched no branch of the
#' adapter, and an unread layer drops the whole chart to a static image; read
#' as points, the nodes would say only where the layout put them. So for a
#' directed graph the edge layers are skipped and the node layer carries the
#' graph, read from the `igraph` object ggraph keeps on the layout.
#'
#' Each node is highlighted as its own point: the node layer draws one point
#' per node, in node order, as one group of `<use>` elements.
#'
#' Emitted with `type = "directed_graph"`, which the core has read since
#' maidr 4.14.0.
#'
#' @keywords internal
Ggplot2DirectedGraphLayerProcessor <- R6::R6Class(
  "Ggplot2DirectedGraphLayerProcessor",
  inherit = Ggplot2PointLayerProcessor,
  public = list(
    #' @description Process the node layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, title, axes and type
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      nodes <- ggraph_directed_nodes(plot)
      if (is.null(nodes)) {
        nodes <- list()
      }

      list(
        data = nodes,
        selectors = self$node_selectors(plot, gt, grob_id, panel_ctx, length(nodes)),
        title = if (!is.null(layout$title)) layout$title else "",
        axes = list(x = list(label = "Node")),
        type = "directed_graph"
      )
    },

    #' @description One selector per node, each naming its own point
    #'
    #' The point processor names the layer's point group, `> use` matching
    #' every point in it; the n-th `<use>` is the n-th node.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @param n_nodes How many nodes the layer declares
    #' @return A list of selectors, or an empty list
    node_selectors = function(plot, gt = NULL, grob_id = NULL,
                              panel_ctx = NULL, n_nodes = 0L) {
      if (n_nodes < 1L) {
        return(list())
      }
      group <- tryCatch(
        unlist(self$generate_selectors(plot, gt, grob_id, panel_ctx)),
        error = function(e) NULL
      )
      if (length(group) != 1L || !endsWith(group, " > use")) {
        return(list())
      }
      lapply(seq_len(n_nodes), function(i) {
        paste0(group, ":nth-of-type(", i, ")")
      })
    }
  )
)

#' Whether the bundled maidr.js can build a `directed_graph` trace
#'
#' The `directed_graph` trace first shipped in maidr.js 4.14.0. A ggraph
#' chart was not read at all before, so without the trace it stays unread.
#'
#' @return TRUE when the pinned bundle carries the trace
#' @keywords internal
directed_graph_trace_available <- function() {
  utils::compareVersion(MAIDR_VERSION, "4.14.0") >= 0
}

#' The directed graph a ggraph plot was drawn from, or NULL
#'
#' `ggraph()` keeps the graph it laid out as the `graph` attribute of the
#' plot's data, a `tbl_graph` that is an `igraph` object.
#'
#' @param plot_object A ggplot2 plot
#' @return The igraph object when the plot is a ggraph of a directed graph
#' @keywords internal
ggraph_directed_graph <- function(plot_object) {
  if (!inherits(plot_object, "ggraph") ||
    !requireNamespace("igraph", quietly = TRUE)) {
    return(NULL)
  }
  graph <- tryCatch(attr(plot_object$data, "graph"), error = function(e) NULL)
  if (!inherits(graph, "igraph") || !isTRUE(igraph::is_directed(graph))) {
    return(NULL)
  }
  graph
}

#' Whether a layer is the node layer a directed ggraph's reading rides on
#'
#' The first `GeomPoint` layer drawn from the node layout itself -- its own
#' data unset, so it inherits the layout, and with no `filter` aesthetic, so
#' it draws every node in node order. A later point layer, or a filtered
#' one, is not claimed.
#'
#' @param layer A ggplot2 layer
#' @param plot_object The plot the layer belongs to
#' @return TRUE for the node layer of a directed ggraph
#' @keywords internal
is_ggraph_node_layer <- function(layer, plot_object) {
  if (is.null(ggraph_directed_graph(plot_object))) {
    return(FALSE)
  }
  is_node_points <- function(candidate) {
    identical(class(candidate$geom)[1], "GeomPoint") &&
      inherits(candidate$data, "waiver") &&
      !("filter" %in% names(candidate$mapping))
  }
  first <- Find(is_node_points, plot_object$layers)
  !is.null(first) && identical(first, layer)
}

#' The nodes of a directed ggraph, as the trace declares them
#'
#' One node per vertex, in vertex order -- the order the node layer draws
#' its points in. The id and label are the vertex's `name` when it has one,
#' and its index otherwise; `inputs` are the vertices whose edges arrive at
#' it; its other scalar attributes are announced with it.
#'
#' @param plot_object A ggraph plot
#' @return A list of nodes, or NULL when the plot is not a directed ggraph
#' @keywords internal
ggraph_directed_nodes <- function(plot_object) {
  graph <- ggraph_directed_graph(plot_object)
  if (is.null(graph)) {
    return(NULL)
  }
  igraph_directed_nodes(graph)
}

#' The nodes of a directed igraph object, as the trace declares them
#'
#' One node per vertex, in vertex order. The id and label are the vertex's
#' `name` when it has one, and its index otherwise; `inputs` are the vertices
#' whose edges arrive at it; its other scalar attributes are announced with
#' it. Shared by the ggraph reading and Base R's `plot()` of an igraph.
#'
#' @param graph A directed igraph object
#' @return A list of nodes, or NULL when the graph has no vertex or two
#'   vertices share a name
#' @keywords internal
igraph_directed_nodes <- function(graph) {
  count <- igraph::vcount(graph)
  if (count < 1L) {
    return(NULL)
  }

  names <- igraph::vertex_attr(graph, "name")
  ids <- if (is.null(names)) as.character(seq_len(count)) else as.character(names)
  if (anyDuplicated(ids) > 0L) {
    return(NULL)
  }

  # `name` is the id; a name starting with a dot is ggraph's own bookkeeping
  # (`.ggraph.orig_index`), not something the author put on the graph.
  attributes <- igraph::vertex_attr(graph)
  attributes <- attributes[names(attributes) != "name" &
    !startsWith(names(attributes), ".")]

  lapply(seq_len(count), function(v) {
    feeding <- as.integer(igraph::neighbors(graph, v, mode = "in"))
    node <- list(
      id = ids[[v]],
      label = ids[[v]],
      inputs = as.list(unique(ids[feeding]))
    )
    scalars <- list()
    for (key in names(attributes)) {
      value <- attributes[[key]][[v]]
      if (length(value) == 1L && !is.na(value) &&
        (is.character(value) || is.logical(value) ||
          (is.numeric(value) && is.finite(value)))) {
        scalars[[key]] <- if (is.factor(value)) as.character(value) else value
      }
    }
    if (length(scalars) > 0L) {
      node$attributes <- scalars
    }
    node
  })
}
