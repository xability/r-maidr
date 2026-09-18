#' ROC Curve Layer Processor
#'
#' @description
#' Reads a receiver operating characteristic curve -- a classifier's true
#' positive rate against its false positive rate, one point per decision
#' threshold, one curve per classifier -- as the `roc` trace.
#'
#' Structurally a multi-series line, so the line processor does the work: the
#' series split, the x recovery through the scale, the selectors per drawn
#' polyline. What this adds is what the trace reads that a line does not.
#'
#' - **The rates are numbers.** The line processor formats x for
#'   announcement, which turns a rate into a string; the core's ROC trace
#'   measures the area under the curve and each point's height above the
#'   chance diagonal from `x`, so it is handed back as a number.
#' - **`x` is the false positive rate.** [pROC::ggroc()] maps `specificity`
#'   on a reversed axis, which draws the same picture as `1 - specificity`
#'   on an ordinary one and reads as the opposite: every point would be
#'   measured below the diagonal it sits above. The rate is inverted and the
#'   axis named for what is announced.
#' - **Thresholds and areas travel with the points.** A `maidr_roc()` layer's
#'   `threshold` aesthetic survives the build as a column, and its `auc`
#'   argument names the areas; each is attached to the points of the series
#'   it belongs to, the threshold per point and the area on the first point
#'   of its curve, which is where the core reads it.
#'
#' Emitted with `type = "roc"`, which the core has read since maidr 4.9.0.
#'
#' @keywords internal
Ggplot2RocLayerProcessor <- R6::R6Class(
  "Ggplot2RocLayerProcessor",
  inherit = Ggplot2LineLayerProcessor,
  public = list(
    #' @description Process the ROC layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, title, axes and type
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      result <- super$process(
        plot, layout, built, gt, grob_id, panel_id, panel_ctx
      )
      result$type <- "roc"

      layer <- self$get_layer(plot)
      inverted <- roc_x_is_specificity(layer, plot)

      result$data <- self$as_rates(result$data, inverted)
      result$data <- self$attach_thresholds(result$data, built, panel_id)
      result$data <- self$attach_areas(result$data, layer)

      if (inverted && is.list(result$axes$x) &&
        is.character(result$axes$x$label) && nzchar(result$axes$x$label)) {
        # Named for what is announced. The axis on the page says
        # "specificity" and runs from 1 to 0; the rate a reader hears runs
        # the other way, and calling it by the axis's name would put "0.2"
        # under a label whose tick reads 0.8.
        result$axes$x$label <- paste("1 -", result$axes$x$label)
      }

      result
    },

    #' @description Hand the rates back as numbers, inverting `x` when asked
    #'
    #' The line processor stringifies `x` on the way out, because a line's x
    #' may be a date or a category. A rate is neither, and the core does
    #' arithmetic on it.
    #'
    #' @param data The series list the line processor emitted
    #' @param inverted Whether `x` is specificity, to be read as `1 - x`
    #' @return The series list with numeric rates
    as_rates = function(data, inverted = FALSE) {
      lapply(data, function(series) {
        lapply(series, function(point) {
          x <- suppressWarnings(as.numeric(point$x))
          if (length(x) == 1L && is.finite(x)) {
            point$x <- if (isTRUE(inverted)) 1 - x else x
          }
          y <- suppressWarnings(as.numeric(point$y))
          if (length(y) == 1L && is.finite(y)) {
            point$y <- y
          }
          point
        })
      })
    },

    #' @description Attach each point's decision threshold, when the layer
    #' carries one
    #'
    #' A `threshold` column survives the build only for a `maidr_roc()`
    #' layer, whose geom names the aesthetic. The line processor drops the
    #' rows whose y is `NA` and splits the rest by group in the group's own
    #' order, so the same filter and split here put the thresholds back
    #' beside the points they were scored at. A series whose count disagrees
    #' -- a row the line processor dropped for a reason other than `NA` y --
    #' gets no thresholds rather than the wrong ones.
    #'
    #' @param data The series list
    #' @param built Built plot data
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return The series list, with `threshold` on each point that has one
    attach_thresholds = function(data, built, panel_id = NULL) {
      frame <- self$rows_read(built, panel_id)
      if (is.null(frame) || !("threshold" %in% names(frame))) {
        return(data)
      }

      per_series <- if ("group" %in% names(frame)) {
        split(frame$threshold, frame$group)
      } else {
        list(frame$threshold)
      }

      # The line processor emits only the groups that kept a row, in the
      # order `split()` gives them.
      per_series <- Filter(function(values) length(values) > 0L, per_series)
      if (length(per_series) != length(data)) {
        return(data)
      }

      for (i in seq_along(data)) {
        thresholds <- per_series[[i]]
        if (length(thresholds) != length(data[[i]])) {
          next
        }
        for (j in seq_along(thresholds)) {
          value <- suppressWarnings(as.numeric(thresholds[[j]]))
          if (length(value) == 1L && is.finite(value)) {
            data[[i]][[j]]$threshold <- value
          }
        }
      }
      data
    },

    #' @description Attach the declared area to the first point of each curve
    #'
    #' `maidr_roc(auc = )` names one area per curve. A named vector is
    #' matched to the series by their names; an unnamed one is taken in
    #' series order when it has one entry per series. Anything else is left
    #' out rather than guessed, and the core measures the area from the
    #' points instead.
    #'
    #' @param data The series list
    #' @param layer The layer being read
    #' @return The series list, with `auc` on each curve's first point
    attach_areas = function(data, layer) {
      areas <- tryCatch(layer$maidr_auc, error = function(e) NULL)
      if (!is.numeric(areas) || length(areas) == 0L || length(data) == 0L) {
        return(data)
      }

      names_of <- vapply(data, function(series) {
        z <- series[[1]]$z
        if (is.null(z)) "" else as.character(z)
      }, character(1))

      matched <- if (!is.null(names(areas)) && all(nzchar(names(areas)))) {
        areas[match(names_of, names(areas))]
      } else if (length(areas) == length(data)) {
        unname(areas)
      } else {
        rep(NA_real_, length(data))
      }

      for (i in seq_along(data)) {
        if (length(data[[i]]) > 0L && is.finite(matched[[i]])) {
          data[[i]][[1]]$auc <- unname(matched[[i]])
        }
      }
      data
    },

    #' @description The built rows the line processor emitted points for
    #'
    #' The same panel filter and `NA`-y filter `extract_data()` applies, so
    #' that a column read off these rows lines up with the emitted points.
    #'
    #' @param built Built plot data
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return The rows, or NULL when the layer built none
    rows_read = function(built, panel_id = NULL) {
      index <- self$get_layer_index()
      if (is.null(built) || is.null(built$data) || is.null(index) ||
        index < 1L || index > length(built$data)) {
        return(NULL)
      }
      frame <- built$data[[index]]
      if (!is.data.frame(frame) || nrow(frame) == 0L) {
        return(NULL)
      }
      if (!is.null(panel_id) && "PANEL" %in% names(frame)) {
        frame <- frame[frame$PANEL == panel_id, , drop = FALSE]
      }
      if ("y" %in% names(frame)) {
        frame <- frame[!is.na(frame$y), , drop = FALSE]
      }
      frame
    }
  )
)

