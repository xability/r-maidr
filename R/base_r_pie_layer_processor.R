#' Base R Pie Chart Layer Processor
#'
#' Processes Base R `pie()` layers based on recorded plot calls. A pie layer is
#' 1-D and flat: one point per slice, carrying the slice label as `x` and the
#' slice magnitude as `y`. Percentages are derived by the frontend from those
#' magnitudes, so none are emitted here.
#'
#' @keywords internal
BaseRPieLayerProcessor <- R6::R6Class(
  "BaseRPieLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the pie layer
    #' @param plot Unused for Base R (NULL)
    #' @param layout Layout information
    #' @param built Unused for Base R (NULL)
    #' @param gt Grob tree used for selector generation
    #' @param scale_mapping Unused for Base R
    #' @param grob_id Unused for Base R
    #' @param panel_id Unused for Base R
    #' @param panel_ctx Unused for Base R
    #' @param layer_info Layer information (contains the recorded plot call)
    #' @return List with data, selectors, type, title and axes
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt, data)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      # No orientation field: a pie has none, and the frontend navigates
      # every pie as a single row of slices.
      list(
        data = data,
        selectors = selectors,
        type = "pie",
        title = title,
        axes = axes
      )
    },

    #' @description Pie slices are emitted in drawing order (see extract_data)
    #' @return FALSE
    needs_reordering = function() {
      FALSE
    },

    #' @description Extract one point per slice from the recorded call
    #' @param layer_info Layer information
    #' @return Flat list of `list(x = <label>, y = <value>)` points
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      args <- layer_info$plot_call$args

      # pie()'s first formal is `x`; a named `x` wins over the first unnamed
      # argument, which is how the call itself matches them.
      values <- resolve_xy_args(args)$x
      if (is.null(values) || !is.numeric(values)) {
        return(list())
      }

      labels <- self$resolve_slice_labels(values, args)
      # as.numeric() drops names, so labels must be resolved before it runs.
      values <- as.numeric(values)

      # Emit slices in recorded-call order: the SVG is replayed from these
      # same args, so slice k is polygon k. Re-sorting here (by size, or
      # alphabetically) would desynchronise every announced value from the
      # wedge it highlights. pie() rejects negative and NA values at the
      # source, so the caller has already heard about those.
      data_points <- vector("list", length(values))
      for (i in seq_along(values)) {
        data_points[[i]] <- list(
          x = labels[i],
          y = values[i]
        )
      }

      data_points
    },

    #' @description Resolve the per-slice labels the way pie() does
    #'
    #' `labels` defaults to `names(x)`, and falls back to the slice position
    #' when the input is unnamed. `pie(labels = NA)` draws neither label nor
    #' leader line, but the wedges are still there and still navigable, so
    #' those slices are announced by position rather than as "NA".
    #'
    #' @param values The recorded `x` argument (names still attached)
    #' @param args Recorded argument list from the pie() call
    #' @return Character vector with one label per slice
    resolve_slice_labels = function(values, args) {
      labels <- args$labels
      if (is.null(labels)) {
        labels <- names(values)
      }
      if (is.null(labels)) {
        labels <- seq_along(values)
      }

      # Index rather than recycle, matching pie()'s own `labels[i]` lookup:
      # a short `labels` leaves the trailing slices unlabelled.
      labels <- as.character(labels)[seq_along(values)]
      positions <- as.character(seq_along(values))
      labels[is.na(labels)] <- positions[is.na(labels)]
      labels
    },

    #' @description Generate one selector per wedge, index-aligned to the data
    #' @param layer_info Layer information
    #' @param gt Grob tree to search
    #' @param extracted_data Points from [extract_data()], used for the count
    #' @return List of CSS selector strings, one per slice
    generate_selectors = function(layer_info, gt = NULL, extracted_data = NULL) {
      n_slices <- length(extracted_data)
      if (is.null(gt) || n_slices == 0) {
        return(list())
      }

      # For multipanel plots the grob names carry the panel number
      plot_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      poly_names <- self$find_polygon_grobs(gt, plot_index)

      # `density =` shading interleaves a segments grob per hatch line between
      # the wedges, so the polygon grobs are no longer contiguous in tree
      # order. Sort by the trailing grob number; a lexicographic sort would
      # also place "-polygon-10" before "-polygon-2".
      poly_names <- poly_names[order(suppressWarnings(
        as.integer(sub(".*-([0-9]+)$", "\\1", poly_names))
      ))]

      # pie() emits one polygon per slice, zero-valued slices included, so a
      # short list means these are not this pie's grobs. Filling the gap with
      # a guessed id would silently highlight another panel's wedges.
      if (length(poly_names) < n_slices) {
        return(list())
      }

      # Unlike barplot, whose n bars all live inside a single rect grob, each
      # wedge is its own grob and therefore needs its own selector.
      lapply(poly_names[seq_len(n_slices)], function(name) {
        escaped <- gsub("\\.", "\\\\.", paste0(name, ".1"))
        paste0("#", escaped, " polygon")
      })
    },

    #' @description Recursively collect this plot's wedge polygon grob names
    #' @param grob The grob tree to search
    #' @param plot_index The plot (panel) index to match
    #' @return Character vector of grob names
    find_polygon_grobs = function(grob, plot_index) {
      names <- character(0)

      pattern <- paste0("^graphics-plot-", plot_index, "-polygon-[0-9]+$")
      if (!is.null(grob$name) && grepl(pattern, grob$name)) {
        names <- c(names, grob$name)
      }

      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_polygon_grobs(grob[[i]], plot_index))
        }
      }

      if (inherits(grob, "gTree") && !is.null(grob$children)) {
        for (i in seq_along(grob$children)) {
          names <- c(names, self$find_polygon_grobs(grob$children[[i]], plot_index))
        }
      }

      if (!is.null(grob$grobs)) {
        for (i in seq_along(grob$grobs)) {
          names <- c(names, self$find_polygon_grobs(grob$grobs[[i]], plot_index))
        }
      }

      names
    },

    #' @description Extract the axis titles for this layer
    #'
    #' x names what the slice labels mean, y what their magnitudes measure.
    #'
    #' @param layer_info Layer information
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(build_axes(x = "", y = ""))
      }

      args <- layer_info$plot_call$args
      build_axes(
        x = if (!is.null(args$xlab)) args$xlab else "",
        y = if (!is.null(args$ylab)) args$ylab else ""
      )
    },

    #' @description Extract the main title for this layer
    #' @param layer_info Layer information
    #' @return Character scalar
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }

      args <- layer_info$plot_call$args
      if (!is.null(args$main)) args$main else ""
    }
  )
)
