#' chartSeries TA Advisory Warning State
#'
#' Environment used to suppress repeat chartSeries `TA` advisory warnings
#' within a single session.
#'
#' @keywords internal
.maidr_chartseries_ta_warned <- new.env(parent = emptyenv())
.maidr_chartseries_ta_warned$value <- FALSE

#' Emit a one-time warning when quantmod::chartSeries() is called with a
#' non-NULL `TA` argument (e.g. `TA = "addVo()"`).
#'
#' The gridSVG export pipeline used to convert chartSeries' multi-panel
#' base graphics output into an accessible HTML SVG mis-handles the volume
#' sub-panel, producing rects with negative y coordinates that overlap the
#' date-label band. Because gridSVG is unmaintained, maidr falls back to
#' native (non-accessible) rendering for these calls and surfaces a
#' one-time advisory pointing users to the ggplot2 + tidyquant + patchwork
#' alternative which renders correctly via maidr's ggplot2 path.
#'
#' @return Invisibly NULL.
#' @keywords internal
warn_chartseries_ta_unsupported <- function() {
  if (isTRUE(.maidr_chartseries_ta_warned$value)) {
    return(invisible(NULL))
  }
  .maidr_chartseries_ta_warned$value <- TRUE
  rlang::warn(
    c(
      paste0(
        "quantmod::chartSeries() with a `TA` argument (e.g. ",
        "`TA = \"addVo()\"`) is not supported by maidr's accessible ",
        "HTML pipeline; the volume sub-panel does not export reliably ",
        "from the underlying gridSVG bridge."
      ),
      i = paste0(
        "Falling back to native (non-accessible) graphics for this plot."
      ),
      i = paste0(
        "For accessible price + volume charts use ggplot2 + ",
        "tidyquant::geom_candlestick() + patchwork instead."
      )
    ),
    class = "maidr_chartseries_ta_unsupported",
    .frequency = "once",
    .frequency_id = "maidr_chartseries_ta_unsupported"
  )
  invisible(NULL)
}

#' Does a Base R `type` argument request a stairstep?
#'
#' `graphics::plot()` and `graphics::lines()` draw stairsteps for
#' `type = "s"` (horizontal segment first) and `type = "S"` (vertical segment
#' first). The comparison is case-sensitive because those two letters mean
#' different things.
#'
#' @param plot_type The `type` argument recorded from the plot call (may be
#'   NULL when the caller did not pass one).
#' @return `TRUE` when `plot_type` is `"s"` or `"S"`, otherwise `FALSE`.
#' @keywords internal
is_step_plot_type <- function(plot_type) {
  if (is.null(plot_type) || length(plot_type) == 0) {
    return(FALSE)
  }
  as.character(plot_type)[1] %in% c("s", "S")
}

#' Whether a `mosaicplot()` call was handed a two-way table
#'
#' A `mosaic` layer has one category axis and one fill, so it can carry a
#' two-dimensional table and no more. `mosaicplot()` accepts deeper ones and
#' splits them recursively.
#'
#' The table itself is resolved by `recorded_two_way_table()`, which the
#' processor also reads, so dispatch and extraction cannot disagree about
#' which calls are readable.
#'
#' @param args The arguments recorded from the `mosaicplot()` call.
#' @return `TRUE` when the call's table has exactly two dimensions.
#' @keywords internal
is_two_way_table <- function(args) {
  !is.null(recorded_two_way_table(args))
}

#' Whether a `dotchart()` call draws more than one group
#'
#' `dotchart()` draws a group per matrix column, or per level of `groups`,
#' with a header in the left margin and every dot in one shared grob. The
#' grouping is what the chart is drawn to show and there is nothing in a
#' flat `dot` layer to carry it, so such a call is declined rather than
#' flattened.
#'
#' @param args The arguments recorded from the `dotchart()` call.
#' @return `TRUE` when the call draws groups, otherwise `FALSE`.
#' @keywords internal
is_grouped_dotchart <- function(args) {
  if (!is.null(args$groups)) {
    return(TRUE)
  }
  # `resolve_xy_args()` rather than `args$x`, which partial-matches `xlab`
  # and friends -- see #245.
  x <- resolve_xy_args(args)$x
  is.matrix(x) || is.data.frame(x)
}

