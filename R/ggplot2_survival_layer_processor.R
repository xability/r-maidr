#' ggplot2 Kaplan-Meier Layer Processor
#'
#' @description
#' Reads a [maidr_survival()] layer as the `survival` trace: one series per
#' stratum, each point a row of the layer, with `censored` where a subject
#' left the study at that time and the band's `yMin` and `yMax` when the
#' layer draws it.
#'
#' A Kaplan-Meier curve is a step chart, so the step processor does the
#' work -- the rows in drawn order, the series split, the x and y read back
#' through the scales, `stepDirection` (always `"hv"`). What this adds is
#' what the trace reads that a step does not, and where the curve is.
#'
#' - **Censoring and the band travel with the points.** `GeomSurvival`
#'   names `censored`, `ymin` and `ymax` as aesthetics, so they survive the
#'   build as columns. The rows the step processor emitted points for are
#'   found again by the same panel filter, drawn order, group split and
#'   `NA` span, and each value is put beside its point; a series whose count
#'   disagrees gets nothing rather than another row's.
#' - **The curve is found in the layer's own tree.** `GeomSurvival` draws
#'   its band, curve and marks as one grob tree named after the geom, the
#'   curve a bare polyline with one line per stratum. The tree is found by
#'   the layer's slot in the panel and the polyline inside it, so no other
#'   layer's polyline can be taken for it, nor it for theirs.
#'
#' @keywords internal
Ggplot2SurvivalLayerProcessor <- R6::R6Class(
  "Ggplot2SurvivalLayerProcessor",
  inherit = Ggplot2StepLayerProcessor,
  public = list(
    #' @description Process the Kaplan-Meier layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, title, axes, type and stepDirection
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
      built <- self$in_drawn_order(built)

      # The strata are named from the data the curves are drawn from, which
      # for `maidr_survival(fit)` is the layer's own rather than the plot's.
      own <- tryCatch(self$get_layer(plot)$data, error = function(e) NULL)
      if (is.data.frame(own)) {
        plot$data <- own
      }

      result <- super$process(
        plot, layout, built, gt, grob_id, panel_id, panel_ctx
      )
      result$type <- "survival"
      result$data <- self$attach_survival(
        result$data, built, panel_id,
        band = survival_band_drawn(self$get_layer(plot))
      )
      result
    },

    #' @description Attach each point's censoring and, when the band is
    #'   drawn, its bounds
    #' @param data The series the step processor emitted
    #' @param built Built plot data, in drawn order
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param band Whether the layer draws the band
    #' @return The series, with `censored`, `yMin` and `yMax` where they apply
    attach_survival = function(data, built, panel_id = NULL, band = FALSE) {
      index <- self$get_layer_index()
      if (length(data) == 0L || is.null(built) || is.null(index) ||
        index < 1L || index > length(built$data)) {
        return(data)
      }
      frame <- built$data[[index]]
      if (!is.data.frame(frame) || nrow(frame) == 0L) {
        return(data)
      }
      if (!is.null(panel_id) && "PANEL" %in% names(frame)) {
        frame <- frame[frame$PANEL == panel_id, , drop = FALSE]
      }
      band <- isTRUE(band) && all(c("ymin", "ymax") %in% names(frame))
      if (band) {
        frame$ymin <- untransform_positions(frame$ymin, built, "y", panel_id)
        frame$ymax <- untransform_positions(frame$ymax, built, "y", panel_id)
      }

      # The rows the line processor read, in the order it emitted them:
      # split by group, each kept from its first reading to its last.
      groups <- if ("group" %in% names(frame)) frame$group else rep(1L, nrow(frame))
      per_series <- lapply(split(frame, groups), function(rows) {
        rows[line_drawn_span(rows$y), , drop = FALSE]
      })
      per_series <- Filter(function(rows) nrow(rows) > 0L, per_series)
      if (length(per_series) != length(data)) {
        return(data)
      }

      for (i in seq_along(data)) {
        rows <- per_series[[i]]
        if (nrow(rows) != length(data[[i]])) {
          next
        }
        censored <- survival_censored(rows$censored)
        for (j in seq_len(nrow(rows))) {
          if (length(censored) && censored[[j]]) {
            data[[i]][[j]]$censored <- TRUE
          }
          if (band && is.finite(rows$ymin[[j]]) && is.finite(rows$ymax[[j]])) {
            data[[i]][[j]]$yMin <- rows$ymin[[j]]
            data[[i]][[j]]$yMax <- rows$ymax[[j]]
          }
        }
      }
      data
    },

    #' @description The curve's polyline, inside this layer's own grob tree
    #' @param plot The ggplot2 object
    #' @param panel_grob The panel's grob tree
    #' @param target Index of the layer to find; defaults to this one's
    #' @return The polyline grob, or NULL when the tree holds anything but one
    find_layer_polyline_grob = function(plot, panel_grob, target = NULL) {
      if (is.null(target)) {
        target <- self$get_layer_index()
      }
      tree <- find_layer_slot_grob(panel_grob, target)
      if (is.null(tree) || is.null(tree$name) ||
        !startsWith(tree$name, "geom_survival.")) {
        return(NULL)
      }
      lines <- polylines_within(tree)
      if (length(lines) == 1L) lines[[1]] else NULL
    }
  )
)

