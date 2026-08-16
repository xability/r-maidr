#' ggplot2 System Adapter
#'
#' @description
#' Adapter for the ggplot2 plotting system. This adapter wraps the existing
#' ggplot2 functionality to work with the new extensible architecture.
#'
#' @format An R6 class inheriting from SystemAdapter
#' @keywords internal

Ggplot2Adapter <- R6::R6Class(
  "Ggplot2Adapter",
  inherit = SystemAdapter,
  public = list(
    #' @description Initialize the ggplot2 adapter
    initialize = function() {
      super$initialize("ggplot2")
    },

    #' @description Check if this adapter can handle a plot object
    #' @param plot_object The plot object to check
    #' @return TRUE if this adapter can handle the object, FALSE otherwise
    can_handle = function(plot_object) {
      inherits(plot_object, "ggplot")
    },

    #' @description Detect the type of a single layer
    #' @param layer The ggplot2 layer object to analyze
    #' @param plot_object The parent plot object (for context)
    #' @return String indicating the layer type (e.g., "bar", "line", "point")
    detect_layer_type = function(layer, plot_object) {
      if (is.null(layer)) {
        return("unknown")
      }

      geom_class <- class(layer$geom)[1]
      stat_class <- class(layer$stat)[1]
      position_class <- class(layer$position)[1]

      # geom_step() draws a stairstep: the value is piecewise constant, held
      # across an interval and then jumped, rather than interpolated between
      # samples the way a line implies. GeomStep *inherits* GeomPath, so this
      # branch must come before the line branch below; and the comparison must
      # stay on class(...)[1] (an inherits() test would swallow step into
      # "line" and silently mis-describe the data).
      #
      # GeomStep is also the default geom of `stat_ecdf()`. That was declined
      # at first, for two reasons that both reproduce: StatEcdf returns its
      # rows in input order (GeomStep only sorts them later, inside
      # draw_panel) and pads them with -Inf / Inf, so the rows as built
      # neither match the drawn polyline nor carry usable x values. Measured
      # on n = 20: 22 rows, two of them infinite, `is.unsorted(x)` TRUE.
      #
      # Both are now undone by `Ggplot2StepLayerProcessor$in_drawn_order()`
      # before anything reads the frame, so an ECDF is claimed as well (#168).
      # Still only these two stats: a step layer drawn on some other computed
      # stat keeps returning "unknown" and so keeps the static-image fallback
      # it had before step support existed.
      if (geom_class == "GeomStep" &&
        stat_class %in% c("StatIdentity", "StatEcdf")) {
        return("step")
      }

      # GeomMA comes from tidyquant::geom_ma() and inherits from GeomLine.
      # We treat it as a regular line layer so moving averages overlaid on
      # a candlestick chart are detected and rendered alongside the candles.
      # GeomArea inherits GeomRibbon, which inherits GeomPath -- so this must
      # come before the line branch, and must stay a class(...)[1] comparison
      # rather than an inherits() test, or an area layer would be swallowed as
      # a line and announce its cumulative band tops as values.
      # Only an identity-ish stat is claimed. `geom_area()` defaults to
      # StatAlign, but the geom is also how a filled density curve is drawn --
      # `geom_area(stat = "density")` is a smooth, and its rows are a computed
      # curve rather than the observations an area chart carries. Same rule
      # GeomStep follows above, and for the same reason.
      if (geom_class == "GeomArea" &&
        stat_class %in% c("StatAlign", "StatIdentity")) {
        if (identical(position_class, "PositionFill")) {
          return("stacked_normalized_area")
        }
        # Whether the bands stack is not knowable from the position alone: a
        # single-series chart is drawn with PositionStack too and has nothing
        # stacked on it. The processor decides from the series it emits, and
        # both types route to it.
        return("area")
      }

      if (geom_class %in% c("GeomLine", "GeomPath", "GeomMA")) {
        return("line")
      }
      if (geom_class == "GeomSmooth" || stat_class == "StatDensity") {
        return("smooth")
      }

      if (geom_class %in% c("GeomBar", "GeomCol")) {
        if (stat_class == "StatBin") {
          return("hist")
        }

        # A bar layer drawn in polar coordinates with theta on y is the
        # idiomatic ggplot2 pie: the stack's segments wrap into wedges. It
        # must be caught before the position checks, which would otherwise
        # claim the very same layer as a stacked bar. A layer that spreads
        # across several x positions is a multi-ring bullseye instead, and
        # falls through to those very checks.
        if (self$is_pie_coord(plot_object, layer)) {
          return("pie")
        }

        if (position_class %in% c("PositionDodge", "PositionDodge2")) {
          return("dodged_bar")
        }

        if (position_class %in% c("PositionStack", "PositionFill")) {
          layer_mapping <- layer$mapping
          plot_mapping <- plot_object$mapping
          has_fill <- (!is.null(layer_mapping) && !is.null(layer_mapping$fill)) ||
            (!is.null(plot_mapping) && !is.null(plot_mapping$fill))
          if (has_fill) {
            # position = "fill" rescales every category to a common height, so
            # a segment's value is its share of that category and every bar
            # totals 1 by construction. Reading it as a plain stacked bar
            # announces those shares as if they were counts and implies the
            # categories have equal totals, which is the one thing a filled
            # bar is drawn to deny. maidr.js has carried the distinct type
            # since SegmentedTrace began serving NORMALIZED alongside STACKED.
            if (position_class == "PositionFill") {
              return("stacked_normalized_bar")
            }
            return("stacked_bar")
          }
        }

        return("bar")
      }

      # ggplot2 4.0 gave `geom_bin_2d()` a geom of its own, GeomBin2d, where
      # 3.x drew it with a plain GeomTile. It is the same tile grid and still
      # a heatmap, so both names land here. Matched by name rather than by
      # inherits(), to match every other branch in this function and because
      # the symbol does not exist on 3.x. The same release left
      # `stat_summary_2d()` on GeomTile, so nothing else moves with it.
      if (geom_class %in% c("GeomTile", "GeomBin2d")) {
        return("heat")
      }

      # `geom_hex()` bins into hexagons rather than rectangles. That is a
      # lattice of counted cells and so nearly a heatmap, but the rows are
      # offset by half a cell -- which is what lets hexagons tessellate, and
      # what stops a column index from being a position. Reading it as `heat`
      # would navigate and would put every bin past the first row on the
      # wrong x, so it is a type of its own.
      if (geom_class == "GeomHex") {
        return("hexbin")
      }

      if (geom_class == "GeomPoint") {
        return("point")
      }

      if (geom_class == "GeomBoxplot") {
        return("box")
      }

      if (geom_class == "GeomViolin") {
        return("violin")
      }

      # tidyquant::geom_candlestick() expands to two layers:
      #   - GeomLinerangeBC / StatLinerangeBC : the high-low wicks
      #   - GeomRectCS      / StatRectCS      : the open-close bodies
      # The wick layer is folded into the candlestick layer, so we tag it
      # as "skip" and let the body layer's processor reach back into the
      # wick grobs to build wick selectors.
      if (geom_class == "GeomLinerangeBC" || stat_class == "StatLinerangeBC") {
        return("skip")
      }
      if (geom_class == "GeomRectCS" || stat_class == "StatRectCS") {
        return("candlestick")
      }

      # ggplot2's uncertainty geoms. They all compute the same interval
      # aesthetics (ymin/ymax, or xmin/xmax when horizontal), so one processor
      # reads every one of them.
      #
      # GeomCrossbar and GeomPointrange do NOT inherit GeomErrorbar, and
      # GeomErrorbarh is its own class rather than a flipped GeomErrorbar, so
      # this has to be a membership test rather than an inherits() check.
      if (geom_class %in% c(
        "GeomErrorbar", "GeomErrorbarh", "GeomLinerange",
        "GeomPointrange", "GeomCrossbar"
      )) {
        return("error_bar")
      }

      # A bare `geom_ribbon()` is the other way to draw a confidence band, and
      # the one `geom_smooth(se = TRUE)` produces when a user assembles the
      # two halves by hand. It is not automatically an interval though:
      # `geom_ribbon(aes(ymin = 0, ymax = y))` is an area chart, and reading
      # that as an uncertainty would announce the whole magnitude as a bound.
      #
      # The baseline is what separates them, which is the same rule the Python
      # binding draws for `fill_between`: filling from zero to one curve is an
      # area, and anything else is the gap between two curves. Measured on a
      # pair of ribbons -- `aes(ymin = lo, ymax = hi)` gives non-zero `ymin`,
      # `aes(ymin = 0, ymax = y)` gives `ymin` identically zero.
      #
      # `class(...)[1]` rather than `inherits()`, because `GeomArea` inherits
      # `GeomRibbon`: an area layer must keep reaching its own branch above.
      if (geom_class == "GeomRibbon") {
        # A zero-baseline ribbon measures a height from a baseline, which is
        # what the area processor reads; anything else is the gap between two
        # curves, which is an interval.
        return(if (self$ribbon_is_area(layer, plot_object)) "area" else "error_bar")
      }

      if (geom_class == "GeomText") {
        return("skip")
      }

      # A reference line is decoration rather than data: a target, a control
      # limit, last year's median, a significance cutoff. It carries no
      # observations, and the grammar has no annotation shape to put it in.
      #
      # Skipped rather than left "unknown", because "unknown" is what makes
      # `has_unsupported_layers()` true and drops the *whole plot* to a static
      # image. Measured with `save_html()`:
      #
      #     geom_boxplot()                     interactive SVG   44,353 bytes
      #     geom_boxplot() + geom_hline()      base64 image      14,680 bytes
      #
      # A supported chart lost every bit of its interactivity to one
      # annotation, and a threshold line is among the most ordinary things to
      # draw on one (#176).
      #
      # Skipping rather than reading it is the same answer the Python binding
      # reached in xability/py-maidr#434, and for the stronger of the two
      # reasons: an `axhline` there announced its endpoints as 0 and 1,
      # because a blended transform puts its coordinates in axes-fraction
      # space rather than data space. Read as a line layer this is not a
      # partial reading, it is a confident reading of a series that is not
      # there. Announcing *that* a threshold is drawn, and where, is worth
      # doing -- but it needs a grammar shape for annotations, and is not a
      # reason to keep costing a chart everything in the meantime.
      if (geom_class %in% c("GeomHline", "GeomVline", "GeomAbline")) {
        return("skip")
      }

      "unknown"
    },

    #' @description Check if a bar layer is drawn as pie wedges
    #'
    #' \code{coord_radial()} produces a CoordRadial that does NOT inherit
    #' CoordPolar, so both class names have to be tested. \code{theta} decides
    #' what the angle encodes: only \code{theta = "y"} maps a bar's height
    #' onto the angle, which is a pie. \code{theta = "x"} keeps the height on
    #' the radius, which is a coxcomb/rose - still a bar chart, just bent.
    #'
    #' The coordinate system alone is not enough: a polar bar layer is a pie
    #' only when it draws ONE ring. \code{geom_col(aes(x = category))} under
    #' \code{coord_polar("y")} draws one concentric ring per x category - a
    #' bullseye - and a pie payload has no room for that second dimension, so
    #' such a layer keeps the bar classification it has always had.
    #'
    #' @param plot_object The ggplot2 plot object
    #' @param layer The layer being classified, or NULL for the plot's first
    #' @return TRUE when the layer is drawn as a pie, FALSE otherwise
    is_pie_coord = function(plot_object, layer = NULL) {
      if (is.null(plot_object)) {
        return(FALSE)
      }

      coord <- plot_object$coordinates
      if (!inherits(coord, c("CoordPolar", "CoordRadial"))) {
        return(FALSE)
      }

      if (!identical(coord$theta, "y")) {
        return(FALSE)
      }

      self$draws_single_ring(plot_object, layer)
    },

    #' @description Check if a layer occupies a single position on x
    #'
    #' The ring count has to come off the BUILT data: a mapping expression
    #' cannot say how many levels it has, and by build time ggplot2 has
    #' already resolved every constant form - the literal \code{""}, a
    #' one-level factor, a column holding one repeated value - to the same
    #' single x position. Each facet panel is its own pie, so constancy is
    #' asked of each panel separately. A build that fails answers FALSE,
    #' leaving the layer classified the way it was before pie support.
    #'
    #' @param plot_object The ggplot2 plot object
    #' @param layer The layer being classified, or NULL for the plot's first
    #' @return TRUE when no panel holds more than one x position
    draws_single_ring = function(plot_object, layer = NULL) {
      layer_index <- self$find_layer_index(plot_object, layer)
      if (is.null(layer_index)) {
        return(FALSE)
      }

      built <- tryCatch(
        ggplot2::ggplot_build(plot_object),
        error = function(e) NULL
      )
      if (is.null(built) || length(built$data) < layer_index) {
        return(FALSE)
      }

      built_data <- built$data[[layer_index]]
      if (is.null(built_data$x)) {
        return(TRUE)
      }

      panels <- if (is.null(built_data$PANEL)) {
        rep(1L, length(built_data$x))
      } else {
        built_data$PANEL
      }

      all(vapply(
        split(built_data$x, panels),
        function(x) length(unique(x[!is.na(x)])) <= 1L,
        logical(1)
      ))
    },

    #' @description Locate a layer among its plot's layers
    #' @param plot_object The ggplot2 plot object
    #' @param layer The layer to locate, or NULL for the plot's first
    #' @return Integer index into the plot's layers, or NULL when absent
    find_layer_index = function(plot_object, layer = NULL) {
      layers <- plot_object$layers
      if (length(layers) == 0) {
        return(NULL)
      }

      if (is.null(layer)) {
        return(1L)
      }

      for (i in seq_along(layers)) {
        if (identical(layers[[i]], layer)) {
          return(i)
        }
      }

      NULL
    },

    #' @description Create an orchestrator for this system (ggplot2)
    #' @param plot_object The ggplot2 plot object to process
    #' @return PlotOrchestrator instance
    create_orchestrator = function(plot_object) {
      if (!self$can_handle(plot_object)) {
        stop("Plot object is not a ggplot2 object")
      }

      # Use the existing PlotOrchestrator for ggplot2
      Ggplot2PlotOrchestrator$new(plot_object)
    },

    #' @description Get the system name
    #' @return System name string
    get_system_name = function() {
      self$system_name
    },

    #' @description Get a reference to this adapter (for use by orchestrator)
    #' @return Self reference
    get_adapter = function() {
      self
    },

    #' @description Check if plot has facets
    #' @param plot_object The ggplot2 plot object
    #' @return TRUE if plot has facets, FALSE otherwise
    has_facets = function(plot_object) {
      if (!self$can_handle(plot_object)) {
        return(FALSE)
      }

      facet_class <- class(plot_object$facet)[1]
      facet_class != "FacetNull"
    },

    #' @description Check if plot is a patchwork plot
    #' @param plot_object The ggplot2 plot object
    #' @return TRUE if plot is patchwork, FALSE otherwise
    is_patchwork = function(plot_object) {
      inherits(plot_object, "patchwork") ||
        !is.null(attr(plot_object, "patchwork"))
    },

    #' @description Whether a ribbon fills from a baseline rather than
    #' spanning two curves.
    #'
    #' `geom_ribbon(aes(ymin = 0, ymax = y))` is an area chart: the magnitude
    #' is the height of the fill, measured from a baseline the reader can
    #' assume. `geom_ribbon(aes(ymin = lo, ymax = hi))` draws the *gap*, and
    #' its content is the distance between two edges rather than the height of
    #' either -- read as an area it would announce `hi` as a magnitude and drop
    #' `lo` entirely.
    #'
    #' The same distinction the Python binding draws for `fill_between()`, and
    #' drawn the same way: only an identically-zero lower edge is an area.
    #'
    #' Reads the built data rather than the mapping, because `ymin` may be a
    #' constant, a column, or a computed aesthetic, and only the built frame
    #' has resolved which. A layer that cannot be built is treated as a band,
    #' which is the reading that loses nothing: an area announced as an
    #' interval still carries both edges.
    #'
    #' @param layer The ggplot2 layer
    #' @param plot_object The parent plot object
    #' @return TRUE when the ribbon is an area chart
    ribbon_is_area = function(layer, plot_object) {
      built <- tryCatch(
        ggplot2::ggplot_build(plot_object),
        error = function(e) NULL
      )
      if (is.null(built)) {
        return(FALSE)
      }

      index <- self$find_layer_index(plot_object, layer)
      if (is.null(index) || index < 1L || index > length(built$data)) {
        return(FALSE)
      }

      rows <- built$data[[index]]
      if (is.null(rows) || nrow(rows) == 0L || !"ymin" %in% names(rows)) {
        return(FALSE)
      }

      lower <- rows$ymin[is.finite(rows$ymin)]
      length(lower) > 0L && all(lower == 0)
    }
  )
)
