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

      # An annotation is decoration whatever it is drawn with, so this is
      # asked before any geom branch: `annotate("rect")` would otherwise be
      # measured as a schedule and `annotate("segment")` claimed as one.
      #
      # Skipped rather than left "unknown", which is what makes
      # `has_unsupported_layers()` true and drops the *whole plot* to a static
      # image -- the same cost #176 measured for a reference line, and
      # `annotate("rect")` is at least as ordinary a thing to put on a chart.
      # A plot that is *nothing but* annotations still falls back, because it
      # then reads as no layers at all rather than because of a rule about
      # geoms.
      if (layer_is_annotation(layer)) {
        return("skip")
      }

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

      # `geom_segment()` and `geom_curve()` draw a span between two points.
      # When the two ends share a coordinate that span is an interval in a
      # lane -- a schedule, a range plot, a high-low chart -- which is the
      # gantt trace MAIDR has carried since xability/maidr#801. The four
      # columns `ggplot_build` computes (`x`, `xend`, `y`, `yend`) are the
      # interval and the lane exactly, with nothing inverted from a pixel.
      #
      # `geom_curve()` computes the same four columns and reads the same way:
      # the curvature is a drawing instruction that never becomes a position,
      # the conclusion xability/maidr#1094 reached for `Plot.link`'s `curve`
      # option. It was refused until #195, not on its reading but on its
      # export -- `gridSVG` rejects the vectorised `gp` a `curve` grob
      # carries, so claiming the layer turned a chart that rendered as a
      # picture into a `save_html()` that raised. `split_vectorised_curve_grobs()`
      # gives gridSVG one curve per row, which both fixes the export and is
      # what the per-interval selectors address.
      #
      # A layer whose segments share nothing is an edge in a node-link
      # diagram, and goes back to "unknown" -- which is what it returns today,
      # so a chart that is refused keeps exactly the static-image fallback it
      # already had. `segment_lane_axis()` is what asks, of the whole layer.
      # `geom_contour()` and `geom_density_2d()` draw a scalar field as curves
      # of constant value, and ggplot2 computes `level` as a **number** on
      # every row -- so the value is data rather than a fill colour, which is
      # what left the same chart unread in the Observable adapter
      # (xability/maidr#1084) and what makes it readable here.
      #
      # The filled forms are a different chart: they draw the bands *between*
      # levels, and their `level` is a factor of intervals rather than a
      # number. `GeomContourFilled` and `GeomDensity2dFilled` do not inherit
      # their line counterparts, so naming only the two is enough -- and
      # `contour_curves()` checks the frame as well, so a stat that ever
      # produced banded levels under a line geom is declined rather than read.
      if (geom_class %in% c("GeomContour", "GeomDensity2d")) {
        return("contour")
      }

      # `geom_rug()` marks one short tick per observation against the panel's
      # edge -- the raw data, which the density curve or histogram it usually
      # accompanies does not state. `GeomRug` is a direct `Geom` subclass, so
      # it matched no branch above and reached the unknown processor: a
      # rug-only chart emitted one empty layer and a rug beside a scatter
      # added an empty one to land on (#222).
      #
      # py-maidr has read the same chart as points since
      # xability/py-maidr#250, and the processor emits `point` to match. It is
      # dispatched under its own name because what it reads and how it
      # addresses its elements are both its own -- the arrangement `dotplot`
      # already uses to emit `hist`.
      if (geom_class == "GeomRug") {
        return("rug")
      }

      if (geom_class %in% c("GeomSegment", "GeomCurve")) {
        return(if (self$segments_span_lanes(layer, plot_object)) "gantt" else "unknown")
      }

      if (geom_class %in% c("GeomLine", "GeomPath", "GeomMA")) {
        return("line")
      }
      # `GeomFunction` *is* a `GeomPath`, but the branch above matches the
      # first class name and so misses the subclass -- which is why the chart
      # fell through to the static-image fallback entirely (#202). It reads as
      # `smooth` rather than `line` for the reason `StatDensity` does: the
      # curve is sampled from a function at `n` renderer-chosen points, so
      # there are no observations to announce and the sample count is a
      # drawing parameter.
      if (geom_class == "GeomFunction" || stat_class == "StatFunction") {
        return("smooth")
      }
      if (geom_class == "GeomSmooth" || stat_class == "StatDensity") {
        return("smooth")
      }

      # A Wilkinson dot plot is a histogram drawn one dot per observation,
      # and `GeomDotplot` is a direct `Geom` subclass rather than a relative
      # of anything already handled -- the same shape of miss `GeomRaster`
      # was (#193). Its own processor emits `hist`.
      if (geom_class == "GeomDotplot") {
        return("dotplot")
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
      if (geom_class %in% c("GeomTile", "GeomBin2d", "GeomRaster")) {
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

      # `geom_label()` is `geom_text()` with a rounded rectangle behind it --
      # the same annotation, drawn twice over. But `GeomLabel` is a *sibling*
      # of `GeomText` rather than a subclass, both direct `Geom` children, so
      # matching the one name missed the other entirely and left it "unknown".
      # Measured on ggplot2 3.4.4 with `save_html()`, the same three-bar chart
      # in each row:
      #
      #     geom_col()                                interactive   39,116 bytes
      #     geom_col() + geom_text(aes(label = v))    interactive   41,339 bytes
      #     geom_col() + geom_label(aes(label = v))   base64 image  17,220 bytes
      #
      # Which of the two spellings the author reached for decided whether the
      # chart kept any interactivity at all (#211). Whether either should be
      # *read* -- as the JS core now reads a standalone `Plot.text`
      # (xability/maidr#1106) -- is a separate question; what this settles is
      # that they cost the same.
      if (geom_class %in% c("GeomText", "GeomLabel")) {
        return("skip")
      }

      # `geom_blank()` draws nothing at all. It exists to force a scale limit
      # -- `geom_blank(aes(y = 0))` to include zero, `geom_blank(data = ...)`
      # to give facets a shared range -- so it is added to charts that are
      # otherwise entirely readable, and left "unknown" it took every one of
      # them down to a picture: 39,116 bytes interactive against 13,380 as a
      # base64 image, measured the same way (#211). There is no reading
      # question in a layer with no marks.
      if (geom_class == "GeomBlank") {
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
    },

    #' @description Check whether a segment layer draws intervals in lanes
    #'
    #' Asked of the built data for the reason \code{ribbon_is_area()} is: a
    #' mapping expression cannot say whether the two ends of a segment agree,
    #' and by build time ggplot2 has resolved every spelling of the lane -- a
    #' factor, a character column, a repeated constant -- to the position it
    #' drew at.
    #'
    #' The whole layer is asked at once rather than each row, which is the
    #' rule xability/maidr#1100 settled for the same reading: one
    #' \code{geom_segment()} call can hold spans and edges together, and
    #' reading three spans out of four segments would announce a gantt quietly
    #' missing a quarter of its chart.
    #'
    #' @param layer The layer being classified
    #' @param plot_object The ggplot2 plot object
    #' @return TRUE when the layer's segments lay intervals in lanes
    segments_span_lanes = function(layer, plot_object) {
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

      !is.null(segment_lane_axis(built$data[[index]]))
    }
  )
)


