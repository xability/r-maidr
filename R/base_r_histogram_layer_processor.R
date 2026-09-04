#' Base R Histogram Layer Processor
#'
#' Processes Base R histogram plot layers using verified data extraction
#' and selector generation logic.
#'
#' @keywords internal
BaseRHistogramLayerProcessor <- R6::R6Class(
  "BaseRHistogramLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the layer: read its data, selectors, axis titles and main title from
    #'   the recorded call
    #' @param plot Unused; present for the processor interface
    #' @param layout Unused; present for the processor interface
    #' @param built Unused; present for the processor interface
    #' @param gt Gtable of the replayed drawing, searched for selectors (optional)
    #' @param layer_info Layer information with the recorded call
    #' @return List describing the layer for the MAIDR payload
    process = function(plot, layout, built = NULL, gt = NULL, layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      list(
        data = data,
        selectors = selectors,
        type = "hist",
        title = title,
        axes = axes
      )
    },
    #' @description One point per bin, from the histogram recomputed from the recorded call
    #' @param layer_info Layer information with the recorded call
    #' @return List of points
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      hist_obj <- self$recompute_histogram(args)
      if (is.null(hist_obj)) {
        return(list())
      }

      breaks <- hist_obj$breaks
      counts <- hist_obj$counts
      mids <- hist_obj$mids

      y_values <- if (self$is_frequency(args, hist_obj)) counts else hist_obj$density

      histogram_data <- list()
      for (i in seq_along(counts)) {
        histogram_data[[i]] <- list(
          x = mids[i],
          y = y_values[i],
          xMin = breaks[i],
          xMax = breaks[i + 1],
          yMin = 0,
          yMax = y_values[i]
        )
      }

      histogram_data
    },

    #' @description Recompute the plotted histogram from the recorded call
    #'
    #' @param args Recorded argument list
    #' @return A "histogram" object, or NULL when the call recorded no data
    recompute_histogram = function(args) {
      hist_data <- args[["x"]]
      if (is.null(hist_data) && length(args) > 0) {
        arg_names <- names(args)
        unnamed <- if (is.null(arg_names)) {
          seq_along(args)
        } else {
          which(!nzchar(arg_names))
        }
        if (length(unnamed) > 0) {
          hist_data <- args[[unnamed[1]]]
        }
      }
      if (is.null(hist_data)) {
        return(NULL)
      }

      # Pass the original binning parameters so the recomputed histogram
      # matches the plotted one (right/include.lowest change bin counts).
      # Suppress warnings about parameters unused when plot = FALSE.
      hist_params <- list(plot = FALSE)
      for (param in c("breaks", "nclass", "right", "include.lowest")) {
        if (!is.null(args[[param]])) {
          hist_params[[param]] <- args[[param]]
        }
      }

      # Use graphics::hist directly to avoid calling the wrapped version
      suppressWarnings(do.call(graphics::hist, c(list(hist_data), hist_params)))
    },

    #' @description Is this a frequency histogram rather than a density one?
    #'
    #' The plotted y-axis shows counts only for frequency histograms; with
    #' freq = FALSE or probability = TRUE it shows densities. hist()'s own
    #' default is freq = TRUE only for equidistant breaks.
    #'
    #' @param args Recorded argument list
    #' @param hist_obj The recomputed histogram, or NULL when there is none
    #' @return Logical
    is_frequency = function(args, hist_obj = NULL) {
      if (!is.null(args[["freq"]])) {
        return(recorded_flag(args, "freq"))
      }
      if (!is.null(args[["probability"]])) {
        return(!recorded_flag(args, "probability"))
      }
      # Without a recomputed histogram there is no equidist to consult, and
      # a histogram with no recorded data draws nothing either way.
      is.null(hist_obj) || isTRUE(hist_obj$equidist)
    },
    #' @description The selector for the bins, scoped to this layer's plot group
    #' @param layer_info Layer information with the recorded call
    #' @param gt Gtable of the replayed drawing (optional)
    #' @return List of selectors
    generate_selectors = function(layer_info, gt = NULL) {
      # Use group_index for grob lookup (not layer index)
      # Multiple layers in same group share same grob with group-based naming
      group_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      # Use the working method - generate selectors from the provided grob
      if (!is.null(gt)) {
        selectors <- self$generate_selectors_from_grob(gt, group_index)
        if (length(selectors) > 0 && selectors != "") {
          return(list(selectors))
        }
      }

      # Fallback selector for histograms - return as array
      main_selector <- paste0(
        "rect[id^='graphics-plot-",
        group_index,
        "-rect-1']"
      )
      list(main_selector)
    },
    #' @description Find the rect grobs drawn by the recorded call at `call_index`
    #' @param grob The grob tree to search
    #' @param call_index Index of the recorded plot group, which numbers the panel's grobs
    #' @return Character vector of grob names
    find_rect_grobs = function(grob, call_index) {
      names <- character(0)

      # Look for graphics-plot pattern matching our call index
      if (
        !is.null(grob$name) && grepl(paste0("graphics-plot-", call_index, "-rect-1"), grob$name)
      ) {
        names <- c(names, grob$name)
      }

      # Recursively search through gList
      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_rect_grobs(grob[[i]], call_index))
        }
      }

      # Recursively search through gTree children
      if (inherits(grob, "gTree")) {
        if (!is.null(grob$children)) {
          for (i in seq_along(grob$children)) {
            names <- c(names, self$find_rect_grobs(grob$children[[i]], call_index))
          }
        }
      }

      # Also check grobs field (like stacked bar processor)
      if (!is.null(grob$grobs)) {
        for (i in seq_along(grob$grobs)) {
          names <- c(names, self$find_rect_grobs(grob$grobs[[i]], call_index))
        }
      }

      names
    },
    #' @description Build this layer's selector from the grob tree
    #' @param grob The grob tree to search
    #' @param call_index Index of the recorded plot group, which numbers the panel's grobs
    #' @return A selector string, or an empty string when no grob matches
    generate_selectors_from_grob = function(grob, call_index = NULL) {
      # Use robust selector generation with plot_index for multipanel support
      selector <- generate_robust_selector(grob, "rect", "rect", plot_index = call_index)

      return(selector)
    },
    #' @description Extract the axis titles for this layer
    #'
    #' `hist()` derives both titles inside the call and so records neither:
    #' the x title is `deparse(substitute(x))`, which is gone by the time the
    #' evaluated arguments reach us, and the y title is "Frequency" or
    #' "Density" depending on what the bars measure. The y default therefore
    #' repeats hist()'s own choice -- resolved by the same rule that decides
    #' which values extract_data() emits, so the noun always names the number
    #' being announced -- while x says only what the axis certainly holds:
    #' the bins.
    #'
    #' @param layer_info Layer information
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      args <- layer_info$plot_call$args

      build_axes(
        x = recorded_axis_label(args, "xlab", "Bin"),
        y = recorded_axis_label(args, "ylab", self$frequency_label(args))
      )
    },

    #' @description The title hist() itself would print above the counted axis
    #'
    #' @param args Recorded argument list
    #' @return "Frequency" or "Density"
    frequency_label = function(args) {
      # The histogram is only recomputed when neither freq nor probability
      # was recorded, since only then does the answer depend on the breaks.
      needs_breaks <- is.null(args[["freq"]]) && is.null(args[["probability"]])
      hist_obj <- if (needs_breaks) self$recompute_histogram(args) else NULL

      if (self$is_frequency(args, hist_obj)) "Frequency" else "Density"
    },
    #' @description The main title of the recorded call, or an empty string
    #' @param layer_info Layer information with the recorded call
    #' @return Character string
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      main_title <- recorded_main_title(args)

      main_title
    }
  )
)
