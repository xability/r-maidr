#' Group hexagonal bins into lattice rows
#'
#' A hex lattice staggers alternate rows by half a cell, which is what lets
#' the hexagons tessellate. Read as a grid of counted cells it is a heatmap,
#' but the stagger means a bin's column index is not its position -- bin 3 of
#' one row and bin 3 of the next sit at different x -- so the frontend
#' announces centres rather than indices and this returns the rows rather
#' than a rectangle.
#'
#' Rows ascend in y, because the frontend's UPWARD steps to the *next* row
#' index, the same convention the heatmap follows. Within a row bins ascend
#' in x.
#'
#' Rows are ragged and are left that way. \code{stat_binhex()} emits only the
#' bins that hold something, so the lattice is genuinely uneven; padding it
#' would put cells on the chart that were never drawn.
#'
#' The returned \code{order} is the point of the function. It is the built-data
#' row behind each emitted bin, in emission order, and the selectors are built
#' from it -- so the highlight follows the regrouping instead of relying on the
#' DOM happening to be in the same order. \code{stat_binhex()} does emit its
#' rows bottom-first today, which means that reliance would pass; it would also
#' be undetectable the moment it stopped, since a hexbin announces centres and
#' has no index to contradict.
#'
#' @param built_data A layer's computed data, carrying \code{x}, \code{y} and
#'   \code{count}, one row per drawn hexagon
#' @return A list with \code{data} (rows of bins, each a list of \code{x},
#'   \code{y} and \code{count}) and \code{order} (the built-data row behind
#'   each bin, in emission order)
#' @keywords internal
hexbin_lattice <- function(built_data) {
  empty <- list(data = list(), order = integer(0))
  if (is.null(built_data) || nrow(built_data) == 0) {
    return(empty)
  }
  if (!all(c("x", "y", "count") %in% names(built_data))) {
    return(empty)
  }

  # Grouped on the y centre by exact equality, which is exact rather than
  # approximate here: every centre in a lattice row is computed from the same
  # row index and the same cell height, so a row's values are identical bit
  # for bit, and the two staggered lattices are half a height apart.
  rows <- split(seq_len(nrow(built_data)), built_data$y)
  ordered_rows <- rows[order(as.numeric(names(rows)))]

  order <- integer(0)
  data <- list()
  for (indices in ordered_rows) {
    indices <- indices[order(built_data$x[indices])]
    data[[length(data) + 1L]] <- lapply(indices, function(i) {
      list(
        x = as.numeric(built_data$x[i]),
        y = as.numeric(built_data$y[i]),
        count = as.numeric(built_data$count[i])
      )
    })
    order <- c(order, indices)
  }

  list(data = data, order = order)
}