#' The name an aesthetic is mapped to, as the ROC vocabulary would spell it
#'
#' `rlang::as_label()` renders `aes(x = specificity)` as `specificity`,
#' `aes(x = 1 - specificity)` as `1 - specificity`, and the `.data[["1-specificity"]]`
#' that [pROC::ggroc()] writes as `.data[["1-specificity"]]`. Stripping the
#' pronoun and the whitespace makes the three spellings of one rate compare
#' equal.
#'
#' @param mapping An aesthetic mapping, or NULL
#' @param aesthetic Which aesthetic to read
#' @return The normalised name, or NULL when nothing is mapped
#' @keywords internal
roc_mapped_name <- function(mapping, aesthetic) {
  if (is.null(mapping)) {
    return(NULL)
  }
  quo <- tryCatch(mapping[[aesthetic]], error = function(e) NULL)
  if (is.null(quo)) {
    return(NULL)
  }
  label <- tryCatch(rlang::as_label(quo), error = function(e) NULL)
  if (!is.character(label) || length(label) != 1L) {
    return(NULL)
  }
  label <- sub('^\\.data\\[\\["(.*)"\\]\\]$', "\\1", label)
  tolower(gsub("[[:space:]]+", "", label))
}

#' The x and y a layer draws, its own mapping first and the plot's beneath
#'
#' @param layer A ggplot2 layer
#' @param plot_object The plot the layer belongs to
#' @return list(x = , y = ) of normalised names, either NULL when unmapped
#' @keywords internal
roc_layer_rates <- function(layer, plot_object) {
  own <- tryCatch(layer$mapping, error = function(e) NULL)
  inherited <- if (isTRUE(tryCatch(layer$inherit.aes, error = function(e) TRUE))) {
    tryCatch(plot_object$mapping, error = function(e) NULL)
  } else {
    NULL
  }
  read <- function(aesthetic) {
    name <- roc_mapped_name(own, aesthetic)
    if (is.null(name)) name <- roc_mapped_name(inherited, aesthetic)
    name
  }
  list(x = read("x"), y = read("y"))
}

#' Whether a line layer maps the ROC's own vocabulary
#'
#' A ROC curve drawn as `geom_line()` or `geom_path()` carries no evidence of
#' what it means except its column names, and two producers name them after
#' the rates themselves: [pROC::ggroc()] maps `specificity` or
#' `1-specificity` against `sensitivity`, and `ggplot2::autoplot()` of a
#' [yardstick::roc_curve()] maps `1 - specificity` against `sensitivity`.
#' Those names are the claim, and nothing else is read as one -- a line of
#' `fpr` against `tpr` under any other column names is declared with
#' [maidr_roc()] instead, because a rule loose enough to catch it would catch
#' charts that are not ROC curves.
#'
#' @param layer A ggplot2 layer
#' @param plot_object The plot the layer belongs to
#' @return TRUE when the layer's x and y are specificity and sensitivity
#' @keywords internal
layer_maps_roc_rates <- function(layer, plot_object) {
  rates <- roc_layer_rates(layer, plot_object)
  if (is.null(rates$x) || is.null(rates$y)) {
    return(FALSE)
  }
  identical(rates$y, "sensitivity") &&
    rates$x %in% c("specificity", "1-specificity")
}

#' Whether a ROC layer's x is specificity, to be announced as `1 - x`
#'
#' @param layer A ggplot2 layer
#' @param plot_object The plot the layer belongs to
#' @return TRUE only for a detected layer whose x is specificity itself
#' @keywords internal
roc_x_is_specificity <- function(layer, plot_object) {
  if (is.null(layer) || identical(class(layer$geom)[1], "GeomRoc")) {
    return(FALSE)
  }
  identical(roc_layer_rates(layer, plot_object)$x, "specificity")
}