#' Whether a Base R `type` argument draws spikes
#'
#' `type = "h"` draws a vertical line from the baseline to each value --
#' "histogram-like" in `plot()`'s own wording -- and joins nothing to
#' anything. Read as a `lollipop` layer, which the core builds on `BarTrace`:
#' one value per position, with no claim about the space between two of them.
#'
#' Case-sensitive, like the step test beside it: `plot()` has no `"H"`.
#'
#' @param plot_type The `type` argument recorded from the plot call (may be
#'   NULL when the caller did not pass one).
#' @return `TRUE` when `plot_type` is `"h"`, otherwise `FALSE`.
#' @keywords internal
is_spike_plot_type <- function(plot_type) {
  if (is.null(plot_type) || length(plot_type) == 0) {
    return(FALSE)
  }
  identical(as.character(plot_type)[1], "h")
}

#' Map a Base R `type` argument onto a MAIDR step direction
#'
#' `type = "s"` draws the horizontal segment first, which is MAIDR's `"hv"`;
#' `type = "S"` draws the vertical segment first, which is `"vh"`. Any other
#' value returns NULL so the caller can omit `stepDirection` rather than
#' assert a convention the call never asked for.
#'
#' @param plot_type The `type` argument recorded from the plot call.
#' @return `"hv"`, `"vh"`, or NULL.
#' @keywords internal
base_r_step_direction <- function(plot_type) {
  if (!is_step_plot_type(plot_type)) {
    return(NULL)
  }
  if (identical(as.character(plot_type)[1], "s")) "hv" else "vh"
}

