# The ggplot2 side of the `survival` layer. Base R reads `plot()` of a
# `survfit` object from the object (`R/base_r_survfit_layer_processor.R`);
# ggplot2 has no Kaplan-Meier geom of its own, so a curve is either a
# `geom_step()` -- which says nothing about censoring or the band -- or
# survminer's figure. `maidr_survival()` declares one the way `maidr_roc()`
# and `maidr_volcano()` do: a geom of its own, identified by
# `class(layer$geom)[1]` in `R/ggplot2_adapter.R`, whose optional aesthetics
# carry what a step has no column for (`censored`, and the band's `ymin` and
# `ymax`) through `ggplot_build()`.
#
# Unlike those, the geom draws more than its parent: the band and the
# censoring marks belong to the curve, so they are drawn by the same layer
# rather than by sibling layers that would each need a rule to be left out of
# the reading. Everything it draws sits in one grob tree named after the
# geom, so the processor finds its polyline by the layer's slot in the panel
# and no other layer can count it as its own.

#' A step geom for Kaplan-Meier curves
#'
#' `ggplot2::GeomStep` drawn `"hv"`, as a survival estimate is held until the
#' next event, with three optional aesthetics -- `ymin`, `ymax` and
#' `censored` -- and, from them, the confidence band beneath the curve and a
#' mark at each censored time. The band, the curve and the marks are one
#' grob tree named `geom_survival`, the curve a bare polyline inside it with
#' one line per group.
#'
#' @format A ggproto object inheriting from `ggplot2::GeomStep`
#' @keywords internal
GeomSurvival <- ggplot2::ggproto(
  "GeomSurvival",
  ggplot2::GeomStep,
  optional_aes = c("ymin", "ymax", "censored"),
  default_aes = ggplot2::aes(
    colour = "black",
    linewidth = 0.5,
    linetype = 1,
    alpha = NA,
    fill = NA
  ),
  draw_key = ggplot2::draw_key_path,
  draw_panel = function(self,
                        data,
                        panel_params,
                        coord,
                        conf.int = FALSE,
                        conf.int.alpha = 0.2,
                        censor = TRUE,
                        censor.shape = 3,
                        censor.size = 3,
                        lineend = "butt",
                        linejoin = "round",
                        linemitre = 10,
                        na.rm = FALSE) {
    if (nrow(data) == 0L) {
      return(ggplot2::zeroGrob())
    }
    data <- data[order(data$group, data$x), , drop = FALSE]
    groups <- split(data, data$group)

    band <- if (isTRUE(conf.int)) {
      survival_band_grob(groups, panel_params, coord, conf.int.alpha)
    }
    line <- ggplot2::ggproto_parent(ggplot2::GeomPath, self)$draw_panel(
      do.call(rbind, lapply(groups, survival_stairstep)),
      panel_params,
      coord,
      lineend = lineend,
      linejoin = linejoin,
      linemitre = linemitre,
      na.rm = na.rm
    )
    marks <- if (isTRUE(censor)) {
      survival_censor_grob(data, panel_params, coord, censor.shape, censor.size)
    }

    children <- Filter(Negate(is.null), list(band, line, marks))
    tree <- grid::gTree(children = do.call(grid::gList, children))
    tree$name <- grid::grobName(tree, "geom_survival")
    tree
  }
)

#' One group's rows as the `"hv"` staircase a survival curve is drawn as
#'
#' The estimate holds from each time to the next and drops there, so the
#' `n` rows become `2n - 1` vertices: ggplot2's own `"hv"` stairstep, every
#' column but `y` taken from the row the vertex's x belongs to.
#'
#' @param rows One group's rows, sorted by x
#' @param y The column the staircase holds level, `"y"` unless a band edge
#' @return The staircase's rows
#' @keywords internal
survival_stairstep <- function(rows, y = "y") {
  n <- nrow(rows)
  if (n < 2L) {
    return(rows)
  }
  xs <- c(1L, rep(seq.int(2L, n), each = 2L))
  ys <- rep(seq_len(n), each = 2L)[-2L * n]
  out <- rows[xs, , drop = FALSE]
  out[[y]] <- rows[[y]][ys]
  rownames(out) <- NULL
  out
}