#' Hexbin Layer Processor
#'
#' @description
#' Processes hexagonal binning layers (\code{geom_hex}, \code{stat_binhex}).
#'
#' A hexbin is the standard answer to an overplotted scatter: bin the points
#' into hexagons and encode the count as fill. Read as a lattice of counted
#' cells that is a heatmap, and the navigation, braille and pitch all
#' transfer -- but the rows are staggered, so it is a layer type of its own
#' rather than a heatmap with different cells. See \code{hexbin_lattice()} for
#' what that costs.
#'
#' @keywords internal
Ggplot2HexbinLayerProcessor <- R6::R6Class(
  "Ggplot2HexbinLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the hexbin layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return List with data, selectors and axes
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      lattice <- self$extract_data(plot, built, panel_id)

      list(
        data = lattice$data,
        selectors = self$generate_selectors(gt, plot, panel_ctx, lattice$order),
        axes = self$extract_axes(plot, built)
      )
    },

    #' @description Read the drawn lattice out of the built data
    #'
    #'   The built data *is* the lattice: one row per drawn hexagon, carrying
    #'   its centre and its count. Nothing is reconstructed from the source
    #'   columns, which are the raw observations and say nothing about where
    #'   the stat placed the bins.
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return The list \code{hexbin_lattice()} returns
    extract_data = function(plot, built = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      # The panel filter lives in the base class, and taking it from there
      # matters more here than it looks: the rows a bin's selector is indexed
      # by are the rows of *this panel's* frame, because each panel draws its
      # own grob and gridSVG numbers the polygons within it from one. Filtering
      # a second way here would be a second chance for the two to disagree.
      built_data <- self$get_layer_built_data(built, panel_id)
      if (is.null(built_data)) {
        return(list(data = list(), order = integer(0)))
      }

      hexbin_lattice(built_data)
    },

    #' @description Name the three axes
    #'
    #'   The colour axis is the count of points that fell in the bin, which is
    #'   what \code{stat_binhex()} computes and what the fill encodes. Named
    #'   here rather than read from the legend title, which says "count" for
    #'   the default and would say \code{after_stat(density)} for a chart that
    #'   is still counting into the same cells.
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @return An axes payload with x, y and z
    extract_axes = function(plot, built = NULL) {
      labels <- if (!is.null(built)) built$plot$labels else plot$labels
      axis_label <- function(aes) {
        label <- labels[[aes]]
        if (is.null(label) || !is.character(label) || length(label) != 1L) {
          mapped <- plot$mapping[[aes]]
          if (is.null(mapped)) {
            return(aes)
          }
          return(rlang::as_label(mapped))
        }
        label
      }

      build_axes(x = axis_label("x"), y = axis_label("y"), z = "count")
    },

    #' @description Address each drawn hexagon by its own element
    #'
    #'   gridSVG exports the layer's single multi-polygon grob as one
    #'   \code{<polygon>} per hexagon, in built-data order, each carrying an id
    #'   of the form \code{<grob>.1.<n>}. So a bin is addressed by the built
    #'   row it came from, and the emitted list follows the regrouping rather
    #'   than the document.
    #'
    #'   The frontend withdraws highlighting outright unless the resolved
    #'   element count matches the bin count exactly, so a partial list is
    #'   worse than none -- an empty list is returned when the grob cannot be
    #'   found rather than a guess at its name.
    #' @param gt Gtable object
    #' @param plot The ggplot2 object, used to build a gtable when none is given
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @param order The built-data row behind each bin, in emission order
    #' @return A list of CSS selectors, one per bin
    generate_selectors = function(gt = NULL, plot = NULL, panel_ctx = NULL,
                                  order = integer(0)) {
      if (length(order) == 0) {
        return(list())
      }
      if (is.null(gt)) {
        if (is.null(plot)) {
          return(list())
        }
        gt <- ggplot2::ggplotGrob(plot)
      }

      panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
      if (is.null(panel_grob)) {
        return(list())
      }

      grob_name <- self$find_hex_polygon_name(panel_grob)
      if (is.null(grob_name)) {
        return(list())
      }

      lapply(order, function(index) {
        id <- paste0(grob_name, ".1.", index)
        paste0("polygon#", gsub("\\.", "\\\\.", id))
      })
    },

    #' @description Find the name of the grob holding the hexagons
    #'
    #'   \code{GeomHex} draws every hexagon in one \code{polygonGrob}, so there
    #'   is a single name to find rather than one per bin. Searched depth-first
    #'   because the layer's grobs sit inside a gTree of their own.
    #' @param grob The panel grob to search
    #' @return The grob name, or NULL when the layer drew nothing
    find_hex_polygon_name = function(grob) {
      found <- NULL
      walk <- function(node) {
        if (!is.null(found)) {
          return(invisible(NULL))
        }
        name <- node$name
        if (!is.null(name) && is.character(name) &&
          length(name) == 1L && grepl("^geom_hex\\.polygon", name)) {
          found <<- name
          return(invisible(NULL))
        }
        if (inherits(node, "gList")) {
          for (i in seq_along(node)) walk(node[[i]])
        }
        if (inherits(node, "gTree")) {
          for (i in seq_along(node$children)) walk(node$children[[i]])
        }
        invisible(NULL)
      }
      walk(grob)
      found
    }
  )
)