#' Base R System Adapter
#'
#' @description
#' Adapter for the Base R plotting system. This adapter uses function patching
#' to intercept Base R plotting calls and detect plot types.
#'
#' @format An R6 class inheriting from SystemAdapter
#' @keywords internal
BaseRAdapter <- R6::R6Class(
  "BaseRAdapter",
  inherit = SystemAdapter,
  public = list(
    #' @description Initialize the Base R adapter
    initialize = function() {
      super$initialize("base_r")
    },

    #' @description Check if this adapter can handle a plot object
    #' @param plot_object The plot object to check (should be NULL for Base R)
    #' @return TRUE if Base R plotting is active, FALSE otherwise
    can_handle = function(plot_object) {
      active <- is_patching_active()
      device_id <- grDevices::dev.cur()
      has_calls <- has_device_calls(device_id)
      calls_count <- length(get_device_calls(device_id))
      can_handle_result <- active && has_calls
      can_handle_result
    },

    #' @description Detect the type of a single layer from Base R plot calls
    #' @param layer The plot call entry from our logger
    #' @param plot_object The parent plot object (NULL for Base R)
    #' @return String indicating the layer type (e.g., "bar", "dodged_bar",
    #'   "stacked_bar", "smooth", "line", "point")
    detect_layer_type = function(layer, plot_object = NULL) {
      if (is.null(layer)) {
        return("unknown")
      }

      function_name <- layer$function_name
      args <- layer$args

      # HIGH-level function detection
      layer_type <- switch(function_name,
        "barplot" = {
          if (self$is_dodged_barplot(args)) {
            "dodged_bar"
          } else if (self$is_normalized_barplot(args)) {
            "stacked_normalized_bar"
          } else if (self$is_stacked_barplot(args)) {
            "stacked_bar"
          } else {
            "bar"
          }
        },
        "plot" = {
          first_arg <- args[[1]]
          if (!is.null(first_arg) && inherits(first_arg, "density")) {
            "smooth"
          } else {
            # plot() default type is "p" (points/scatter)
            # plot(x, y) with two numeric vectors defaults to scatter
            #
            # `type = "b"` reads as points, not as a line. It draws the
            # segments with a gap at every symbol, so gridSVG exports them
            # under "brokenline" rather than the single "lines" polyline the
            # line selector addresses - the layer came out with NO selector
            # and highlighted nothing, while the points grob it also draws
            # resolves cleanly. The `curve` branch below already reached this
            # conclusion for the same draw types; the `plot` branch could not
            # act on it while a positionally supplied type never arrived here
            # at all (#98). `"o"` overplots symbols on an unbroken polyline,
            # so it keeps the line reading, exactly as `curve` does.
            #
            # `"c"` and `"h"` are left as they are: they export under names
            # the line selector cannot address either, but they draw no
            # symbols to fall back to, so there is nothing to point at until
            # a trace type exists for them. Their reading is unchanged from a
            # named `type =` today.
            #
            # `"s"` and `"S"` were in that list until a trace type did exist
            # for them. They now type as "step", and the step processor
            # overrides the grob search to the `-step-` / `-Step-` names
            # gridGraphics gives them, so they are addressable rather than
            # unpointable. Reaching here positionally is new, so
            # `plot(x, y, "s")` is described for the first time.
            #
            # `type = "n"` is the one that draws nothing at all: it sets up
            # the axes and plots no points and no lines, which is how a custom
            # chart is started before `segments`, `polygon` or `rect` add the
            # marks. The catch-all below claimed it as a line, so an empty
            # panel was announced as a full series of the values `plot()` was
            # handed and deliberately did not draw -- ten points to walk and
            # sonify, where a sighted reader sees nothing (#237).
            #
            # Worse than being unread, for the reason #572 gives about
            # `triplot`: the data is real, the axes are real, and the only
            # false thing is the claim that any of it was drawn. Declined, so
            # the figure falls back to a picture of the empty panel it is --
            # which is what the shapes drawn over it already get, since they
            # contribute no layer of their own.
            plot_type <- args$type
            if (is.character(plot_type) && identical(plot_type[1], "n")) {
              "unknown"
            } else if (is.null(plot_type) || plot_type[1] %in% c("p", "b")) {
              "point"
            } else if (is_spike_plot_type(plot_type)) {
              # type = "h" draws a vertical from the baseline to each value
              # and joins nothing to anything. The catch-all "line" below
              # claimed it, which is the reading a spike chart most needs not
              # to have: a line says the samples are joined and the space
              # between them can be interpolated (#239).
              "lollipop"
            } else if (is_step_plot_type(plot_type)) {
              # type = "s" / "S" draw stairsteps. This test must precede the
              # catch-all "line" below, which would otherwise claim them.
              "step"
            } else {
              "line"
            }
          }
        },
        # curve() draws the points it evaluates as a polyline, which is
        # what plot(x, y, type = "l") does, so it types as the same "line"
        # layer -- and the SVG export names that polyline
        # "graphics-plot-N-lines-1", the grob the line processor already
        # looks for.
        #
        # Only the polyline draw types qualify. type = "s"/"S"/"b"/"c"/"h"
        # /"p" export under grob names the line selector cannot address
        # ("step", "Step", "brokenline", "spike", "points"), so they keep
        # falling back to a static image rather than shipping data with
        # selectors that highlight nothing. type = "o" draws the same
        # polyline plus a points grob, so the line reading holds.
        #
        # curve(add = TRUE) is excluded for a different reason: `curve` is
        # a HIGH-level function, so it opens its own plot group, and a
        # single-panel figure exports only the FIRST group's grob. An
        # overlay typed as "line" would therefore emit data for a curve
        # that is absent from the exported SVG, with a selector pointing
        # at a grob that group never drew. Overlays stay on the static
        # fallback until they are grouped with the plot they add to.
        "curve" = {
          curve_type <- args[["type"]]
          overlays_existing <- "add" %in% names(args) &&
            !identical(args[["add"]], FALSE)
          draws_polyline <- is.null(curve_type) ||
            (is.character(curve_type) && curve_type[1] %in% c("l", "o"))
          if (overlays_existing || !draws_polyline) {
            "unknown"
          } else {
            "line"
          }
        },
        # A Cleveland dot plot: one value per category, marked on a guide
        # line, categories down the page. Read as `dot`, which the core
        # builds on its bar trace (#237).
        #
        # Only the one-value-per-category form. `dotchart()` also takes a
        # matrix, or a `groups` factor, and then draws every group's dots
        # into the *same* points grob with a header per group in the left
        # margin -- so a flat reading would hand the reader one run of dots
        # with no way to tell which group each belongs to, and the group
        # names silently dropped. Declined, which is where it already was.
        "dotchart" = {
          if (is_grouped_dotchart(args)) "unknown" else "dot"
        },
        # A two-way contingency table drawn as tiles, where the column
        # widths encode data as well as the tile heights. Read as `mosaic`,
        # which exists for exactly this shape; read as a stacked bar it
        # would lose the widths, and the widths are half the table (#242).
        #
        # Only a two-dimensional table. `mosaicplot()` accepts three and
        # more, splitting recursively, and a `mosaic` layer has one category
        # axis and one fill -- so a deeper table has nowhere to put its
        # later dimensions and is declined rather than flattened into a
        # cross-classification the chart does not claim.
        "mosaicplot" = {
          if (is_two_way_table(args)) "mosaic" else "unknown"
        },
        # A Cohen--Friendly association plot: the same two-way table, drawn
        # as one tile per cell whose signed height is that cell's Pearson
        # residual. Read as a `heat` -- a named grid of one number per cell,
        # navigated row then column, which is how a contingency table is
        # read. NOT as a `mosaic`, though the two look alike: a mosaic's
        # tiles are proportions of a whole and these are signed departures
        # from an expectation, which sum to nothing (#266).
        "assocplot" = {
          if (is_two_way_table(args)) "residual" else "unknown"
        },
        # A Q-Q plot: the scatter of one sample's quantiles against another
        # distribution's. Read as `point` -- it is a scatter, and the only
        # thing separating it from any other is that its coordinates are
        # *computed* rather than handed in, which is what
        # `BaseRQqLayerProcessor` exists for (#251).
        "qqnorm" = "qq",
        # `qqplot(conf.level = ...)` additionally draws a confidence band,
        # as a `polygon()` from inside `stats` that the wrapper never sees
        # and nothing in the payload could carry. Reading the points alone
        # would hand a reader a chart with a drawn region silently missing
        # from it, so the whole call is declined and keeps falling back to
        # a picture, which at least says what it is.
        #
        # The caller's own argument is the whole test, which reads "no band"
        # off the caller's *silence*. That is sound only while
        # `stats::qqplot`'s own default is NULL, and it is -- so rather than
        # consult `formals()` here, where a NULL default makes the extra
        # branch unobservable and untestable, the assumption is asserted
        # outright in `test-base-r-qq-plot.R`. A release that changed the
        # default fails that test rather than silently turning every plain
        # `qqplot()` into a chart with a drawn region missing from it.
        # Raised in review of #253.
        "qqplot" = {
          if (is.null(args[["conf.level"]])) "qq" else "unknown"
        },
        # A one-dimensional scatter: every observation as its own mark,
        # laid along a value axis at its group's position. Read as `point`,
        # one layer per group, which is what the drawing forces -- gridSVG
        # exports one `points` grob per group -- and what the same chart
        # already gets in py-maidr (#251).
        "stripchart" = "strip",
        # An `n x n` grid of scatters: every ordered pair of columns, the
        # column across against the column down. Read as a *figure* of
        # subplots rather than as one layer, which is the shape the same
        # chart already gets in py-maidr (#272).
        "pairs" = "pairs",
        # The same level curves `contour()` draws, with the bands between
        # them filled. Read as a contour, from `contourLines()` rather than
        # from the fill, so one chart's two spellings read alike (#251).
        "filled.contour" = "filled_contour",
        # A mosaic of two categorical variables: one column per level of x,
        # its width that level's share of all observations, split by y's
        # conditional proportions. Read as `mosaic`, which is the shape
        # `mosaicplot()` already gets (#251).
        "spineplot" = "spine",
        # The conditional distribution of a factor across a numeric x,
        # drawn as bands that fill the height and sum to 1 at every x. Read
        # as `stacked_normalized_area`, the shape `geom_area(position =
        # "fill")` already gets (#251).
        "cdplot" = "conditional_density",
        # The three correlogram entry points. Each draws one vertical spike
        # per lag, from the zero line to the correlation at that lag, and
        # joins nothing to anything -- the shape `type = "h"` already reads
        # as a `lollipop` for, and under the same `spike` grob name (#276).
        # They are recorded but were read as nothing, so the chart came out
        # as a picture.
        "acf" = "correlogram",
        "pacf" = "correlogram",
        "ccf" = "correlogram",
        "hist" = "hist",
        "boxplot" = "box",
        # `boxplot()`'s own drawing half, called directly by a caller who
        # already has the five-number summaries. It draws the same marks
        # `boxplot()` does -- the same grob names in the same order -- so it
        # is the same `box` layer, and the separate name only routes it to
        # the subclass that reads the summaries out of the call instead of
        # recomputing them from observations that are not there (#262).
        "bxp" = "box_stats",
        # vioplot::vioplot() -- read as the violin_box + violin_kde pair, the
        # same shape the ggplot2 adapter produces for geom_violin().
        "vioplot" = "violin",
        "pie" = "pie",
        "image" = "heat",
        "heatmap" = "heat",
        # Typed "contour" again, now that `BaseRContourLayerProcessor` exists
        # to read one (#218). It was "unknown" for a while, and the reason is
        # worth keeping: with no processor behind it, this line put the gap in
        # the *payload* rather than in the fallback. The layer came out typed
        # "unknown" -- which `unsupported_layer_flags` only looks for on
        # `layer$type`, so the static-image path never ran -- and the core's
        # trace factory ends with `throw new Error("Invalid trace type: ...")`,
        # so the figure never bound. An interactive shell answering no key,
        # and no picture either (#214).
        #
        # So this name and the factory's dispatch have to move together. The
        # registry in `base_r_processor_factory` is derived from that dispatch
        # (#200), which is what stops them drifting apart again.
        "contour" = "contour",
        "matplot" = "line",
        # The same set of lines, over cell means the call computes
        # rather than over a matrix the caller handed in. The separate
        # name routes it to the subclass that recomputes them (#278).
        "interaction.plot" = "interaction",
        # quantmod::chartSeries() candlestick path. The `type` argument
        # defaults to "auto"; we accept the call as candlestick only when
        # the user explicitly requests it (matching the MVP scope).
        # Other types (bars / line / matchsticks) are deferred.
        # Technical analysis overlays via the `TA` argument (e.g.
        # `addVo()`) are also unsupported: the gridSVG export pipeline
        # (chartSeries -> ggplotify::as.grob -> gridGraphics::grid.echo
        # -> gridSVG::grid.export) mis-handles the multi-panel volume
        # sub-plot, producing volume <rect>s with negative y coordinates
        # that spill into the date-label band. gridSVG is unmaintained
        # (last CRAN release 2017); a proper fix would require either
        # patching gridSVG or rewriting the export pipeline. We return
        # "unknown" (which triggers maidr's standard fallback to native
        # graphics) and emit a one-time warning steering users to the
        # working ggplot2 + tidyquant + patchwork path for accessible
        # price+volume charts.
        "chartSeries" = {
          ct <- args$type
          ta <- args$TA
          ta_in_args <- "TA" %in% names(args)
          x <- args[[1]]
          # quantmod::chartSeries() default `TA` auto-adds addVo() when
          # the input has a Volume column. Treat that implicit case the
          # same as an explicit TA: warn + fall back to native graphics.
          has_default_vo <- !ta_in_args &&
            !is.null(x) &&
            requireNamespace("quantmod", quietly = TRUE) &&
            tryCatch(isTRUE(quantmod::has.Vo(x)),
                     error = function(e) FALSE)
          ta_explicit_unsupported <- ta_in_args &&
            !is.null(ta) && !identical(ta, FALSE) &&
            !identical(ta, "") && !identical(ta, NA)
          if (is.null(ct) || !identical(as.character(ct)[1], "candlesticks")) {
            "unknown"
          } else if (ta_explicit_unsupported || has_default_vo) {
            warn_chartseries_ta_unsupported()
            "unknown"
          } else {
            "candlestick"
          }
        },
        NULL
      )

      if (!is.null(layer_type)) {
        return(layer_type)
      }

      # LOW-level function detection (NEW)
      layer_type <- switch(function_name,
        "lines" = {
          first_arg <- args[[1]]
          # lines() never inspected `type` before, so lines(x, y, type = "s")
          # was reported as a plain line. The wrapper captures named dots, so
          # the stairstep request is available here just as it is for plot().
          # Same ladder the `plot()` branch above runs, so an overlay drawn
          # with `type = "s"` or `type = "h"` reads as the shape it draws
          # rather than as a plain line.
          step_fallback <- if (is_step_plot_type(args$type)) {
            "step"
          } else if (is_spike_plot_type(args$type)) {
            "lollipop"
          } else {
            "line"
          }
          if (!is.null(first_arg)) {
            if (inherits(first_arg, "density")) {
              "smooth" # Existing: density curves
            } else if (inherits(first_arg, "loess")) {
              "smooth" # Loess objects (shouldn't happen directly, but check)
            } else if (inherits(first_arg, "smooth.spline")) {
              "smooth" # Smooth spline objects
            } else if (
              is.list(first_arg) &&
                all(c("x", "y") %in% names(first_arg)) &&
                length(args) == 1
            ) {
              # List with x,y and no other args - likely loess.smooth result
              "smooth"
            } else {
              step_fallback # Default: regular line, unless type = "s" / "S"
            }
          } else {
            step_fallback
          }
        },
        "points" = "point",
        "abline" = "line",
        # `qqline()` draws an `abline` from inside the `stats`
        # namespace, where the wrapper never sees it -- so it is
        # recorded under its own name and read as the reference line
        # it is, from its own arguments rather than the plot's (#252).
        "qqline" = "qqline",
        "polygon" = "unknown", # Decorative element, triggers fallback if present
        "unknown"
      )

      layer_type
    },

    #' @description Check if a barplot call represents a dodged bar plot
    #' @param args The arguments from the barplot call
    #' @return TRUE if this is a dodged bar plot, FALSE otherwise
    is_dodged_barplot = function(args) {
      height <- args[[1]]
      is_matrix <- is.matrix(height) || (is.array(height) && length(dim(height)) == 2)

      # For matrices, beside = TRUE creates dodged bars. Read the way
      # `barplot()` reads it -- `if (beside)` -- rather than passed through,
      # which returned the caller's own value and made this expression a
      # number rather than a logical (#256).
      beside_true <- recorded_flag(args, "beside")

      is_matrix && beside_true
    },

    #' @description Check if a barplot call represents a stacked bar plot
    #' @param args The arguments from the barplot call
    #' @return TRUE if this is a stacked bar plot, FALSE otherwise
    is_stacked_barplot = function(args) {
      height <- args[[1]]
      is_matrix <- is.matrix(height) || (is.array(height) && length(dim(height)) == 2)

      # For matrices, beside = FALSE creates stacked bars - and FALSE is
      # barplot()'s DEFAULT, so a matrix without an explicit `beside`
      # argument is also stacked
      beside_false <- !recorded_flag(args, "beside")

      is_matrix && beside_false
    },

    #' @description Check if a barplot call draws a 100% stacked bar
    #'
    #' Base R has no `position = "fill"` to read: `barplot()` takes no
    #' normalisation argument at all, and the idiomatic way to draw a 100%
    #' stacked bar is to normalise the matrix first, as
    #' `barplot(prop.table(m, 2))`. The only signal left is the drawn geometry.
    #'
    #' So this reads what the chart shows rather than guessing what the author
    #' meant, and the two are the same thing here: when every column sums to 1,
    #' every bar is drawn to a common full height and each segment is that
    #' category's share. A chart like that IS a 100% stacked bar whatever the
    #' numbers were before they reached `barplot()`.
    #'
    #' Deliberately narrow. It does not also accept columns summing to 100,
    #' because a matrix of raw counts can total 100 by coincidence and nothing
    #' about the drawing would distinguish that from percentages. And it needs
    #' two or more rows, because a single series stacked against nothing is not
    #' a stack.
    #'
    #' @param args The arguments from the barplot call
    #' @return TRUE if every column of the height matrix sums to 1
    is_normalized_barplot = function(args) {
      if (!self$is_stacked_barplot(args)) {
        return(FALSE)
      }

      height <- args[[1]]
      if (nrow(height) < 2) {
        return(FALSE)
      }

      sums <- colSums(height, na.rm = TRUE)
      if (length(sums) == 0 || !all(is.finite(sums))) {
        return(FALSE)
      }

      # `prop.table()` divides, so the columns land near 1 rather than on it.
      isTRUE(all.equal(
        unname(sums),
        rep(1, length(sums)),
        tolerance = 1e-8
      ))
    },

    #' @description Create an orchestrator for this system (Base R)
    #' @param plot_object The plot object to process (NULL for Base R)
    #' @return PlotOrchestrator instance
    create_orchestrator = function(plot_object = NULL) {
      if (!self$can_handle(plot_object)) {
        stop("Base R plotting system is not active or no plot calls recorded")
      }

      device_id <- grDevices::dev.cur()
      BaseRPlotOrchestrator$new(device_id = device_id)
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

    #' @description Check if plot has facets (Base R doesn't support facets)
    #' @param plot_object The plot object (ignored for Base R)
    #' @return FALSE (Base R doesn't support facets)
    has_facets = function(plot_object = NULL) {
      FALSE
    },

    #' @description Check if plot is a patchwork plot (Base R doesn't support patchwork)
    #' @param plot_object The plot object (ignored for Base R)
    #' @return FALSE (Base R doesn't support patchwork)
    is_patchwork = function(plot_object = NULL) {
      FALSE
    },

    #' @description Get recorded plot calls for processing
    #' @param device_id Graphics device ID (defaults to current device)
    #' @return List of recorded plot calls
    get_plot_calls = function(device_id = grDevices::dev.cur()) {
      get_device_calls(device_id)
    },

    #' @description Clear recorded plot calls (for cleanup)
    #' @param device_id Graphics device ID (defaults to current device)
    clear_plot_calls = function(device_id = grDevices::dev.cur()) {
      clear_device_storage(device_id)
    },

    #' @description Initialize function patching
    #' @return NULL (invisible)
    initialize_patching = function() {
      initialize_base_r_patching()
      invisible(NULL)
    },

    #' @description Restore original functions
    #' @return NULL (invisible)
    restore_functions = function() {
      restore_original_functions()
      invisible(NULL)
    }
  )
)