#' The confidence band beneath the curves, stepped as they are
#'
#' One polygon per group from its rows with both bounds, filled with the
#' group's `fill` or, when none is mapped, its `colour`.
#'
#' @param groups The panel's rows, split by group and sorted by x
#' @param panel_params,coord The panel's, as handed to `draw_panel()`
#' @param alpha The band's opacity
#' @return A polygon grob, or NULL when no group has a band
#' @keywords internal
survival_band_grob <- function(groups, panel_params, coord, alpha) {
  if (!all(c("ymin", "ymax") %in% names(groups[[1]]))) {
    return(NULL)
  }
  pieces <- lapply(seq_along(groups), function(i) {
    rows <- groups[[i]]
    rows <- rows[is.finite(rows$ymin) & is.finite(rows$ymax), , drop = FALSE]
    if (nrow(rows) < 2L) {
      return(NULL)
    }
    lower <- survival_stairstep(rows, "ymin")
    upper <- survival_stairstep(rows, "ymax")
    fill <- if (!is.na(rows$fill[1])) rows$fill[1] else rows$colour[1]
    list(
      frame = data.frame(
        x = c(upper$x, rev(lower$x)),
        y = c(upper$ymax, rev(lower$ymin)),
        id = i
      ),
      fill = ggplot2::alpha(fill, alpha)
    )
  })
  pieces <- Filter(Negate(is.null), pieces)
  if (length(pieces) == 0L) {
    return(NULL)
  }
  frame <- coord$transform(
    do.call(rbind, lapply(pieces, `[[`, "frame")),
    panel_params
  )
  grid::polygonGrob(
    frame$x, frame$y,
    id = frame$id,
    default.units = "native",
    gp = grid::gpar(
      fill = vapply(pieces, `[[`, "", "fill"),
      col = NA
    ),
    name = grid::grobName(prefix = "geom_survival_band")
  )
}

#' The marks at the censored times, on the curve
#'
#' @param data The panel's rows
#' @param panel_params,coord The panel's, as handed to `draw_panel()`
#' @param shape,size The marks' plotting character and size, in ggplot2's
#'   units
#' @return A points grob, or NULL when no row is censored
#' @keywords internal
survival_censor_grob <- function(data, panel_params, coord, shape, size) {
  if (!("censored" %in% names(data))) {
    return(NULL)
  }
  rows <- data[survival_censored(data$censored), , drop = FALSE]
  if (nrow(rows) == 0L) {
    return(NULL)
  }
  rows <- coord$transform(rows, panel_params)
  stroke <- 0.5
  grid::pointsGrob(
    rows$x, rows$y,
    pch = shape,
    default.units = "native",
    gp = grid::gpar(
      col = ggplot2::alpha(rows$colour, rows$alpha),
      fontsize = size * ggplot2::.pt + stroke * ggplot2::.stroke / 2,
      lwd = stroke * ggplot2::.stroke / 2
    ),
    name = grid::grobName(prefix = "geom_survival_censor")
  )
}

#' Which values of a `censored` aesthetic mark a censored time
#'
#' `TRUE`, or a positive count -- `n.censor`, as `survfit()` and survminer
#' keep it -- and nothing else; a missing value is not censored.
#'
#' @param values The column
#' @return Logical vector
#' @keywords internal
survival_censored <- function(values) {
  if (is.null(values)) {
    return(logical(0))
  }
  if (is.factor(values) || is.character(values)) {
    values <- as.logical(as.character(values))
  }
  out <- if (is.logical(values)) values else suppressWarnings(as.numeric(values)) > 0
  !is.na(out) & out
}

#' The rows `maidr_survival()` draws from a `survfit` object
#'
#' The curves `plot()` of the object draws, as [survfit_frame()] reads them,
#' under the names the axes and legend are titled by: `Time`,
#' `Survival probability`, `lower`, `upper`, `censored` and, with strata,
#' `Stratum`, a factor in the object's own order.
#'
#' @param fit A `survfit` object
#' @return A data frame
#' @keywords internal
survfit_plot_frame <- function(fit) {
  if (!survfit_readable(fit)) {
    stop(
      "maidr_survival() draws a `survfit` object of Kaplan-Meier curves, one ",
      "per stratum, and needs survival 3.0 or later. A multi-state fit, or a ",
      "fit with several curves per stratum, is not one.",
      call. = FALSE
    )
  }
  rows <- survfit_frame(fit)
  frame <- data.frame(
    Time = rows$time,
    `Survival probability` = rows$surv,
    lower = rows$lower,
    upper = rows$upper,
    censored = rows$censored,
    check.names = FALSE
  )
  labels <- attr(rows, "strata")
  if (!is.null(labels)) {
    frame$Stratum <- factor(labels[rows$stratum], levels = labels)
  }
  frame[is.finite(frame$Time) & is.finite(frame[["Survival probability"]]), ,
    drop = FALSE
  ]
}

