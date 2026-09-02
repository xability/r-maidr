#' Base R Violin Layer Processor
#'
#' @description
#' Reads a `vioplot::vioplot()` call as the `violin_box` + `violin_kde` layer
#' pair, matching what the ggplot2 adapter produces for `geom_violin()`. Which
#' plotting system a user chose should not decide whether their chart is
#' accessible.
#'
#' `vioplot()` returns its box summary but not the density curve it drew, so
#' both are recovered by replaying the call vioplot makes internally --- see
#' [compute_vioplot_stats()], which records why that is a transcription rather
#' than an approximation.
#'
#' @keywords internal
NULL

#' Grobs vioplot draws, one of each per violin
#'
#' Measured by echoing a two-group call through `gridGraphics::grid.echo()`:
#'
#' ```
#' graphics-plot-1-box-1      polygon  n=4     <- the plot frame, NOT a violin
#' graphics-plot-1-polygon-1  polygon  n=200   <- violin body
#' graphics-plot-1-lines-1    lines    n=2     <- whisker, lower to upper
#' graphics-plot-1-rect-1     rect     n=1     <- the quartile box
#' graphics-plot-1-points-1   points   n=1     <- the median dot
#' ```
#'
#' The body carries exactly twice the evaluation points `sm.density` returns,
#' mirrored about the category position, which is what confirms the replayed
#' curve is the drawn one.
#'
#' The patterns below are anchored, which is defensive rather than a fix for
#' anything observed. Measured, the two things it is tempting to credit it with
#' are not true: `graphics-plot-11-polygon-1` is excluded by the `-` delimiter
#' whether the pattern is anchored or not, and `graphics-plot-1-box-1` -- the
#' panel frame, which *is* a polygon grob -- never enters this search because
#' it is not named `polygon`. What the trailing `$` genuinely excludes is a
#' longer name beginning the same way, such as `-polygon-1-extra`; gridSVG
#' emits none today, so this keeps a name it does not own from being collected
#' if that ever changes.
#'
#' @keywords internal
.maidr_vioplot_grob_kinds <- c(
  body = "polygon",
  whisker = "lines",
  quartiles = "rect",
  median = "points"
)

#' Build the anchored grob-name pattern for one kind
#' @keywords internal
vioplot_grob_pattern <- function(plot_index, kind) {
  paste0("^graphics-plot-", plot_index, "-", kind, "-[0-9]+$")
}

#' Turn a grob name into the selector gridSVG exports it under
#'
#' gridSVG appends `.1` to each grob id, and the existing base R processors
#' address elements with the `[id^=...]` prefix form.
#'
#' @keywords internal
vioplot_grob_selector <- function(element, id) {
  paste0(element, "[id^='", id, ".1']")
}