#' Whether a layer was drawn by \code{annotate()} rather than by a geom
#'
#' \code{annotate()} is ggplot2's word for decoration: a highlighted region, a
#' label, an arrow pointing at something. Whatever geom it happens to use, the
#' function is the author saying "this is not data".
#'
#' ggplot2 records which function built each layer, so this is exact rather
#' than a guess about geometry. Measured on ggplot2 3.4.4, \code{layer$constructor}
#' holds the matched call and its head is the function name:
#'
#' \preformatted{
#' geom_rect(aes(...))                       -> geom_rect
#' annotate("rect", xmin = 2, xmax = 3, ...) -> annotate
#' annotate("text", x = 2, y = 3, ...)       -> annotate
#' }
#'
#' It survives disguise, which is what makes it better than the shape-based
#' rules considered in #197. \code{annotate()} sets \code{inherit.aes = FALSE}
#' and \code{show.legend = FALSE}, so those two look like a signature -- but a
#' \code{geom_rect()} written with both still reports \code{geom_rect}, and a
#' rule keyed on them would call that user's data decoration.
#'
#' Deliberately not a rule about *what* an annotation may draw. The whole point
#' of asking the constructor is that the answer does not depend on the mark:
#' \code{annotate("segment")} is an arrow, not a schedule, and a geometry test
#' would have to claim or refuse it on its coordinates.
#'
#' A layer with no \code{constructor} -- a ggplot2 that stopped recording it,
#' or a layer built by hand -- answers FALSE and keeps whatever reading it had.
#'
#' @param layer A ggplot2 layer object
#' @return TRUE when \code{annotate()} built the layer
#' @keywords internal
layer_is_annotation <- function(layer) {
  if (is.null(layer)) {
    return(FALSE)
  }
  constructor <- layer$constructor
  if (is.null(constructor) || !is.call(constructor)) {
    return(FALSE)
  }
  head <- tryCatch(as.character(constructor[[1]]), error = function(e) character(0))
  # `ggplot2::annotate(...)` heads as c("::", "ggplot2", "annotate"), so the
  # test is on membership rather than on the whole vector being one name.
  isTRUE("annotate" %in% head)
}