#' Whether a Kaplan-Meier layer draws its confidence band
#'
#' @param layer A [maidr_survival()] layer, or one a survminer figure was
#'   redrawn as
#' @return TRUE or FALSE
#' @keywords internal
survival_band_drawn <- function(layer) {
  if (is.null(layer)) {
    return(FALSE)
  }
  isTRUE(tryCatch(layer$geom_params$conf.int, error = function(e) NULL))
}

#' The ggplot2 figure maidr reads from a `survminer::ggsurvplot()` object
#'
#' survminer draws a Kaplan-Meier figure as a `geom_step()` of the curves, a
#' stepped ribbon of the band (its own `GeomConfint`) and a `geom_point()`
#' of the censored times, all from one data frame that carries `time`,
#' `surv`, `n.censor`, `lower` and `upper`. Those three layers are redrawn as
#' one [maidr_survival()] layer from that frame -- the band at survminer's
#' opacity and the marks in its shape and size -- so the figure is read as
#' a `survival` layer rather than as a step, an unreadable ribbon and a
#' scatter of the censored times.
#'
#' Anything else is handed back as the figure's plot unchanged: a figure
#' with no single curve layer, a band drawn some other way
#' (`conf.int.style = "step"`), or a curve that does not fall
#' (`fun = "event"`, `"cumhaz"`), which is not a survival probability. The
#' risk table and the other parts of the object are not read, and a message
#' says so when there is one.
#'
#' @param x Any object
#' @return `x`, or for a `ggsurvplot` object the ggplot to read
#' @keywords internal
ggsurvplot_as_ggplot <- function(x) {
  if (!inherits(x, "ggsurvplot") || !inherits(x$plot, "ggplot")) {
    return(x)
  }
  if (any(vapply(c("table", "ncensor.plot"), function(part) {
    inherits(x[[part]], "ggplot")
  }, logical(1)))) {
    message(
      "maidr reads the survival curves of a ggsurvplot figure; its risk ",
      "table and censoring plot are not shown."
    )
  }

  plot <- x$plot
  rows <- plot$data
  geoms <- vapply(plot$layers, function(layer) class(layer$geom)[1], "")
  curve <- which(geoms == "GeomStep")
  band <- which(geoms == "GeomConfint")
  marks <- which(geoms == "GeomPoint" & vapply(plot$layers, function(layer) {
    is.data.frame(layer$data) && "n.censor" %in% names(layer$data)
  }, logical(1)))
  readable <- is.data.frame(rows) && length(curve) == 1L &&
    length(band) <= 1L && length(marks) <= 1L &&
    all(c("time", "surv", "n.censor") %in% names(rows)) &&
    ggsurvplot_falls(rows)
  if (!readable) {
    return(plot)
  }
  if (!all(c("lower", "upper") %in% names(rows))) {
    band <- integer(0)
  }

  plot$layers[[curve]] <- ggsurvplot_curve_layer(
    plot$layers[[curve]],
    band = if (length(band)) plot$layers[[band]],
    marks = if (length(marks)) plot$layers[[marks]]
  )
  plot$layers[c(band, marks)] <- NULL
  plot
}

#' A survminer figure's curve layer, redrawn with its band and marks
#'
#' A child of the figure's own `geom_step()` layer -- its data, mapping and
#' fixed aesthetics -- drawn by `GeomSurvival`, with `censored` read from
#' `n.censor`, the band from `lower` and `upper` at the band layer's
#' opacity and fill, and the marks in the mark layer's shape and size.
#'
#' @param curve The figure's `geom_step()` layer
#' @param band Its `GeomConfint` layer, or NULL
#' @param marks Its `geom_point()` layer of the censored times, or NULL
#' @return A layer
#' @keywords internal
ggsurvplot_curve_layer <- function(curve, band = NULL, marks = NULL) {
  column <- function(name) rlang::new_quosure(rlang::sym(name), rlang::empty_env())
  mapping <- curve$mapping
  mapping$censored <- column("n.censor")
  params <- list(
    conf.int = !is.null(band),
    censor = !is.null(marks),
    na.rm = isTRUE(curve$geom_params$na.rm)
  )
  if (!is.null(band)) {
    mapping$ymin <- column("lower")
    mapping$ymax <- column("upper")
    if (!is.null(band$mapping$fill)) {
      mapping$fill <- band$mapping$fill
    }
    alpha <- band$aes_params$alpha
    params$conf.int.alpha <- if (is.numeric(alpha)) alpha[1] else 0.3
  }
  if (!is.null(marks)) {
    shape <- marks$aes_params$shape
    size <- marks$aes_params$size
    if (length(shape) == 1L) params$censor.shape <- shape
    if (is.numeric(size) && length(size) == 1L) params$censor.size <- size
  }

  ggplot2::ggproto(
    NULL, curve,
    geom = GeomSurvival,
    mapping = mapping,
    geom_params = params
  )
}

#' Whether each curve of a survminer figure falls from where it starts
#'
#' A survival estimate never rises. A curve that does -- `fun = "event"` or
#' `"cumhaz"` -- is not one, and is not read as one.
#'
#' @param rows The figure's data
#' @return TRUE or FALSE
#' @keywords internal
ggsurvplot_falls <- function(rows) {
  strata <- if ("strata" %in% names(rows)) rows$strata else rep(1L, nrow(rows))
  all(vapply(split(rows, strata), function(curve) {
    surv <- curve$surv[order(curve$time)]
    surv <- surv[is.finite(surv)]
    length(surv) > 0L && all(diff(surv) <= 1e-12)
  }, logical(1)))
}
