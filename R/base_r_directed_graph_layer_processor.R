#' Base R Directed Graph Layer Processor
#'
#' @description
#' Reads `plot()` of a directed igraph object -- igraph's own `plot.igraph()`
#' -- as a directed graph: one node per vertex, in vertex order, each naming
#' the vertices whose edges arrive at it, with its own attributes, read from
#' the graph rather than the drawing. Each node is outlined as its own
#' circle: `plot.igraph()` draws every circle vertex with one `symbols()`
#' call, in vertex order, and gridGraphics exports that call as one group of
#' `<circle>` elements.
#'
#' Emitted with `type = "directed_graph"`, which the core has read since
#' maidr 4.14.0.
#'
#' @keywords internal
BaseRDirectedGraphLayerProcessor <- R6::R6Class(
  "BaseRDirectedGraphLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the layer: the graph's nodes, one selector each
    #' @param plot Unused; present for the processor interface
    #' @param layout Unused; present for the processor interface
    #' @param built Unused; present for the processor interface
    #' @param gt Gtable of the replayed drawing, searched for selectors (optional)
    #' @param grob_id Unused; present for the processor interface
    #' @param panel_id Unused; present for the processor interface
    #' @param panel_ctx Unused; present for the processor interface
    #' @param layer_info Layer information with the recorded call
    #' @return List describing the layer for the MAIDR payload
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      args <- layer_info$plot_call$args
      graph <- resolve_xy_args(args)$x
      nodes <- igraph_directed_nodes(graph)
      if (is.null(nodes)) {
        nodes <- list()
      }
      main <- args[["main"]]

      list(
        data = nodes,
        selectors = self$generate_selectors(layer_info, gt, length(nodes)),
        type = "directed_graph",
        title = if (is.character(main) && length(main) == 1L) main else "",
        axes = list(x = list(label = "Node"))
      )
    },

    #' @description Whether the plot data must be reordered; never
    #' @return FALSE
    needs_reordering = function() {
      FALSE
    },

    #' @description One selector per node, each naming its own circle
    #' @param layer_info Layer information with the recorded call
    #' @param gt Gtable of the replayed drawing (optional)
    #' @param n_nodes How many nodes the layer declares
    #' @return A list of selectors, or an empty list when the circles cannot
    #'   be found
    generate_selectors = function(layer_info, gt = NULL, n_nodes = 0L) {
      if (is.null(gt) || n_nodes < 1L) {
        return(list())
      }
      group_index <- layer_info$group_index %||% layer_info$index
      circles <- find_graphics_plot_grobs(gt, "symbols-circle", group_index)
      if (length(circles) != 1L) {
        return(list())
      }
      group <- paste0("g#", gsub("\\.", "\\\\.", paste0(circles, ".1")), " > circle")
      lapply(seq_len(n_nodes), function(i) {
        paste0(group, ":nth-of-type(", i, ")")
      })
    }
  )
)

#' How Base R's `plot()` of an igraph object is read
#'
#' A directed graph whose every vertex is drawn as a circle -- igraph's
#' default shape -- is a `directed_graph`, the circles being where each node
#' is outlined. Anything else is `"unknown"`, so the chart is shown as a
#' picture: read as the points layer `plot()` otherwise types it, it was an
#' interactive chart with no points in it.
#'
#' @param graph The igraph object `plot()` was handed
#' @param args The recorded call's arguments
#' @return `"directed_graph"` or `"unknown"`
#' @keywords internal
base_r_igraph_layer_type <- function(graph, args) {
  readable <- requireNamespace("igraph", quietly = TRUE) &&
    directed_graph_trace_available() &&
    isTRUE(igraph::is_directed(graph)) &&
    igraph::vcount(graph) > 0L &&
    !isTRUE(args[["add"]]) &&
    igraph_circles_only(graph, args)
  if (readable) "directed_graph" else "unknown"
}

#' Whether `plot.igraph()` draws every vertex as a circle
#'
#' @param graph The igraph object
#' @param args The recorded call's arguments
#' @return TRUE when the shape asked for, the graph's own or igraph's
#'   default, is a circle for every vertex
#' @keywords internal
igraph_circles_only <- function(graph, args) {
  shape <- args[["vertex.shape"]] %||%
    igraph::vertex_attr(graph, "shape") %||%
    igraph::igraph_opt("vertex.shape")
  all(shape == "circle")
}
