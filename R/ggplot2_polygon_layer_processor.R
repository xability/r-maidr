#' Polygon Layer Processor
#'
#' @description
#' Reads `geom_polygon()` as the closed path it draws.
#'
#' A polygon is `geom_path()` with its ends joined and its interior filled.
#' `GeomPath` has been dispatched to `"line"` since before this file existed,
#' so reading a polygon the same way decides nothing new about what a series
#' of vertices means -- it makes two spellings of one mark behave alike, the
#' argument `GeomSpoke` was routed through `GeomSegment` on (#225).
#'
#' What it was costing until then is the whole chart. `"unknown"` is what
#' makes `has_unsupported_layers()` true and drops the plot to a static
#' image (#176). Measured on ggplot2 3.4.4, thirty points, `save_html()`:
#'
#' ```
#' geom_point()                     interactive SVG   52,708 bytes
#' geom_point() + geom_polygon()    base64 image      30,913 bytes
#' geom_polygon() alone             base64 image      18,353 bytes
#' ```
#'
#' Skipping it instead was declined in #225 and the reason is worth keeping
#' here: every geom skipped today carries no observations -- `geom_blank()`
#' draws nothing, a reference line is a constant, a text label repeats a
#' value already in the payload -- so skipping loses a reader nothing they
#' could have navigated. A polygon's vertices are rows the author supplied.
#' Skipping one that is the data would drop it silently, which is worse than
#' the honest picture, because the reader is not told anything is missing.
#'
#' ## The closing vertex is not emitted
#'
#' Four rows draw a quadrilateral with four corners and five edges. The
#' fifth edge is the closure, and it adds no observation -- which is
#' ggplot2's own reading as well: `GeomPolygon$draw_panel()` hands grid the
#' munched rows unchanged under a linear coord, and the drawn element holds
#' exactly as many points as the layer has rows. Straight off the exported
#' SVG for `x = c(1, 3, 3, 1)`, `y = c(1, 1, 3, 3)`:
#'
#' ```
#' <polygon points="49.84,53.12 171.93,53.12 171.93,265.22 49.84,265.22"/>
#' ```
#'
#' So a series and its drawn shape are the same length, in the same order,
#' and a reader who navigates to the end has been told every vertex once.
#'
#' ## Addressing
#'
#' Unlike a line, a polygon layer names its grob after its geom, so it needs
#' no draw-order search of anonymous `GRID.polyline.N` grobs. gridSVG turns
#' one grob into one element per **group**, which is the granularity the
#' multi-series trace wants:
#'
#' ```
#' <g id="geom_polygon.polygon.57.1">
#'   <polygon id="geom_polygon.polygon.57.1.1"/>   <- group 1
#'   <polygon id="geom_polygon.polygon.57.1.2"/>   <- group 2
#' ```
#'
#' `aes(subgroup =)` -- a shape with a hole in it -- is drawn as a
#' `pathgrob` rather than a `polygon`, and gridSVG still emits one `<path>`
#' per `pathId`, which is still the group. Measured on two groups of two
#' subgroups: `geom_polygon.pathgrob.42.1.1` and `...1.2`, each holding both
#' of its rings in one `d`. So both spellings address the same way and only
#' the element differs, which is why the search below matches either.
#'
#' @keywords internal
Ggplot2PolygonLayerProcessor <- R6::R6Class(
  "Ggplot2PolygonLayerProcessor",
  inherit = Ggplot2LineLayerProcessor,
  public = list(
    #' @description Process the polygon layer as a closed path
    #'
    #' The reading is the line processor's: one series per `group`, in the
    #' built data's row order, named from whatever aesthetic splits the
    #' layer. Only the type and the selectors are this class's own.
    #'
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return List with data, selectors, title, axes and type
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      result <- super$process(
        plot, layout, built, gt, grob_id, panel_id, panel_ctx
      )
      # Dispatched under its own name so that what it reads and how it
      # addresses its elements can both be its own; emitted as `line`
      # because that is the trace a closed path is. Same arrangement `rug`
      # uses to emit `point`.
      result$type <- "line"
      result
    },

    #' @description Resolve the aesthetic that splits this layer into series
    #'
    #' A line probes `colour` alone, because a line has no fill. A polygon
    #' has both, and `fill` is the one it is usually split by -- so `fill`
    #' is probed first, then the outline colour, then `group` itself.
    #'
    #' `group` is the addition, and it is worth its line. A polygon is drawn
    #' one shape per group, and `aes(group = g)` with nothing else mapped is
    #' the plainest way to write two shapes -- it is how ggplot2's own
    #' documentation writes them. Without it both series fall back to
    #' "Series 1" and "Series 2" while the chart's own data says "a" and
    #' "b". ggplot2 records the column under `labels$group` exactly as it
    #' records a legend title, so the z label comes out as "g" and a reader
    #' hears "g is a" rather than "Group is Series 1".
    #'
    #' @param plot The ggplot2 object
    #' @return list with `aes` (aesthetic spelling variants, or NULL when
    #'   nothing is mapped) and `column` (the mapped column name, or
    #'   "group" as a fallback)
    resolve_group_mapping = function(plot) {
      resolve_series_group_mapping(
        plot, self$layer_info$index, self$group_aes()
      )
    },

    #' @description Add the grouping column's name as the z axis label
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param data The extracted layer data
    #' @param axes Axes built so far
    #' @return The axes list, with z added when the layer is grouped
    attach_group_axis = function(plot, built, data, axes) {
      attach_series_group_axis(
        axes, plot, built, data,
        layer_index = self$get_layer_index(),
        aes_groups = self$group_aes()
      )
    },

    #' @description The aesthetics a polygon layer can be split by, in order
    #'
    #' @return List of aesthetic-name vectors, each holding the spelling
    #'   variants of one aesthetic
    group_aes = function() {
      list("fill", c("colour", "color"), "group")
    },

    #' @description Selectors for this layer's polygons, one per series
    #'
    #' Declines when the drawn shape count and the emitted series count
    #' disagree, which is what the line processor does and for the same
    #' reason: the frontend's multiline trace drops the whole layer's
    #' highlight unless `selectors.length === data.length`, so a mismatched
    #' list would outline the wrong shape rather than none.
    #'
    #' @param plot The ggplot2 object
    #' @param panel_grob The panel's grob tree
    #' @param n_series Number of series the layer emitted
    #' @return List of CSS selectors, or NULL
    curve_selectors = function(plot, panel_grob, n_series) {
      grob <- self$find_layer_polygon_grob(plot, panel_grob)
      if (is.null(grob)) {
        return(NULL)
      }
      if (!identical(
        as.integer(self$polygon_shape_count(grob)), as.integer(n_series)
      )) {
        return(NULL)
      }
      lapply(seq_len(n_series), function(i) {
        paste0("#", gsub("\\.", "\\\\.", paste0(grob$name, ".1.", i)))
      })
    },

    #' @description How many shapes one polygon grob draws
    #'
    #' `id` separates a `polygon` grob's locations into shapes; a `pathgrob`
    #' uses `id` for its subgroups and `pathId` for the group, so the group
    #' is what has to be counted there -- a two-group, two-subgroup layer
    #' carries `id = 1,1,1,1,2,2,2,2,1,...` and `pathId = 1,1,1,1,1,1,1,1,2,...`,
    #' and reading `id` would answer two for a chart drawing two paths of
    #' two rings each only by coincidence.
    #'
    #' There is no "it has no ids" case to answer for.
    #' `GeomPolygon$draw_panel()` always passes one -- `id = munched$group`
    #' for a polygon, `pathId = munched$group` for a path -- so a grob
    #' without one is not one of these, and `length(unique(NULL))` answering
    #' zero declines it, which is the right answer for a grob this should
    #' not be addressing.
    #'
    #' @param grob A `polygon` or `pathgrob` grob
    #' @return The number of shapes drawn
    polygon_shape_count = function(grob) {
      ids <- if (inherits(grob, "pathgrob")) grob$pathId else grob$id
      length(unique(ids))
    },

    #' @description The polygon grob ggplot2 drew for THIS layer
    #'
    #' @param plot The ggplot2 object
    #' @param panel_grob The panel's grob tree
    #' @param target Index of the layer to find; defaults to this one's
    #' @return The matching grob, or NULL
    find_layer_polygon_grob = function(plot, panel_grob, target = NULL) {
      if (is.null(target)) {
        target <- self$get_layer_index()
      }
      candidates <- self$layer_polygon_grobs(plot, panel_grob, target)
      position <- self$polygon_layer_position(plot, target)
      if (is.null(position) || position > length(candidates)) {
        return(NULL)
      }
      candidates[[position]]
    },

    #' @description Panel polygons that a polygon layer could have drawn
    #'
    #' The skip list is not defensive. `geom_boxplot()` draws each box's
    #' crossbar through `GeomPolygon`, so a boxplot contributes grobs named
    #' exactly like a polygon layer's own -- and they are drawn first.
    #' Measured on three boxes beside one polygon:
    #'
    #' ```
    #' geom_boxplot.gTree.30
    #'   geom_boxplot.gTree.10 -> geom_crossbar.gTree.9 -> geom_polygon.polygon.7
    #'   geom_boxplot.gTree.20 -> geom_crossbar.gTree.19 -> geom_polygon.polygon.17
    #'   geom_boxplot.gTree.28 -> geom_crossbar.gTree.27 -> geom_polygon.polygon.25
    #' geom_polygon.polygon.32                                  <- the layer's own
    #' ```
    #'
    #' Taking the first match would outline a box. Every one of those sits
    #' inside a tree named after the geom that owns it, so refusing to
    #' descend into another layer's tree leaves exactly the layer's own --
    #' which is how `layer_polyline_grobs()` scopes the same search for the
    #' geoms that draw anonymous polylines.
    #'
    #' @param plot The ggplot2 object
    #' @param panel_grob The panel's grob tree
    #' @param target Index of the layer whose polygons are wanted
    #' @return List of grobs in draw order
    layer_polygon_grobs = function(plot, panel_grob, target = NULL) {
      skip <- self$other_geom_grob_prefixes(plot, target)
      out <- list()
      collect <- function(grob) {
        name <- grob$name
        belongs_to_other_layer <- !is.null(name) && length(skip) > 0L &&
          any(startsWith(name, paste0(skip, ".")))
        if (belongs_to_other_layer) {
          return(invisible(NULL))
        }
        if (!is.null(name) &&
          grepl("^geom_polygon\\.(polygon|pathgrob)\\.\\d+$", name)) {
          out[[length(out) + 1L]] <<- grob
        }
        if (inherits(grob, "gTree")) {
          for (child in grob$children) collect(child)
        }
        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) collect(grob[[i]])
        }
        invisible(NULL)
      }
      collect(panel_grob)
      out
    },

    #' @description This layer's position among the plot's polygon layers
    #'
    #' Two `geom_polygon()` calls draw two grobs in layer order, so the
    #' second layer wants the second match.
    #'
    #' @param plot The ggplot2 object
    #' @param target Index of the layer of interest
    #' @return The 1-based position, or NULL when the layer is not one
    polygon_layer_position = function(plot, target) {
      position <- 0L
      for (i in seq_along(plot$layers)) {
        if (identical(class(plot$layers[[i]]$geom)[[1]], "GeomPolygon")) {
          position <- position + 1L
          if (i == target) {
            return(position)
          }
        }
      }
      NULL
    }
  )
)
