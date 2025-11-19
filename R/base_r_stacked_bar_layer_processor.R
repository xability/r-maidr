#' Base R Stacked Bar Layer Processor
#'
#' Processes Base R stacked bar plot layers intercepted via the patching
#' system. Assumes sorting by x (columns) and then fill (rows) has already been
#' applied by the `SortingPatcher`.
#'
#' @keywords internal
BaseRStackedBarLayerProcessor <- R6::R6Class(
  "BaseRStackedBarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL,
      layer_info = NULL
    ) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)

      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      list(
        data = data,
        selectors = selectors,
        type = "stacked_bar",
        title = title,
        axes = axes,
        dom_mapping = list(groupDirection = "forward")
      )
    },
    needs_reordering = function() {
      FALSE
    },
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      height <- args$height
      if (is.null(height) && length(args) > 0) {
        height <- args[[1]]
      }

      if (is.null(height) || !is.matrix(height)) {
        return(list())
      }

      # Use current row/col names (SortingPatcher already ordered them)
      type_names <- rownames(height)
      if (is.null(type_names)) {
        type_names <- as.character(seq_len(nrow(height)))
      }

      category_names <- colnames(height)
      if (is.null(category_names)) {
        category_names <- as.character(seq_len(ncol(height)))
      }

      # Build MAIDR data format: list of rows (fills), each row is list of points
      data <- lapply(seq_len(nrow(height)), function(r) {
        lapply(seq_len(ncol(height)), function(c) {
          list(
            x = as.character(category_names[c]),
            y = as.numeric(height[r, c]),
            fill = as.character(type_names[r])
          )
        })
      })

      data
    },
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(x = "", y = ""))
      }
      args <- layer_info$plot_call$args
      x_title <- if (!is.null(args$xlab)) args$xlab else ""
      y_title <- if (!is.null(args$ylab)) args$ylab else ""
      list(x = x_title, y = y_title)
    },
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }
      args <- layer_info$plot_call$args
      if (!is.null(args$main)) args$main else ""
    },
    generate_selectors = function(layer_info, gt = NULL) {
      if (is.null(layer_info) || is.null(gt)) {
        return(list())
      }

      call_index <- layer_info$index
      rect_groups <- self$find_rect_groups(gt, call_index)
      if (length(rect_groups) == 0) {
        return(list())
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