#' Declare a Kaplan-Meier curve
#'
#' @description
#' `maidr_survival()` draws Kaplan-Meier survival curves -- one per stratum,
#' each held level until an event drops it -- and declares them as such, so
#' that maidr reads them as a `survival` layer: each time announced with its
#' survival estimate and, when the band is drawn, its confidence interval,
#' the times a subject was censored marked so a reader can step between
#' them with the rotor, and the median survival of each curve in the
#' description. The same staircase drawn with `geom_step()` reads as a step
#' chart, which announces the levels and nothing of the censoring that says
#' how much of the curve the data still supports.
#'
#' Give it a `survival::survfit` object and it draws the curves `plot()` of
#' that object would: `ggplot() + maidr_survival(fit)`. Give it data and
#' aesthetics and it draws them as they are, as any geom does.
#'
#' The `survival` layer type \[experimental\] is one of the experimental plot
#' types: it has not been through a user study, and its reading may change
#' without a deprecation period. See "Experimental Plot Types" in the README.
#'
#' @details
#' # From a `survfit` object
#'
#' The curves start at the origin `survival::survfit0()` adds, as `plot()`
#' starts them, and run to each stratum's last time. The layer draws from a
#' data frame of its own, with the columns `Time`, `Survival probability`,
#' `lower`, `upper`, `censored` and, for a fit with strata, `Stratum`, which
#' are what the axes and the legend are titled by; map further aesthetics
#' onto them, `maidr_survival(fit, aes(linetype = Stratum))`, and retitle
#' with `ggplot2::labs()`. The plot's own aesthetics are not inherited. A
#' multi-state fit, or one with several curves per stratum (`survfit()` of
#' a Cox model over several new subjects), is an error: neither is one
#' survival curve per stratum.
#'
#' # From data
#'
#' `x` is the time and `y` the survival estimate, one row per time at which
#' the estimate is reported, and the strata are groups, split by `colour`,
#' `linetype` or `group` as the series of a line chart are. `censored` marks
#' the times a subject left the study without the event: `TRUE`, or a count
#' greater than zero such as a `survfit` summary's `n.censor`. `ymin` and
#' `ymax` are the band's bounds at each time, drawn and read only with
#' `conf.int = TRUE`.
#'
#' # What is read
#'
#' One series per stratum, each point a row: the time, the estimate,
#' `censored` where the row is censored, and, when the band is drawn,
#' `yMin` and `yMax`. Censoring is read whether or not the marks are drawn,
#' as it is from a Base R plot: it is part of the estimate, not of its
#' decoration.
#'
#' # survminer
#'
#' A figure from `survminer::ggsurvplot()` is read the same way when it is
#' handed to [show()] or [save_html()] as it stands: its curve, band and
#' censoring marks are redrawn as one `maidr_survival()` layer from the data
#' the figure carries. The risk table, and a figure whose curve is not a
#' survival probability (`fun = "event"` or `"cumhaz"`), are not read; the
#' first is left out, the second keeps the reading `geom_step()` has.
#'
#' @param mapping Aesthetics, as for [ggplot2::geom_step()]: `x` (the time)
#'   and `y` (the survival estimate) are required, and `ymin`, `ymax` and
#'   `censored` may be mapped as described in Details. Or a `survfit`
#'   object, drawn as described there.
#' @param data The layer's data, as for [ggplot2::geom_step()], or a
#'   `survfit` object. When `mapping` is the `survfit` object, `data` may be
#'   further aesthetics.
#' @param position Position adjustment, as for [ggplot2::geom_step()].
#' @param ... Other arguments passed to the layer, such as `linewidth` or
#'   a fixed `colour` -- except `stat`, which is fixed at `"identity"`.
#' @param conf.int Whether to draw the confidence band from `ymin` and
#'   `ymax` (from the object's own bounds, for a `survfit`), and read it as
#'   each point's `yMin` and `yMax`. `FALSE` by default.
#' @param conf.int.alpha The band's opacity.
#' @param censor Whether to draw a mark at each censored time. Censoring is
#'   read either way.
#' @param censor.shape,censor.size The marks' plotting character and size,
#'   as `shape` and `size` are given to [ggplot2::geom_point()].
#' @param na.rm If `FALSE` (the default), rows with missing values are
#'   removed with a warning.
#' @param show.legend Whether this layer is included in the legends.
#' @param inherit.aes If `FALSE`, the plot's default aesthetics are not
#'   inherited. Always `FALSE` for a `survfit` object.
#'
#' @return A ggplot2 layer, to be added to a plot with `+`.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE) &&
#'   requireNamespace("survival", quietly = TRUE)) {
#'   fit <- survival::survfit(
#'     survival::Surv(time, status) ~ sex,
#'     data = survival::lung
#'   )
#'
#'   km <- ggplot2::ggplot() +
#'     maidr_survival(fit, conf.int = TRUE) +
#'     ggplot2::labs(x = "Days", title = "Survival by sex")
#'
#'   # The same curves drawn with `geom_step()` read as a step chart: the
#'   # levels, and nothing of who was censored.
#'   if (interactive()) {
#'     show(km)
#'   }
#' }
#'
#' @seealso [maidr_roc()] and [maidr_volcano()], the other declarations;
#'   [save_html()] and [show()] for rendering the declared chart
#' @export
maidr_survival <- function(mapping = NULL,
                           data = NULL,
                           position = "identity",
                           ...,
                           conf.int = FALSE,
                           conf.int.alpha = 0.2,
                           censor = TRUE,
                           censor.shape = 3,
                           censor.size = 3,
                           na.rm = FALSE,
                           show.legend = NA,
                           inherit.aes = TRUE) {
  fit <- NULL
  if (inherits(mapping, "survfit")) {
    fit <- mapping
    mapping <- if (inherits(data, "uneval")) data
  } else if (inherits(data, "survfit")) {
    fit <- data
  }

  if (!is.null(fit)) {
    data <- survfit_plot_frame(fit)
    # The labels ggplot2 derives from a mapping are its expressions, so the
    # columns are named for what the axes and legend should say.
    drawn <- list(
      x = rlang::sym("Time"),
      y = rlang::sym("Survival probability"),
      ymin = rlang::sym("lower"),
      ymax = rlang::sym("upper"),
      censored = rlang::sym("censored")
    )
    if ("Stratum" %in% names(data)) {
      drawn$colour <- rlang::sym("Stratum")
    }
    drawn[names(mapping)] <- NULL
    mapping <- do.call(ggplot2::aes, c(drawn, unclass(mapping)))
    inherit.aes <- FALSE
  }

  layer <- ggplot2::layer(
    stat = "identity",
    geom = GeomSurvival,
    data = data,
    mapping = mapping,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(
      conf.int = isTRUE(conf.int),
      conf.int.alpha = conf.int.alpha,
      censor = isTRUE(censor),
      censor.shape = censor.shape,
      censor.size = censor.size,
      na.rm = na.rm,
      ...
    )
  )
  survival_censoring_ungrouped(layer)
}

