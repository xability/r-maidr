#' Base R Heatmap Layer Processor
#'
#' Processes Base R heatmap layers using the heatmap() function
#'
#' @keywords internal
BaseRHeatmapLayerProcessor <- R6::R6Class(
  "BaseRHeatmapLayerProcessor",
  inherit = LayerProcessor,
  public = list(
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

      list(
        data = data,
        selectors = selectors,
        type = "heat",
        title = title,
        axes = axes,
        domMapping = list(order = "row") # Explicit row-major DOM mapping
      )
    },
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # The matrix may arrive named (x = m) or positional (m); with only
      # positional args names(args) is NULL, so check both forms.
      heat_matrix <- args[["x"]]
      if (is.null(heat_matrix) && length(args) > 0) {
        arg_names <- names(args)
        unnamed <- if (is.null(arg_names)) {
          seq_along(args)
        } else {
          which(!nzchar(arg_names))
        }
        if (length(unnamed) > 0) {
          heat_matrix <- args[[unnamed[1]]]
        }
      }

      if (is.null(heat_matrix) || !is.matrix(heat_matrix)) {
        return(list(points = list(), x = character(0), y = character(0)))
      }

      function_name <- layer_info$function_name

      # heatmap()/image() put reordered row 1 at the BOTTOM of the y axis,
      # so the top-down grid is the reverse of the matrix. heatmap()'s revC
      # flips the drawing back, and then the matrix already reads top-down.
      reverse_rows <- TRUE
      ordering <- NULL

      if (identical(function_name, "heatmap")) {
        # heatmap() reorders rows/columns by dendrogram (default Rowv/Colv)
        # before drawing; extract the same ordering so announced values
        # match the drawn cells.
        ordering <- self$compute_heatmap_ordering(args)
        if (!is.null(ordering)) {
          heat_matrix <- heat_matrix[
            ordering$rowInd, ordering$colInd,
            drop = FALSE
          ]
        }
        if (heatmap_applies_revc(args)) {
          reverse_rows <- FALSE
        }
      } else if (identical(function_name, "image")) {
        # image(z) draws matrix ROWS along the x-axis and COLUMNS along
        # the y-axis; transpose so the emitted grid matches the visual.
        heat_matrix <- t(heat_matrix)
      }

      row_names <- rownames(heat_matrix)
      col_names <- colnames(heat_matrix)

      # heatmap() resolves each axis in one expression: it takes the
      # caller's own `labRow` subscripted by `rowInd` when there is one,
      # falling back to `rownames(x)` and then to `(1L:nr)[rowInd]`. So the
      # caller's labels come FIRST and beat dimnames, and they carry the same
      # ordering as everything else. `x` is already reordered by the time
      # `rownames(x)` is read, which is why only the first and third arms of
      # that fallback carry a subscript.
      if (identical(function_name, "heatmap")) {
        # When the ordering probe came back empty the matrix was not
        # reordered either, so heatmap()'s subscript is the identity - but it
        # is still a subscript, which is what keeps a mismatched-length
        # labRow from producing more or fewer labels than there are rows
        # (raised in review).
        row_order <- if (is.null(ordering)) {
          seq_len(nrow(heat_matrix))
        } else {
          ordering$rowInd
        }
        col_order <- if (is.null(ordering)) {
          seq_len(ncol(heat_matrix))
        } else {
          ordering$colInd
        }

        caller_rows <- heatmap_caller_labels(args[["labRow"]], row_order)
        if (!is.null(caller_rows)) row_names <- caller_rows
        caller_cols <- heatmap_caller_labels(args[["labCol"]], col_order)
        if (!is.null(caller_cols)) col_names <- caller_cols
      }

      # An unnamed matrix keeps no dimnames through the reorder, so fall back
      # the way heatmap() itself does: it labels the reordered matrix with
      # `(1L:nr)[rowInd]`, i.e. the ORIGINAL indices in drawn order, not with
      # 1..n positions. Only when no ordering was recovered -- or for image(),
      # which never reorders -- is a plain 1..n sequence the drawn label.
      if (is.null(row_names)) {
        row_names <- if (is.null(ordering)) {
          as.character(seq_len(nrow(heat_matrix)))
        } else {
          as.character(ordering$rowInd)
        }
      }
      if (is.null(col_names)) {
        col_names <- if (is.null(ordering)) {
          as.character(seq_len(ncol(heat_matrix)))
        } else {
          as.character(ordering$colInd)
        }
      }

      # points is a 2D array where points[row][col] = value
      points <- list()
      for (i in seq_len(nrow(heat_matrix))) {
        row_values <- list()
        for (j in seq_len(ncol(heat_matrix))) {
          row_values[[j]] <- heat_matrix[i, j]
        }
        points[[i]] <- row_values
      }

      if (reverse_rows) {
        points <- rev(points)
        row_names <- rev(row_names)
      }

      list(
        points = points,
        x = as.list(col_names),
        y = as.list(row_names)
      )
    },

    #' @description Reproduce the row/column ordering heatmap() draws with
    #' @param args Recorded heatmap() arguments
    #' @return List with rowInd/colInd, or NULL if unavailable
    compute_heatmap_ordering = function(args) {
      result <- tryCatch(
        {
          null_pdf <- tempfile(fileext = ".pdf")
          grDevices::pdf(null_pdf)
          on.exit(
            {
              grDevices::dev.off()
              unlink(null_pdf)
            },
            add = TRUE
          )
          # heatmap() has no plot = FALSE: run it on a throwaway device to
          # obtain the exact rowInd/colInd it uses (invisibly returned).
          do.call(stats::heatmap, clean_maidr_args(args))
        },
        error = function(e) NULL
      )

      if (is.null(result) || is.null(result$rowInd) || is.null(result$colInd)) {
        return(NULL)
      }
      result
    },
    generate_selectors = function(layer_info, gt = NULL, extracted_data = NULL) {
      if (is.null(gt)) {
        return(list())
      }

      # Use group_index for grob lookup
      group_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      # Search for image-rect grobs (heatmap creates image-rect patterns)
      selector <- self$generate_selectors_from_grob(gt, group_index)

      if (length(selector) == 0 || !nzchar(selector[1])) {
        # Fallback container id when the grob search finds nothing
        selector <- paste0(
          "g#graphics-plot-",
          group_index,
          "-image-rect-1\\.1 > rect"
        )
      }

      # Preferred form: a per-cell selector grid. The frontend indexes
      # grid[r][c] with logical row 0 = BOTTOM visual row, exactly the
      # order gridSVG emits the image rects in (bottom-to-top,
      # row-major). A bare container selector instead makes the frontend
      # apply its own DOM-order heuristic, which assumes top-to-bottom
      # rects and highlights the vertically mirrored cell.
      n_rows <- length(extracted_data$points)
      n_cols <- if (n_rows > 0) length(extracted_data$points[[1]]) else 0
      if (n_rows > 0 && n_cols > 0) {
        group_selector <- sub(" > rect$", "", selector[1])
        grid <- vector("list", n_rows)
        for (logical_row in seq_len(n_rows)) {
          row_selectors <- vector("list", n_cols)
          for (col in seq_len(n_cols)) {
            child_index <- (logical_row - 1) * n_cols + col
            row_selectors[[col]] <- paste0(
              group_selector, " > rect:nth-child(", child_index, ")"
            )
          }
          grid[[logical_row]] <- row_selectors
        }
        return(grid)
      }

      list(selector)
    },
    find_image_rect_grobs = function(grob, group_index) {
      names <- character(0)

      # Look for graphics-plot pattern matching image-rect
      if (!is.null(grob$name)) {
        pattern <- paste0("graphics-plot-", group_index, "-image-rect-1")
        if (grepl(pattern, grob$name)) {
          names <- c(names, grob$name)
        }
      }

      # Recursively search through gList
      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_image_rect_grobs(grob[[i]], group_index))
        }
      }

      # Recursively search through gTree children
      if (inherits(grob, "gTree")) {
        if (!is.null(grob$children)) {
          for (i in seq_along(grob$children)) {
            names <- c(
              names,
              self$find_image_rect_grobs(grob$children[[i]], group_index)
            )
          }
        }
      }

      # Also check grobs field
      if (!is.null(grob$grobs)) {
        for (i in seq_along(grob$grobs)) {
          names <- c(names, self$find_image_rect_grobs(grob$grobs[[i]], group_index))
        }
      }

      names
    },
    generate_selectors_from_grob = function(grob, group_index = NULL) {
      rect_names <- self$find_image_rect_grobs(grob, group_index)

      if (length(rect_names) == 0) {
        return("")
      }

      # Take first matching grob name
      name <- rect_names[1]
      svg_id <- paste0(name, ".1")
      escaped <- gsub("\\.", "\\\\.", svg_id)
      selector <- paste0("g#", escaped, " > rect")

      selector
    },
    # Extract the axis titles for this layer
    #
    # `heatmap()` lays the matrix out one way round only -- its columns run
    # along x and its rows up y -- so those two words are facts about the
    # call. `image()` is not the same picture: it draws a coordinate grid,
    # and `image(x, y, z)` puts the caller's own coordinates on those axes,
    # so naming them after a matrix would be a guess. It gets no default.
    #
    # @param layer_info Layer information
    # @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      args <- layer_info$plot_call$args
      is_heatmap <- identical(layer_info$function_name, "heatmap")

      build_axes(
        x = recorded_axis_label(args, "xlab", if (is_heatmap) "Columns" else NULL),
        y = recorded_axis_label(args, "ylab", if (is_heatmap) "Rows" else NULL),
        # For heatmaps, z represents the data values
        # Use a reasonable default label for the color scale
        z = "value"
      )
    },
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

