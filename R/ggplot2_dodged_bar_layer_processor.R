#' Dodged Bar Layer Processor
#'
#' Processes dodged bar plot layers with complete logic included
#'
#' @keywords internal
Ggplot2DodgedBarLayerProcessor <- R6::R6Class(
  "Ggplot2DodgedBarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      data <- self$extract_data(plot, built, panel_ctx = panel_ctx)

      selectors <- self$generate_selectors(plot, gt, panel_ctx = panel_ctx)

      # Build axes including fill label for dodged bars
      axes <- self$extract_layer_axes(plot, layout)

      # Add fill axis label from built plot labels (includes labs(fill = ...))
      if (!is.null(built)) {
        fill_label <- built$plot$labels$fill
      } else {
        b <- ggplot2::ggplot_build(plot)
        fill_label <- b$plot$labels$fill
      }
      if (is.null(fill_label)) {
        # Fallback: get fill label from mapping expression
        layer_index <- self$get_layer_index()
        fill_quo <- plot$layers[[layer_index]]$mapping$fill
        if (is.null(fill_quo)) fill_quo <- plot$mapping$fill
        if (!is.null(fill_quo)) {
          fill_label <- rlang::as_label(fill_quo)
        }
      }
      if (!is.null(fill_label)) {
        axes$z <- list(label = fill_label)
      }

      list(
        data = data,
        selectors = selectors,
        title = if (!is.null(layout$title)) layout$title else "",
        axes = axes
      )
    },
    needs_reordering = function() {
      TRUE
    },
    #' @description Resolve this layer's x/y/fill aesthetics to VALUES.
    #'   `rlang::as_label()` produces a display string, which doubles as a
    #'   column name only for bare-column mappings. Evaluating the quosure
    #'   against the data also covers expression aesthetics such as
    #'   `aes(fill = factor(cyl))`, which are idiomatic ggplot2 and which
    #'   the column-name treatment turned into `data[["factor(cyl)"]]`,
    #'   i.e. NULL.
    #' @param plot A ggplot2 object
    #' @param data Data frame the aesthetics are evaluated against
    #' @return List with `x`, `y` and `fill` vectors (any may be NULL)
    resolve_aes_values = function(plot, data) {
      layer_index <- self$get_layer_index()
      layer_mapping <- if (length(plot$layers) >= layer_index) {
        plot$layers[[layer_index]]$mapping
      } else {
        NULL
      }
      plot_mapping <- plot$mapping

      # `[[` avoids the partial matching `$x` would do against xmin/xmax
      quo_for <- function(name) {
        quo <- if (is.null(layer_mapping)) NULL else layer_mapping[[name]]
        if (is.null(quo) && !is.null(plot_mapping)) quo <- plot_mapping[[name]]
        quo
      }

      evaluate <- function(quo) {
        if (is.null(quo)) {
          return(NULL)
        }
        values <- tryCatch(
          rlang::eval_tidy(quo, data = data),
          error = function(e) NULL
        )
        if (is.null(values)) {
          return(NULL)
        }
        # A constant aesthetic (aes(fill = "red")) recycles to every row
        if (length(values) == 1L && nrow(data) > 1L) {
          values <- rep(values, nrow(data))
        }
        if (length(values) != nrow(data)) {
          return(NULL)
        }
        values
      }

      list(
        x = evaluate(quo_for("x")),
        y = evaluate(quo_for("y")),
        fill = evaluate(quo_for("fill"))
      )
    },
    reorder_layer_data = function(data, plot) {
      aes_values <- self$resolve_aes_values(plot, data)
      x_values <- aes_values$x
      fill_values <- aes_values$fill

      if (is.null(x_values) || is.null(fill_values)) {
        return(data)
      }

      x_ordered <- factor(x_values, levels = sort(unique(x_values)))
      fill_ordered <- factor(fill_values, levels = rev(sort(unique(fill_values))))

      data[order(x_ordered, fill_ordered), , drop = FALSE]
    },
    extract_data = function(plot, built = NULL, panel_ctx = NULL) {
      if (!inherits(plot, "ggplot")) {
        stop("Input must be a ggplot object.")
      }

      source_data <- plot$data

      # Facet path: restrict to this panel's facet group(s)
      if (!is.null(panel_ctx) && length(panel_ctx$facet_groups) > 0) {
        for (facet_var in names(panel_ctx$facet_groups)) {
          if (facet_var %in% names(source_data)) {
            source_data <- source_data[
              as.character(source_data[[facet_var]]) ==
                as.character(panel_ctx$facet_groups[[facet_var]]),
              ,
              drop = FALSE
            ]
          }
        }
      }

      aes_values <- self$resolve_aes_values(plot, source_data)
      x_values <- aes_values$x
      y_values <- aes_values$y
      fill_values <- aes_values$fill

      if (is.null(x_values) || is.null(fill_values)) {
        stop("Could not determine required aesthetic mappings")
      }

      # stat = "count" (no y aesthetic): one bar per (x, fill) combination
      # with the row count as its value
      if (is.null(y_values)) {
        x_chr <- as.character(x_values)
        fill_chr <- as.character(fill_values)
        x_levels <- sort(unique(x_chr))
        fill_levels <- sort(unique(fill_chr))
        count_table <- table(x_chr, fill_chr)

        # Only combinations that actually occur get a bar. Emitting the full
        # cartesian product adds zero-count entries that ggplot2 never draws,
        # so the announced data would be longer than the rect list the
        # selector matches and every later bar would be described wrongly.
        series <- lapply(fill_levels, function(fill_name) {
          drawn <- x_levels[count_table[x_levels, fill_name] > 0]
          lapply(drawn, function(x_name) {
            list(
              x = x_name,
              y = as.numeric(count_table[x_name, fill_name]),
              z = fill_name
            )
          })
        })

        return(Filter(function(points) length(points) > 0, series))
      }

      # Split row INDICES rather than the data frame itself: indexing the
      # evaluated aesthetic vectors sidesteps the tibble trap where
      # `df[i, col]` returns a 1x1 tibble that serializes as a nested array
      # instead of a number.
      rows_by_fill <- split(seq_along(fill_values), fill_values)

      lapply(names(rows_by_fill), function(fill_name) {
        rows <- rows_by_fill[[fill_name]]
        rows <- rows[order(x_values[rows])]

        lapply(rows, function(i) {
          list(
            x = as.character(x_values[i]),
            y = as.numeric(y_values[i]),
            z = as.character(fill_values[i])
          )
        })
      })
    },
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL) {
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        panel_index <- which(
          grepl(paste0("^", panel_ctx$panel_name, "\\b"), gt$layout$name)
        )
      } else {
        panel_index <- which(gt$layout$name == "panel")
      }
      if (length(panel_index) == 0) {
        layer_id <- self$get_layer_index()
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        return(list(paste0("#", escaped_grob_id, " rect")))
      }

      panel_grob <- gt$grobs[[panel_index[1]]]

      find_rect_names <- function(grob) {
        names <- character(0)

        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          names <- c(names, grob$name)
        }

        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            names <- c(names, find_rect_names(grob[[i]]))
          }
        }

        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            names <- c(names, find_rect_names(grob$children[[i]]))
          }
        }

        names
      }

      rect_names <- find_rect_names(panel_grob)

      if (length(rect_names) > 0) {
        grob_name <- rect_names[1]
        layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        selector_string <- paste0("#", escaped_grob_id, " rect")
      } else {
        layer_id <- self$get_layer_index()
        grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
        escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
        selector_string <- paste0("#", escaped_grob_id, " rect")
      }

      list(selector_string)
    }
  )
)