#' A layer whose `censored` aesthetic does not split its curves
#'
#' ggplot2 groups a layer's rows by every discrete aesthetic, and a logical
#' is discrete: `aes(censored = status == 0)` would cut each curve in two,
#' its censored rows one curve and the rest another. The layer's aesthetics
#' are computed as ggplot2 computes them, and then, unless `group` is
#' mapped, grouped again without `censored`, which is made a number (1 for
#' a censored time) so nothing further groups by it.
#'
#' @param layer A layer drawn with `GeomSurvival`
#' @return A child of the layer that groups so
#' @keywords internal
survival_censoring_ungrouped <- function(layer) {
  parent <- layer
  ggplot2::ggproto(
    NULL, parent,
    compute_aesthetics = function(self, data, plot) {
      out <- ggplot2::ggproto_parent(parent, self)$compute_aesthetics(data, plot)
      if (!is.data.frame(out) || !("censored" %in% names(out)) ||
        is.numeric(out$censored)) {
        return(out)
      }
      out$censored <- as.numeric(survival_censored(out$censored))
      mapped <- names(tryCatch(self$computed_mapping, error = function(e) NULL))
      if (!("group" %in% mapped) && nrow(out) > 0L) {
        discrete <- vapply(out, function(column) {
          is.factor(column) || is.character(column) || is.logical(column)
        }, logical(1))
        discrete[names(out) %in% c("label", "PANEL", "group")] <- FALSE
        # ggplot2's own numbering: by each discrete column's levels, or its
        # sorted values, the first column the most significant.
        out$group <- if (any(discrete)) {
          as.integer(interaction(
            lapply(out[discrete], function(column) {
              if (is.factor(column)) droplevels(column) else factor(column)
            }),
            drop = TRUE,
            lex.order = TRUE
          ))
        } else {
          -1L
        }
      }
      out
    }
  )
}