#' Does This heatmap() Call Apply revC?
#'
#' `heatmap()` normally puts reordered row 1 at the bottom of the y axis, but
#' its `revC` argument flips the drawing so row 1 lands at the top. `revC` is
#' not part of the ordering `heatmap()` returns, and it defaults to
#' `identical(Colv, "Rowv")` -- which is TRUE for every `symm = TRUE` call,
#' since `Colv` itself defaults to `"Rowv"` there.
#'
#' @param args Recorded heatmap() arguments
#' @return TRUE when `revC` applies, i.e. the drawn rows read top-down
#' @keywords internal
heatmap_applies_revc <- function(args) {
  matched <- tryCatch(
    {
      call <- as.call(c(list(quote(stats::heatmap)), clean_maidr_args(args)))
      as.list(match.call(stats::heatmap, call))[-1]
    },
    error = function(e) NULL
  )
  if (is.null(matched)) {
    return(FALSE)
  }

  if ("revC" %in% names(matched)) {
    return(isTRUE(matched$revC))
  }

  colv <- if ("Colv" %in% names(matched)) {
    matched$Colv
  } else if (isTRUE(matched$symm)) {
    "Rowv"
  } else {
    NULL
  }
  identical(colv, "Rowv")
}

#' Resolve a heatmap()'s Caller-Supplied Axis Labels
#'
#' `heatmap()` gives an explicit `labRow=`/`labCol=` priority over the
#' matrix's own dimnames, and subscripts it by the same ordering it applies to
#' the data: `labRow[rowInd] %||% rownames(x) %||% (1L:nr)[rowInd]`. Reading
#' the labels off the reordered matrix therefore announced the dimnames -- or,
#' for an unnamed matrix, bare indices -- while the axis showed the caller's
#' strings.
#'
#' A short or `NA`-carrying vector is passed through rather than rejected:
#' `labRow[rowInd]` yields `NA` for the positions it cannot fill, and grid
#' draws that as the glyphs "NA", so mirroring it keeps the announcement equal
#' to the picture. Subscripting is also what holds the result to one label per
#' row: a caller who supplies too many gets the surplus dropped, exactly as
#' `heatmap()` drops it.
#'
#' @param labels The recorded `labRow=` or `labCol=` argument, or NULL
#' @param ordering The matching `rowInd`/`colInd`. Never NULL: when no
#'   ordering was recovered the caller passes the identity, because
#'   `heatmap()` applies a subscript either way
#' @return Character vector in drawn order, or NULL when the caller supplied
#'   no labels for this axis
#' @keywords internal
heatmap_caller_labels <- function(labels, ordering) {
  if (is.null(labels)) {
    return(NULL)
  }
  as.character(labels[ordering])
}
