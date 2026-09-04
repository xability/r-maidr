#' Base R Stacked Bar Layer Processor
#'
#' Processes Base R stacked bar plot layers intercepted via the patching
#' system. Assumes sorting by x (columns) and then z (rows) has already been
#' applied by the `SortingPatcher`.
#'
#' @keywords internal
BaseRStackedBarLayerProcessor <- R6::R6Class(
  "BaseRStackedBarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the layer: read its data, selectors, axis titles and main title from
    #'   the recorded call
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
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt, data)

      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      # `extract_data()` reads the matrix the caller passed, so its points are
      # in the vertical arrangement whichever way the bars were drawn --
      # unlike the plain bar processor, which reads the drawn rectangles and
      # so comes out swapped for free. Both halves therefore have to be set
      # here, and from the one answer: a `"horz"` key over vertical points is
      # the combination #184 was about, and these charts read correctly today
      # only because both were left vertical (#189).
      horizontal <- self$is_horizontal_call(layer_info)

      list(
        data = if (horizontal) self$swap_point_axes(data) else data,
        selectors = selectors,
        orientation = if (horizontal) "horz" else "vert",
        # A 100% stacked bar is extracted by this same processor -- the values
        # are already the drawn shares, since base R has no `position = "fill"`
        # and the author normalised the matrix before calling `barplot()`. Only
        # the emitted type differs, so read it rather than hardcoding one.
        type = if (identical(self$layer_info$type, "stacked_normalized_bar")) {
          "stacked_normalized_bar"
        } else {
          "stacked_bar"
        },
        title = title,
        axes = axes,
        domMapping = list(groupDirection = "forward")
      )
    },
    #' @description Whether the plot data must be reordered before drawing; a Base R layer is read
    #'   from the recorded call and never is
    #' @return FALSE
    needs_reordering = function() {
      FALSE
    },
    #' @description One series per row of the recorded height matrix
    #' @param layer_info Layer information with the recorded call
    #' @return List of series
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      height <- recorded_barplot_height(args)

      if (is.null(height) || !is.matrix(height)) {
        return(list())
      }

      # Use current row/col names (SortingPatcher already ordered them)
      type_names <- NULL

      # Check legend.text: use it only if it's a character vector, not TRUE/FALSE
      if (!is.null(args$legend.text) && is.character(args$legend.text)) {
        type_names <- args$legend.text
      }

      if (is.null(type_names)) {
        type_names <- rownames(height)
      }

      if (is.null(type_names)) {
        type_names <- as.character(seq_len(nrow(height)))
      }

      category_names <- args$names.arg

      if (is.null(category_names)) {
        category_names <- colnames(height)
      }
      if (is.null(category_names)) {
        category_names <- as.character(seq_len(ncol(height)))
      }

      data <- lapply(seq_len(nrow(height)), function(r) {
        lapply(seq_len(ncol(height)), function(c) {
          list(
            x = as.character(category_names[c]),
            y = as.numeric(height[r, c]),
            z = as.character(type_names[r])
          )
        })
      })

      data
    },
    #' @description Extract the axis titles for this layer
    #'
    #' A stacked `barplot()` records no title unless the author wrote one, and
    #' its points always carry the column category on x and the segment height
    #' on y, so the defaults name those two. The stack's own dimension is
    #' already announced per point as z; nothing in the call names the
    #' variable those groups came from, so no z title is claimed.
    #'
    #' @param layer_info Layer information
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      base_r_categorical_axes(layer_info$plot_call$args)
    },
    #' @description The main title of the recorded call, or an empty string
    #' @param layer_info Layer information with the recorded call
    #' @return Character string
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }
      args <- layer_info$plot_call$args
      recorded_main_title(args)
    },
    #' @description The selector for the segments, scoped to this layer's plot group
    #' @param layer_info Layer information with the recorded call
    #' @param gt Gtable of the replayed drawing (optional)
    #' @param extracted_data The data already extracted for this layer (optional)
    #' @return List of selectors
    generate_selectors = function(layer_info, gt = NULL, extracted_data = NULL) {
      if (is.null(layer_info) || is.null(gt)) {
        return(list())
      }

      # gridSVG numbers grobs by plot group (panel), not by maidr layer
      call_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }
      rect_groups <- self$find_rect_groups(gt, call_index)
      if (length(rect_groups) == 0) {
        return(list())
      }

      # Order groups by their trailing grob number (drawing order) and
      # keep only the data groups: barplot() draws one rect group per
      # x category FIRST; legend.text adds extra rect groups (border,
      # swatches) afterwards which must not be highlight targets.
      group_numbers <- suppressWarnings(
        as.integer(sub(".*-([0-9]+)$", "\\1", rect_groups))
      )
      rect_groups <- rect_groups[order(group_numbers)]
      n_categories <- if (length(extracted_data) > 0) {
        length(extracted_data[[1]])
      } else {
        0
      }
      if (n_categories > 0 && length(rect_groups) > n_categories) {
        rect_groups <- rect_groups[seq_len(n_categories)]
      }

      # Compose a single selector string that lists all rect groups
      # Note: exported SVG ids often append ".1" to grob names
      selectors <- paste0(
        "#",
        gsub("\\.", "\\\\.", paste0(rect_groups, ".1")),
        " rect",
        collapse = ", "
      )

      list(selectors)
    },
    #' @description Find every rect group drawn by the plot group at `call_index`
    #' @param grob The grob tree to search
    #' @param call_index Index of the recorded plot group, which numbers the panel's grobs
    #' @return Character vector of grob names
    find_rect_groups = function(grob, call_index) {
      names <- character(0)

      # Match any rect group for this call index (be permissive; exporter may append suffixes)
      if (!is.null(grob$name) && grepl(paste0("graphics-plot-", call_index, "-rect-"), grob$name)) {
        names <- c(names, grob$name)
      }

      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_rect_groups(grob[[i]], call_index))
        }
      }

      if (inherits(grob, "gTree")) {
        if (!is.null(grob$children)) {
          for (i in seq_along(grob$children)) {
            names <- c(names, self$find_rect_groups(grob$children[[i]], call_index))
          }
        }
      }

      if (!is.null(grob$grobs)) {
        for (i in seq_along(grob$grobs)) {
          names <- c(names, self$find_rect_groups(grob$grobs[[i]], call_index))
        }
      }

      # keep unique and in order of discovery (DOM order forward)
      unique(names)
    }
  )
)
