#' Abstract Layer Processor Interface
#'
#' This is the abstract base class for all layer processors. It defines the
#' interface that all layer processors must implement.
#'
#' @field layer_info Information about the layer
#' @keywords internal
LayerProcessor <- R6::R6Class(
  "LayerProcessor",
  private = list(
    .last_result = NULL
  ),
  public = list(
    #' @field layer_info Information about the layer
    layer_info = NULL,

    #' @description Initialize the layer processor
    #' @param layer_info Information about the layer
    initialize = function(layer_info) {
      self$layer_info <- layer_info
    },

    #' @description Process the layer (MUST be implemented by subclasses)
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return List with data and selectors
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_ctx = NULL) {
      stop("process() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description Extract data from the layer (MUST be implemented by subclasses)
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @return Extracted data
    extract_data = function(plot, built = NULL) {
      stop("extract_data() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description Generate selectors for the layer (MUST be implemented by subclasses)
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selector generation (optional)
    #' @return List of selectors
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      stop("generate_selectors() method must be implemented by subclasses", call. = FALSE)
    },

    #' @description Read this layer's rows out of the built plot.
    #'
    #' Scoped to one panel when asked. A faceted plot puts every panel's rows
    #' in one frame, so a layer that took all of them would describe the whole
    #' facet grid as one series.
    #'
    #' @param built Built plot data
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A data frame of computed aesthetics, or NULL
    get_layer_built_data = function(built, panel_id = NULL) {
      index <- self$get_layer_index()
      if (is.null(index) || index < 1L || index > length(built$data)) {
        return(NULL)
      }

      layer_data <- built$data[[index]]
      if (is.null(layer_data) || nrow(layer_data) == 0) {
        return(NULL)
      }

      if (!is.null(panel_id) && "PANEL" %in% names(layer_data)) {
        subset <- layer_data[as.character(layer_data$PANEL) ==
          as.character(panel_id), , drop = FALSE]
        if (nrow(subset) > 0) {
          return(subset)
        }
      }

      layer_data
    },

    #' @description Resolve which entry of \code{built$layout$panel_params}
    #' describes a facet panel.
    #'
    #' Panel parameters are stored in the row order of
    #' \code{built$layout$layout}, so panel \code{n} is entry \code{n}. An
    #' unfaceted plot (or an unusable id) resolves to the only panel there is.
    #'
    #' Shared: the line processor asked this first and the gantt processor
    #' asks it to name its lanes, and two readings disagreeing about which
    #' panel they are describing is not a difference worth having.
    #'
    #' @param built Built plot data
    #' @param panel_id Panel id for faceted plots (optional)
    #' @return Integer index guaranteed to be in range
    resolve_panel_index = function(built, panel_id = NULL) {
      n_panels <- length(built$layout$panel_params)
      if (is.null(panel_id) || n_panels == 0) {
        return(1L)
      }
      candidate <- suppressWarnings(as.integer(as.character(panel_id)))
      if (is.na(candidate) || candidate < 1 || candidate > n_panels) {
        return(1L)
      }
      candidate
    },

    #' @description Resolve the plot layer this processor was built for.
    #'
    #' Every processor knows its index and several need the layer itself --
    #' for its geom, its position or its own `data` -- so the lookup lives
    #' here rather than being copied into each. Answers NULL rather than
    #' erroring when the index does not resolve, since a caller that cannot
    #' find its layer has a reading to fall back on and no crash to justify.
    #'
    #' @param plot The ggplot2 object
    #' @return The layer, or NULL when the index does not resolve
    get_own_layer = function(plot) {
      if (is.null(plot) || is.null(plot$layers)) {
        return(NULL)
      }
      index <- self$get_layer_index()
      if (is.null(index) || index < 1L || index > length(plot$layers)) {
        return(NULL)
      }
      plot$layers[[index]]
    },

    #' @description Find the grob tree ggplot2 drew for this layer.
    #'
    #' ggplot2 names a layer's grob after its geom
    #' (\code{geom_smooth.gTree.5}), so the tree is located by that prefix
    #' and, when the plot repeats the geom, by this layer's position among
    #' the layers sharing it. Scoping to the layer's own tree is what keeps a
    #' sibling layer's grobs out of whatever the caller counts inside it.
    #'
    #' Lives here rather than on one processor because two now need it and
    #' the walk is the same walk -- the argument that moved
    #' \code{get_own_layer()} and \code{get_layer_built_data()} here before
    #' it. What differs between callers is only which layer they are looking
    #' for, and that is the \code{target} argument; the smooth processor
    #' passes a resolved index because it may describe a layer other than its
    #' own, and everything else takes the default.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for panel-scoped selector generation
    #' @param target Index of the layer to find; defaults to this one's
    #' @return The matching grob, or NULL
    find_layer_grob_tree = function(plot, gt, panel_ctx = NULL, target = NULL) {
      if (is.null(target)) {
        target <- self$get_layer_index()
      }
      if (is.null(plot) || is.null(plot$layers) || is.null(target) ||
        target < 1L || target > length(plot$layers)) {
        return(NULL)
      }

      prefix <- geom_grob_prefix(plot$layers[[target]]$geom)

      position <- 0L
      for (i in seq_along(plot$layers)) {
        if (identical(geom_grob_prefix(plot$layers[[i]]$geom), prefix)) {
          position <- position + 1L
          if (i == target) break
        }
      }

      roots <- if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (is.null(panel_grob)) list() else list(panel_grob)
      } else if ("grobs" %in% names(gt)) {
        gt$grobs
      } else {
        list(gt)
      }

      pattern <- paste0("^", prefix, "\\.")
      matches <- list()
      collect <- function(grob) {
        if (!is.null(grob$name) && grepl(pattern, grob$name)) {
          # Do not descend: a match is the whole layer's tree.
          matches[[length(matches) + 1L]] <<- grob
          return(invisible(NULL))
        }
        if (inherits(grob, "gTree")) {
          for (child in grob$children) collect(child)
        }
        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) collect(grob[[i]])
        }
        invisible(NULL)
      }
      for (root in roots) collect(root)

      if (position < 1L || position > length(matches)) {
        return(NULL)
      }
      matches[[position]]
    },

    #' @description The polyline grob ggplot2 drew for THIS layer.
    #'
    #' Shared rather than owned by the line processor: `GeomPath`, `GeomStep`
    #' and `GeomContour` all draw through a bare `polylineGrob` and so all
    #' land in the same auto-named candidate list, which is exactly why one
    #' answer to "which of them is mine" has to serve all three.
    #'
    #' @param plot The ggplot2 object
    #' @param panel_grob The panel's grob tree
    #' @param target Index of the layer to find; defaults to this one's
    #' @return The matching grob, or NULL
    find_layer_polyline_grob = function(plot, panel_grob, target = NULL) {
      if (is.null(target)) {
        target <- self$get_layer_index()
      }
      candidates <- self$layer_polyline_grobs(plot, panel_grob, target)
      if (length(candidates) == 0L) {
        return(NULL)
      }
      position <- polyline_layer_position(plot, target)
      if (!is.null(position)) {
        if (position > length(candidates)) {
          return(NULL)
        }
        return(candidates[[position]])
      }
      if (length(candidates) == 1L) candidates[[1]] else NULL
    },

    #' @description Panel polylines that a line layer could have drawn.
    #'
    #' \code{GeomPath$draw_panel()} returns a bare \code{polylineGrob}, so a
    #' line layer's grob carries grid's auto-generated
    #' \code{GRID.polyline.N} name with no geom prefix to match on -- only
    #' its draw-order position identifies it. Layers that DO name their grob
    #' tree after their geom (\code{geom_smooth.gTree.N}) are skipped whole
    #' via \code{geom_grob_prefix()}, the same helper the smooth processor
    #' uses to scope itself to its own tree; without that, the smooth's
    #' three curves are counted as line-layer polylines and shift every
    #' position by three. Panel grid lines are named after the theme element
    #' (\code{panel.grid.major.x..polyline.N}) and so never match.
    #'
    #' @param plot The ggplot2 object
    #' @param panel_grob The panel's grob tree
    #' @param target Index of the layer whose polylines are wanted
    #' @return List of grobs in draw order
    layer_polyline_grobs = function(plot, panel_grob, target = NULL) {
      skip <- self$other_geom_grob_prefixes(plot, target)
      out <- list()
      collect <- function(grob) {
        name <- grob$name
        belongs_to_other_layer <- !is.null(name) && length(skip) > 0L &&
          any(startsWith(name, paste0(skip, ".")))
        if (belongs_to_other_layer) {
          # Another layer's tree: a match is the whole layer, do not descend.
          return(invisible(NULL))
        }
        if (!is.null(name) && grepl("^GRID\\.polyline\\.\\d+$", name)) {
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

    #' @description Grob-name prefixes belonging to the plot's OTHER geoms.
    #'
    #' This layer's own prefix is excluded so that a second layer sharing
    #' the geom (two \code{geom_line()} calls) is still walked.
    #'
    #' @param plot The ggplot2 object
    #' @param target Index of the layer whose prefix is the \emph{own} one
    #' @return Character vector of prefixes, possibly empty
    other_geom_grob_prefixes = function(plot, target = NULL) {
      if (is.null(target)) {
        target <- self$get_layer_index()
      }
      prefix_of <- function(layer) {
        tryCatch(geom_grob_prefix(layer$geom), error = function(e) NA_character_)
      }
      own <- prefix_of(plot$layers[[target]])
      prefixes <- vapply(plot$layers, prefix_of, character(1))
      prefixes <- unique(prefixes[!is.na(prefixes)])
      if (!is.na(own)) {
        prefixes <- setdiff(prefixes, own)
      }
      prefixes
    },

    #' @description Check if this layer needs reordering (OPTIONAL - default: FALSE)
    #' @return Logical indicating if reordering is needed
    needs_reordering = function() {
      FALSE
    },

    #' @description Reorder layer data (OPTIONAL - default: no-op)
    #' @param data data.frame effective for this layer
    #' @param plot full ggplot object (for mappings)
    #' @return Reordered data
    reorder_layer_data = function(data, plot) {
      data
    },

    #' @description Augment the plot before building (OPTIONAL - default: no-op)
    #'
    #' Called by the orchestrator before ggplot_build/ggplotGrob. Allows a
    #' processor to inject additional geom layers (e.g., a boxplot inside a
    #' violin) so they appear in the SVG and can be targeted by selectors.
    #'
    #' @param plot The ggplot2 object to augment
    #' @return The (possibly augmented) ggplot2 object
    augment_plot = function(plot) {
      plot
    },

    #' @description Check if this processor needs to augment the plot
    #' @return Logical
    needs_augmentation = function() {
      FALSE
    },

    #' @description Get layer index
    #' @return Layer index
    get_layer_index = function() {
      self$layer_info$index
    },

    #' @description Is this layer drawn with its category axis running up `y`?
    #'
    #' `ggplot(df, aes(y = g, x = n)) + geom_col()` is the ordinary spelling of
    #' a horizontal bar chart. `ggplot_build()` marks such a layer
    #' `flipped_aes` and swaps which computed column holds what, so a
    #' processor that reads `x` as the category and `y` as the measure picks up
    #' exactly the wrong pair unless it asks first (#162, #184, #186).
    #'
    #' Lives here rather than on one processor because three of them need the
    #' same answer, and because a processor that never asks it goes wrong
    #' silently: both columns hold plausible values.
    #'
    #' `coord_flip()` is a different thing and answers `FALSE` here. It
    #' rotates the coordinate system and leaves `flipped_aes` alone, so the
    #' data layout is genuinely unflipped.
    #'
    #' @param built A `ggplot_build()` result, or `NULL` when the caller has
    #'   none -- in which case the layer is treated as unflipped, since there
    #'   is nothing to read the flag from.
    #' @return `TRUE` when the category runs up the y axis.
    is_flipped_layer = function(built = NULL) {
      if (is.null(built) || is.null(built$data)) {
        return(FALSE)
      }
      layer_index <- self$get_layer_index()
      if (layer_index > length(built$data)) {
        return(FALSE)
      }
      isTRUE(built$data[[layer_index]]$flipped_aes[1])
    },

    #' @description Exchange a built layer's paired x and y columns
    #'
    #' Swapping the pairs up front lets every branch downstream stay written
    #' against one arrangement rather than each learning to ask which way round
    #' it is -- and a branch that forgot to ask would go wrong silently, since
    #' both columns hold plausible numbers.
    #'
    #' @param built_data One layer's built data.
    #' @return The same frame with its x and y pairs exchanged.
    unflip_columns = function(built_data) {
      for (pair in list(c("x", "y"), c("xmin", "ymin"), c("xmax", "ymax"))) {
        if (all(pair %in% names(built_data))) {
          held <- built_data[[pair[1]]]
          built_data[[pair[1]]] <- built_data[[pair[2]]]
          built_data[[pair[2]]] <- held
        }
      }
      built_data
    },

    #' @description Was this base R call drawn with `horiz = TRUE`?
    #'
    #' The base R counterpart of {@link is_flipped_layer}: `barplot()` takes
    #' the orientation as an argument rather than marking the built layer, so
    #' the answer is read back off the captured call.
    #'
    #' @param layer_info The captured layer information, or `NULL`.
    #' @return `TRUE` when the bars run across the page.
    is_horizontal_call = function(layer_info = NULL) {
      if (is.null(layer_info)) {
        return(FALSE)
      }
      recorded_flag(layer_info$plot_call$args, "horiz")
    },

    #' @description Exchange a panel's x and y scales
    #'
    #' So the break labels a processor reads come from the axis the categories
    #' are actually drawn on. Both the scale objects and the flattened
    #' `x.labels`/`y.labels` of older ggplot2 are swapped, since readers fall
    #' back from one to the other.
    #'
    #' @param panel_params One entry of `built$layout$panel_params`.
    #' @return The same list with its x and y entries exchanged.
    unflip_panel_params = function(panel_params) {
      for (pair in list(c("x", "y"), c("x.labels", "y.labels"))) {
        held <- panel_params[[pair[1]]]
        panel_params[[pair[1]]] <- panel_params[[pair[2]]]
        panel_params[[pair[2]]] <- held
      }
      panel_params
    },

    #' @description Put a horizontal layer's category and measure in the fields
    #'   the bar grammar reads them from.
    #'
    #' Processors emit `x = category, y = measure`, which is the vertical
    #' arrangement. A horizontal bar is read the other way round: MAIDR takes
    #' `x` as the magnitude and `y` as the category when `orientation` is
    #' `"horz"`, so the pair has to be exchanged on the way out. Left
    #' unexchanged, the core looks for a number and finds a category name --
    #' no magnitude to pitch, and an announcement that pairs the category axis
    #' with the measure and the measure axis with the category name (#184).
    #'
    #' Only the bar family wants this, which is why it is a step a processor
    #' opts into rather than something the orchestrator applies to every
    #' horizontal layer. An error bar keeps its category in `x` at both
    #' orientations and lets `orientation` swap only which axis labels the
    #' reading is announced against; a box carries quantiles and has no axis
    #' assignment to exchange at all.
    #'
    #' @param data_points Points in `x = category, y = measure` form. A nested
    #'   list -- one series per element, as a grouped bar layer emits -- is
    #'   handled as well as a flat one.
    #' @return The same points with `x` and `y` exchanged.
    swap_point_axes = function(data_points) {
      lapply(data_points, function(entry) {
        if (is.null(names(entry))) {
          return(self$swap_point_axes(entry))
        }
        swapped <- entry
        swapped$x <- entry$y
        swapped$y <- entry$x
        swapped
      })
    },

    #' @description Store the last processed result (used by orchestrator)
    #' @param result The result to store
    set_last_result = function(result) {
      private$.last_result <- result
      invisible(result)
    },

    #' @description Get the last processed result
    #' @return The last result
    get_last_result = function() {
      private$.last_result
    },

    #' @description Extract axes labels for this specific layer
    #'
    #' Returns axes in the canonical per-axis object schema:
    #' \code{list(x = list(label = "..."), y = list(label = "..."))}.
    #'
    #' Bare strings, top-level \code{format}/\code{min}/\code{max}/\code{tickStep}/
    #' \code{fill}/\code{level}, and any non-\{x,y,z\} keys are NOT permitted.
    #'
    #' @param plot The ggplot object
    #' @param layout Global layout with fallback axes
    #' @return Named list with \code{x} and \code{y} AxisConfig objects
    extract_layer_axes = function(plot, layout) {
      layer_index <- self$get_layer_index()

      # Start with layout axes as fallback. Layout may already carry the new
      # AxisConfig shape, a legacy bare string, or be NULL.
      x_label <- extract_axis_label(layout$axes$x, default = "")
      y_label <- extract_axis_label(layout$axes$y, default = "")

      # Helper to extract variable name from potentially complex expressions
      extract_var_name <- function(mapping_expr) {
        tryCatch(
          {
            # Try simple conversion first
            rlang::as_label(mapping_expr)
          },
          error = function(e) {
            # If that fails, try to extract the first symbol from the expression
            expr <- rlang::quo_get_expr(mapping_expr)
            if (is.call(expr) && length(expr) > 1) {
              # For expressions like line_values * scale_factor, extract first symbol
              first_arg <- expr[[2]]
              if (is.symbol(first_arg)) {
                return(as.character(first_arg))
              }
            }
            # If all else fails, return NULL to use fallback
            NULL
          }
        )
      }

      # Try to get layer-specific mapping
      if (!is.null(plot$layers[[layer_index]]$mapping)) {
        layer_mapping <- plot$layers[[layer_index]]$mapping

        # Override with layer-specific x mapping if it exists
        if (!is.null(layer_mapping$x)) {
          extracted_x <- extract_var_name(layer_mapping$x)
          if (!is.null(extracted_x)) {
            x_label <- extracted_x
          }
        }

        # Override with layer-specific y mapping if it exists
        if (!is.null(layer_mapping$y)) {
          extracted_y <- extract_var_name(layer_mapping$y)
          if (!is.null(extracted_y)) {
            y_label <- extracted_y
          }
        }
      }

      list(
        x = list(label = x_label),
        y = list(label = y_label)
      )
    }
  )
)