BaseRViolinLayerProcessor <- R6::R6Class(
  "BaseRViolinLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Read a recorded `vioplot()` call as two maidr layers
    #' @param plot Unused; present for the processor interface.
    #' @param layout Unused; present for the processor interface.
    #' @param built Unused; present for the processor interface.
    #' @param gt The grob tree of the rendered plot.
    #' @param layer_info The recorded plot call and its metadata.
    #' @return A multi-layer result, or `NULL` when nothing can be read.
    process = function(plot, layout, built = NULL, gt = NULL, layer_info = NULL) {
      info <- if (!is.null(layer_info)) layer_info else self$layer_info
      violins <- self$extract_violins(info)
      if (!length(violins)) {
        return(NULL)
      }

      orientation <- self$determine_orientation(info)
      axes <- self$extract_axis_titles(info)
      title <- self$extract_main_title(info)
      plot_index <- self$plot_index(info)

      # gridSVG applies a scale(1, -1) Y-flip for vertical plots, which inverts
      # the top and bottom edges of the quartile box. The frontend swaps them
      # back when told to, the same way the base R box plot does it.
      iqr_direction <- if (orientation == "vert") "reverse" else "forward"

      box_layer <- list(
        data = self$build_box_data(violins),
        selectors = self$build_box_selectors(violins, gt, plot_index),
        axes = axes,
        title = title,
        orientation = orientation,
        type = "violin_box",
        violinOptions = list(
          showMedian = TRUE,
          showMean = FALSE,
          showExtrema = TRUE
        ),
        domMapping = list(iqrDirection = iqr_direction)
      )

      kde_layer <- list(
        data = self$build_kde_data(violins),
        selectors = self$build_kde_selectors(violins, gt, plot_index),
        axes = axes,
        title = title,
        orientation = orientation,
        type = "violin_kde"
      )

      list(
        multi_layer = TRUE,
        layers = list(box_layer, kde_layer)
      )
    },

    #' @description The recorded call's violins, each with its statistics
    #' @param layer_info The recorded plot call and its metadata.
    #' @return A list of `list(label =, stats =)`, one per drawn violin.
    extract_violins = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(list())
      }
      args <- layer_info$plot_call$args

      # A formula call names its groups through an environment this processor
      # no longer has, so reconstructing them would be guesswork. Declining
      # leaves the chart on maidr's static fallback, which says nothing rather
      # than saying something invented.
      if (any(vapply(args, inherits, logical(1), "formula"))) {
        return(list())
      }

      samples <- extract_vioplot_samples(args)
      if (!length(samples)) {
        return(list())
      }

      # Carried through from the call rather than defaulted: a caller-supplied
      # bandwidth goes straight to `sm.density`, so ignoring it would announce
      # a smoother or rougher curve than the one drawn, and `range` decides
      # where the whiskers stop.
      h <- args[["h"]]
      reach <- if (!is.null(args[["range"]])) {
        args[["range"]]
      } else {
        .maidr_vioplot_default_range
      }

      violins <- list()
      for (label in names(samples)) {
        stats_i <- compute_vioplot_stats(samples[[label]], h = h, range = reach)
        # A sample with no spread has no distribution to describe. vioplot
        # draws a degenerate mark for it; announcing a curve there would claim
        # a spread the chart does not show.
        if (is.null(stats_i)) {
          next
        }
        violins[[length(violins) + 1L]] <- list(label = label, stats = stats_i)
      }

      violins
    },

    #' @description One box summary per violin
    #' @param violins As returned by `extract_violins()`.
    #' @return A list of box points.
    build_box_data = function(violins) {
      lapply(violins, function(v) {
        list(
          z = v$label,
          # vioplot draws no outliers -- the curve beside the box already
          # covers the tails -- so separating points off would announce a
          # distinction the chart does not make.
          lowerOutliers = list(),
          min = v$stats$min,
          q1 = v$stats$q1,
          q2 = v$stats$median,
          q3 = v$stats$q3,
          max = v$stats$max,
          upperOutliers = list()
        )
      })
    },

    #' @description One density curve per violin
    #' @param violins As returned by `extract_violins()`.
    #' @return A list of point lists, one per violin.
    build_kde_data = function(violins) {
      lapply(violins, function(v) {
        positions <- v$stats$positions
        density <- v$stats$density
        # `width` rather than `density`, matching the ggplot2 and matplotlib
        # vocabulary for this layer; the frontend reads `density ?? width ?? 0`
        # so either is understood, and consistency within r-maidr wins.
        #
        # No pixel coordinates: the base R path has no SVG coordinate
        # injection -- that machinery is ggplot2-only -- so a coordinate
        # emitted here would be a guess at where the point ended up.
        lapply(seq_along(positions), function(i) {
          list(x = v$label, y = positions[i], width = density[i])
        })
      })
    },

    #' @description Selectors addressing each violin's outline
    #' @param violins As returned by `extract_violins()`.
    #' @param gt The grob tree.
    #' @param plot_index Which recorded plot these grobs belong to.
    #' @return A list of selector strings, or an empty list.
    build_kde_selectors = function(violins, gt, plot_index) {
      ids <- self$grob_ids(gt, plot_index, .maidr_vioplot_grob_kinds[["body"]])
      if (length(ids) < length(violins)) {
        return(list())
      }
      lapply(seq_along(violins), function(i) {
        vioplot_grob_selector("polygon", ids[[i]])
      })
    },

    #' @description `BoxSelector` objects addressing each violin's box parts
    #'
    #' vioplot draws the whisker, the quartile box and the median as separate
    #' grobs, so unlike a plotly violin -- where the whole box is one path and
    #' every section has to share it -- each section can point at what it
    #' actually is.
    #'
    #' @param violins As returned by `extract_violins()`.
    #' @param gt The grob tree.
    #' @param plot_index Which recorded plot these grobs belong to.
    #' @return A list of `BoxSelector` lists, or an empty list.
    build_box_selectors = function(violins, gt, plot_index) {
      whiskers <- self$grob_ids(gt, plot_index, .maidr_vioplot_grob_kinds[["whisker"]])
      boxes <- self$grob_ids(gt, plot_index, .maidr_vioplot_grob_kinds[["quartiles"]])
      medians <- self$grob_ids(gt, plot_index, .maidr_vioplot_grob_kinds[["median"]])

      # All three or none. A partial set would leave some sections pointing at
      # elements and others at nothing, which reads as a highlight that works
      # intermittently rather than one that is honestly absent.
      if (
        length(whiskers) < length(violins) ||
          length(boxes) < length(violins) ||
          length(medians) < length(violins)
      ) {
        return(list())
      }

      lapply(seq_along(violins), function(i) {
        whisker <- vioplot_grob_selector("polyline", whiskers[[i]])
        list(
          lowerOutliers = list(),
          min = whisker,
          iq = vioplot_grob_selector("rect", boxes[[i]]),
          q2 = vioplot_grob_selector("use", medians[[i]]),
          max = whisker,
          upperOutliers = list()
        )
      })
    },

    #' @description Grob names of one kind, in drawing order
    #' @param gt The grob tree.
    #' @param plot_index Which recorded plot these grobs belong to.
    #' @param kind One of the kinds in `.maidr_vioplot_grob_kinds`.
    #' @return A character vector of grob names.
    grob_ids = function(gt, plot_index, kind) {
      if (is.null(gt)) {
        return(character(0))
      }
      names <- collect_grob_names(gt)
      matched <- grep(vioplot_grob_pattern(plot_index, kind), names, value = TRUE)
      if (!length(matched)) {
        return(character(0))
      }
      # Sorted by the trailing index rather than lexically, so a plot with ten
      # or more violins does not put `-10` between `-1` and `-2`.
      order_by <- suppressWarnings(as.integer(sub(".*-([0-9]+)$", "\\1", matched)))
      matched[order(order_by)]
    },

    #' @description Which recorded plot this layer belongs to
    #' @param layer_info The recorded plot call and its metadata.
    #' @return An integer index.
    plot_index = function(layer_info) {
      if (!is.null(layer_info) && !is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        1
      }
    },

    #' @description Axis titles for the violin's two axes
    #' @param layer_info The recorded plot call and its metadata.
    #' @return An axes list.
    extract_axis_titles = function(layer_info) {
      args <- if (!is.null(layer_info)) layer_info$plot_call$args else list()
      base_r_categorical_axes(
        args,
        horizontal = self$determine_orientation(layer_info) == "horz"
      )
    },

    #' @description The plot's main title
    #' @param layer_info The recorded plot call and its metadata.
    #' @return A character scalar.
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }
      args <- layer_info$plot_call$args
      recorded_main_title(args)
    },

    #' @description Whether the violins run up the page or across it
    #' @param layer_info The recorded plot call and its metadata.
    #' @return `"vert"` or `"horz"`.
    determine_orientation = function(layer_info) {
      if (is.null(layer_info)) {
        return("vert")
      }
      args <- layer_info$plot_call$args
      if (recorded_flag(args, "horizontal")) "horz" else "vert"
    }
  )
)

#' Every grob name in a tree, depth first
#'
#' Shared with the box plot processor's own walk, which looks for the same
#' `graphics-plot-N-kind-M` names in the same tree shape.
#'
#' @param g A grob, gList, gTree or gtable.
#' @return A character vector of names.
#' @keywords internal
collect_grob_names <- function(g) {
  names <- character(0)
  if (!is.null(g$name)) {
    names <- c(names, as.character(g$name))
  }
  if (inherits(g, "gList")) {
    for (i in seq_along(g)) {
      names <- c(names, collect_grob_names(g[[i]]))
    }
  }
  if (inherits(g, "gTree") && !is.null(g$children)) {
    for (i in seq_along(g$children)) {
      names <- c(names, collect_grob_names(g$children[[i]]))
    }
  }
  if (!is.null(g$grobs)) {
    for (i in seq_along(g$grobs)) {
      names <- c(names, collect_grob_names(g$grobs[[i]]))
    }
  }
  names
}
