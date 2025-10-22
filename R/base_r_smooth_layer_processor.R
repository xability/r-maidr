#' Base R Smooth/Density Layer Processor
#'
#' Processes Base R smooth/density plots (created with plot(density()))
#'
#' @keywords internal
BaseRSmoothLayerProcessor <- R6::R6Class("BaseRSmoothLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL,
                      scale_mapping = NULL, grob_id = NULL,
                      panel_id = NULL, panel_ctx = NULL,
                      layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      list(
        data = data,
        selectors = selectors,
        type = "smooth",
        title = title,
        axes = axes
      )
    },

    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      density_obj <- args[[1]]

      if (!inherits(density_obj, "density")) {
        return(list())
      }

      x_values <- density_obj$x
      y_values <- density_obj$y

      data_points <- lapply(seq_along(x_values), function(i) {
        list(x = x_values[i], y = y_values[i])
      })

      list(data_points)
    },

    generate_selectors = function(layer_info, gt = NULL) {
      if (is.null(gt)) {
        return(list())
      }

      call_index <- layer_info$index

      selectors <- self$generate_selectors_from_grob(gt, call_index)

      selectors
    },

    find_polyline_grobs = function(grob, call_index) {
      names <- character(0)

      if (!is.null(grob$name)) {
        if (grepl(paste0("graphics-plot-", call_index, "-lines-"), grob$name)) {
          names <- c(names, grob$name)
        }
      }

      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_polyline_grobs(grob[[i]], call_index))
        }
      }

      if (inherits(grob, "gTree")) {
        if (!is.null(grob$children)) {
          for (i in seq_along(grob$children)) {
            names <- c(names,
              self$find_polyline_grobs(grob$children[[i]], call_index))
          }
        }
      }

      if (!is.null(grob$grobs)) {
        for (i in seq_along(grob$grobs)) {
          names <- c(names, self$find_polyline_grobs(grob$grobs[[i]],
            call_index))
        }
      }

      names
    },

    generate_selectors_from_grob = function(grob, call_index) {
      polyline_names <- self$find_polyline_grobs(grob, call_index)

      if (length(polyline_names) == 0) {
        return(list())
      }

      selectors <- lapply(polyline_names, function(name) {
        svg_id <- paste0(name, ".1.1")
        escaped <- gsub("\\.", "\\\\.", svg_id)
        paste0("#", escaped)
      })

      selectors
    },

    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(x = "", y = ""))
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      x_title <- if (!is.null(args$xlab)) args$xlab else ""
      y_title <- if (!is.null(args$ylab)) args$ylab else ""

      list(x = x_title, y = y_title)
    },

    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      main_title <- if (!is.null(args$main)) args$main else ""
      main_title
    }
  )
)

