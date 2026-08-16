#' Smooth Layer Processor
#'
#' Processes smooth plot layers with complete logic included
#'
#' @keywords internal
Ggplot2SmoothLayerProcessor <- R6::R6Class(
  "Ggplot2SmoothLayerProcessor",
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
      data <- self$extract_data(plot, built, panel_id = panel_id)
      selectors <- self$generate_selectors(
        plot, gt,
        panel_ctx = panel_ctx, built = built, panel_id = panel_id
      )

      axes <- self$extract_layer_axes(plot, layout)
      axes <- self$attach_group_axis(plot, built, data, axes)

      title <- if (!is.null(layout$title)) layout$title else ""
      smooth_layer <- list(
        data = data,
        selectors = selectors,
        title = title,
        axes = axes
      )

      smooth_layer
    },


    #' @description Whether this layer's \code{ymin}/\code{ymax} are an
    #' interval at all.
    #'
    #' Asked of the **stat**, never of the columns, because the columns lie.
    #' This processor serves \code{StatSmooth} and \code{StatDensity} alike,
    #' and both emit \code{ymin}/\code{ymax} while meaning different things:
    #' \code{StatSmooth} computes the confidence bounds around the fit, but
    #' \code{StatDensity} sets \code{ymin = 0} and \code{ymax = density} --
    #' the extent of the fill, not an uncertainty. Measured on a three-group
    #' \code{geom_density()}: all 1536 rows carry finite bounds running from
    #' zero to the curve.
    #'
    #' Reading those as an interval would announce every density curve as
    #' having a confidence band from zero, which is a claim about the data
    #' rather than a missing feature -- the worse of the two failures, and
    #' the one this guard exists to prevent.
    #'
    #' @param plot The ggplot2 object
    #' @return TRUE when the layer's stat computes an interval
    layer_computes_interval = function(plot) {
      # `resolve_target_layer()` answers with an *index*, which is what the
      # rest of this class threads around; the layer object is one lookup
      # further on.
      index <- self$resolve_target_layer(plot)
      if (is.null(index) || is.null(plot$layers) ||
        index < 1L || index > length(plot$layers)) {
        return(FALSE)
      }
      layer <- plot$layers[[index]]
      if (is.null(layer$stat)) {
        return(FALSE)
      }
      identical(class(layer$stat)[1], "StatSmooth")
    },


    #' @description Grouping aesthetics that split this layer into curves.
    #'
    #' \code{geom_smooth()} and \code{geom_density()} both render a fill, so
    #' \code{aes(fill = g)} splits them into one curve per group just as
    #' \code{aes(colour = g)} does. The line processor probes colour only,
    #' because a line has no fill and reading one from an unrelated layer's
    #' mapping would invent a legend the plot never draws.
    #'
    #' \code{Ggplot2Adapter} types a layer as \code{smooth} for
    #' \code{GeomSmooth} or for any layer whose stat is \code{StatDensity}.
    #' A default \code{geom_area()} uses \code{StatAlign} and so never
    #' arrives here, but \code{geom_area(stat = "density")} does, and splits
    #' per group like the others.
    #'
    #' @return List of aesthetic-name vectors, in precedence order
    group_aes = function() {
      list(c("colour", "color"), "fill")
    },

    #' @description Add the legend title as the z axis label when the layer is
    #' split into per-group curves.
    #'
    #' Shared with the line layer processor via
    #' \code{attach_series_group_axis()}; see \code{R/series_group_utils.R}.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param data The extracted layer data
    #' @param axes Axes built so far
    #' @return The axes list, with z added when the layer is grouped
    attach_group_axis = function(plot, built, data, axes) {
      if (!data_has_series_groups(data)) {
        return(axes)
      }
      attach_series_group_axis(
        axes, plot, built, data,
        layer_index = self$resolve_target_layer(plot),
        aes_groups = self$group_aes()
      )
    },

    #' @description Resolve which layer of the plot this processor describes.
    #'
    #' Prefers this processor's OWN layer: picking the first line-like layer
    #' would extract another layer's data in multi-layer plots (e.g.
    #' geom_line + geom_smooth).
    #'
    #' @param plot The ggplot2 object
    #' @return Index into \code{plot$layers}
    resolve_target_layer = function(plot) {
      layer_index <- self$get_layer_index()
      own_layer <- plot$layers[[layer_index]]
      is_smooth_like <- inherits(own_layer$geom, "GeomSmooth") ||
        inherits(own_layer$geom, "GeomLine") ||
        inherits(own_layer$geom, "GeomDensity") ||
        inherits(own_layer$geom, "GeomArea")

      if (is_smooth_like) {
        return(layer_index)
      }

      smooth_layers <- which(sapply(plot$layers, function(layer) {
        inherits(layer$geom, "GeomSmooth") ||
          inherits(layer$geom, "GeomLine") ||
          inherits(layer$geom, "GeomDensity")
      }))

      if (length(smooth_layers) == 0) {
        stop("No smooth curve layers found in plot")
      }
      smooth_layers[1]
    },

    #' @description Built data for this layer, restricted to one facet panel.
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A data frame of built rows
    layer_built_data = function(plot, built = NULL, panel_id = NULL) {
      if (!inherits(plot, "ggplot")) {
        stop("Input must be a ggplot object.")
      }

      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      built_data <- built$data[[self$resolve_target_layer(plot)]]

      if (!is.null(panel_id) && "PANEL" %in% names(built_data)) {
        built_data <- built_data[built_data$PANEL == panel_id, , drop = FALSE]
      }

      built_data
    },

    #' @description Distinct group ids when the layer draws more than one curve.
    #' @param built_data Built rows for this layer
    #' @return Sorted group ids, or an empty vector for a single-curve layer
    series_group_ids = function(built_data) {
      if (!("group" %in% names(built_data))) {
        return(integer(0))
      }
      ids <- sort(unique(built_data$group))
      if (length(ids) < 2L) integer(0) else ids
    },

    #' @description Extract one series per drawn curve.
    #'
    #' ggplot2 draws a mapped smooth as one curve per group, so the payload
    #' has to be split the same way: concatenating the groups into a single
    #' series would walk a reader off the end of one curve into the start of
    #' the next with nothing announced in between.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return List of series, each a list of points
    extract_data = function(plot, built = NULL, panel_id = NULL) {
      built_data <- self$layer_built_data(plot, built, panel_id)

      # Back into the space the reader sees, before the rows are split into
      # curves. Safe on the whole frame here because nothing below orders by
      # these values -- the split is on `group` and the points keep the row
      # order `StatSmooth` emitted. Inverting changes what each row *says*,
      # never which row comes first (#158).
      if (!is.null(built_data) && nrow(built_data) > 0) {
        built_data$x <- untransform_positions(built_data$x, built, "x", panel_id)
        built_data$y <- untransform_positions(built_data$y, built, "y", panel_id)
        built_data <- self$attach_interval(built_data, plot, built, panel_id)
      }

      group_ids <- self$series_group_ids(built_data)
      if (length(group_ids) == 0L) {
        return(list(self$curve_points(built_data)))
      }

      series_names <- resolve_series_group_names(
        plot, built_data$group,
        resolve_series_group_mapping(
          plot, self$resolve_target_layer(plot), self$group_aes()
        )$column
      )

      lapply(seq_along(group_ids), function(i) {
        rows <- built_data[built_data$group == group_ids[[i]], , drop = FALSE]
        self$curve_points(rows, series_names[[i]])
      })
    },

    #' @description Turn built rows into MAIDR points.
    #' @param rows Built rows for one curve
    #' @param z Series name, or NULL for a single-curve layer
    #' @return List of points
    curve_points = function(rows, z = NULL) {
      has_interval <- all(c("ymin", "ymax") %in% names(rows))
      lapply(seq_len(nrow(rows)), function(i) {
        point <- list(x = rows$x[i], y = rows$y[i])
        if (!is.null(z)) {
          point$z <- z
        }
        # Per sample rather than per layer: `se = TRUE` can leave individual
        # rows without bounds, and announcing "interval NA to NA" would be
        # worse than announcing the fitted value alone.
        if (has_interval &&
          is.finite(rows$ymin[i]) && is.finite(rows$ymax[i])) {
          point$yMin <- as.numeric(rows$ymin[i])
          point$yMax <- as.numeric(rows$ymax[i])
        }
        point
      })
    },

    #' @description Keep this layer's \code{ymin}/\code{ymax} only when they
    #' are an uncertainty, and put them in the space the reader is shown.
    #'
    #' The columns are dropped rather than ignored, so \code{curve_points()}
    #' can key on their presence instead of re-asking the stat per sample.
    #'
    #' @param built_data This layer's built rows
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return \code{built_data}, with the interval untransformed or removed
    attach_interval = function(built_data, plot, built = NULL, panel_id = NULL) {
      bounds <- c("ymin", "ymax")
      drop <- function(frame) {
        frame[intersect(bounds, names(frame))] <- NULL
        frame
      }

      if (!self$layer_computes_interval(plot) ||
        !all(bounds %in% names(built_data))) {
        return(drop(built_data))
      }

      # `se = FALSE` still leaves the columns in place, filled with NA, so
      # their presence is not the test -- whether anything finite was
      # computed is.
      if (!any(is.finite(built_data$ymin) & is.finite(built_data$ymax))) {
        return(drop(built_data))
      }

      # Bounds live on the y scale, so a log or sqrt scale would otherwise
      # announce the interval in transformed units while the axis is
      # labelled in the original ones (#158).
      built_data$ymin <- untransform_positions(
        built_data$ymin, built, "y", panel_id
      )
      built_data$ymax <- untransform_positions(
        built_data$ymax, built, "y", panel_id
      )
      built_data
    },

    # `GRID.polyline.N` is grid's auto-name for an unnamed grob: N is a
    # session-wide counter, not a per-plot index. Two renders of the same
    # plot in one session produced `GRID.polyline.1` then
    # `GRID.polyline.54`, and the gtable this processor inspects is the one
    # `create_enhanced_svg()` later draws, so the only way to learn N is to
    # read it off that gtable. Rebuilding one with `ggplotGrob()` does not
    # help - it allocates a fresh round of names that the exported SVG will
    # never carry.
    #
    # So when the lookup finds no polyline there is nothing to guess from,
    # and the id this used to fall back to - `GRID.polyline.1.1.1` - is not
    # a harmless miss. In a `facet_wrap(~g, drop = FALSE)` whose third
    # level is empty, panel 3's fabricated selector came out byte-identical
    # to panel 1's real one, so the empty panel highlighted panel 1's
    # fitted line. The one plot shape where that id IS this layer's line (a
    # lone `geom_smooth()` drawn as the session's first auto-named grob)
    # is a shape where the lookup SUCCEEDS, so it never reached the
    # fallback. Emit nothing instead: the caller can tell an empty selector
    # list apart from a wrong one, a user cannot.
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL,
                                  built = NULL, panel_id = NULL) {
      if (is.null(gt)) {
        return(list())
      }

      n_series <- self$series_group_count(plot, built, panel_id)
      if (n_series > 1L) {
        grouped <- self$grouped_curve_selectors(plot, gt, panel_ctx, n_series)
        if (!is.null(grouped)) {
          return(grouped)
        }
        # The chunking could not line the grob children up with the groups.
        # Do NOT fall through to the single-curve path here: it returns ONE
        # selector while extract_data() has already returned n_series, and a
        # highlight aimed at one group's curve while the reader walks all of
        # them is the very defect this processor was fixed for. Emitting
        # nothing is the honest answer -- the caller can tell an empty
        # selector list apart from a wrong one, a user cannot.
        return(list())
      }

      collect_all_polyline_grobs <- function(grob) {
        polyline_grobs <- list()

        if (!is.null(grob$name) && grepl("GRID\\.polyline", grob$name)) {
          polyline_grobs <- append(polyline_grobs, grob$name)
        }

        if ("children" %in% names(grob)) {
          for (child in grob$children) {
            child_grobs <- collect_all_polyline_grobs(child)
            polyline_grobs <- append(polyline_grobs, child_grobs)
          }
        }

        polyline_grobs
      }

      all_polyline_grobs <- list()

      if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        # Facet / patchwork path: scope the search to this panel's grob
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (!is.null(panel_grob)) {
          all_polyline_grobs <- collect_all_polyline_grobs(panel_grob)
        }
      } else if ("grobs" %in% names(gt)) {
        for (grob in gt$grobs) {
          grob_results <- collect_all_polyline_grobs(grob)
          all_polyline_grobs <- append(all_polyline_grobs, grob_results)
        }
      }

      if (length(all_polyline_grobs) == 0) {
        return(list())
      }

      numeric_ids <- sapply(all_polyline_grobs, function(grob_name) {
        match_result <- regmatches(grob_name, regexpr("GRID\\.polyline\\.(\\d+)", grob_name))
        if (length(match_result) > 0) {
          as.numeric(gsub("GRID\\.polyline\\.", "", match_result))
        } else {
          0
        }
      })

      numeric_ids <- numeric_ids[numeric_ids > 0]

      if (length(numeric_ids) > 0) {
        # Fitted line is the LAST polyline (confidence interval rendered first)
        # ggplot2 renders confidence interval first, then the fitted line
        target_id <- max(numeric_ids)
        grob_id <- paste0("GRID.polyline.", target_id, ".1.1")
      } else {
        # Fallback to first found grob
        grob_id <- paste0(all_polyline_grobs[[1]], ".1")
      }
      escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)

      list(paste0("#", escaped_grob_id))
    },

    #' @description Number of curves this layer draws in the given panel.
    #'
    #' Never throws: selector generation has to degrade to the single-curve
    #' path for inputs \code{extract_data()} would reject.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return Number of groups, or 0 when the layer draws a single curve
    series_group_count = function(plot, built = NULL, panel_id = NULL) {
      tryCatch(
        length(self$series_group_ids(
          self$layer_built_data(plot, built, panel_id)
        )),
        error = function(e) 0L
      )
    },

    #' @description One selector per curve for a layer split into groups.
    #'
    #' ggplot2 draws a grouped smooth one group at a time, so the layer's grob
    #' tree holds an equal run of children per group: a bare polyline for
    #' \code{se = FALSE}, a ribbon gTree followed by a polyline for
    #' \code{se = TRUE}, and a ribbon gTree alone for \code{geom_density()}.
    #' Chunking the children by group and taking the last polyline in each
    #' chunk applies the same "the curve is the last polyline drawn" rule the
    #' single-curve path uses, once per group instead of once per layer.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for panel-scoped selector generation
    #' @param n_series Number of curves the layer draws
    #' @return List of selectors, or NULL when the grob tree does not line up
    grouped_curve_selectors = function(plot, gt, panel_ctx, n_series) {
      if (is.null(gt)) {
        return(NULL)
      }
      tree <- tryCatch(
        self$find_layer_grob_tree(plot, gt, panel_ctx),
        error = function(e) NULL
      )
      if (is.null(tree) || !inherits(tree, "gTree")) {
        return(NULL)
      }

      children <- tree$children
      n_children <- length(children)
      if (n_children == 0L || n_children %% n_series != 0L) {
        return(NULL)
      }

      per_group <- n_children %/% n_series
      selectors <- list()
      for (i in seq_len(n_series)) {
        ids <- character(0)
        for (j in seq_len(per_group)) {
          child <- children[[(i - 1L) * per_group + j]]
          ids <- c(ids, self$polyline_grob_names(child))
        }
        if (length(ids) == 0L) {
          return(NULL)
        }
        # gridSVG suffixes a single-line polyline grob with ".1.1"
        svg_id <- paste0(ids[[length(ids)]], ".1.1")
        selectors[[i]] <- paste0("#", gsub("\\.", "\\\\.", svg_id))
      }
      selectors
    },

    #' @description Names of the curve polyline grobs inside a grob, in draw
    #' order. Panel grid lines are excluded: they are named after the theme
    #' element (\code{panel.grid.major.x..polyline.N}), not \code{GRID.polyline.N}.
    #'
    #' @param grob A grob to walk
    #' @return Character vector of grob names
    polyline_grob_names = function(grob) {
      out <- character(0)
      if (!is.null(grob$name) && grepl("^GRID\\.polyline\\.\\d+$", grob$name)) {
        out <- c(out, grob$name)
      }
      if (inherits(grob, "gTree")) {
        for (child in grob$children) {
          out <- c(out, self$polyline_grob_names(child))
        }
      }
      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          out <- c(out, self$polyline_grob_names(grob[[i]]))
        }
      }
      out
    },

    #' @description Find the grob tree ggplot2 drew for this layer.
    #'
    #' Defers to the base walk and supplies the one thing this processor does
    #' differently: which layer to look for. \code{resolve_target_layer()} may
    #' answer a layer other than this processor's own, which is why the target
    #' cannot simply be the layer index the base class would use.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for panel-scoped selector generation
    #' @param target Index of the layer to find; resolved when absent
    #' @return The matching grob, or NULL
    find_layer_grob_tree = function(plot, gt, panel_ctx = NULL, target = NULL) {
      if (is.null(target)) {
        target <- self$resolve_target_layer(plot)
      }
      super$find_layer_grob_tree(plot, gt, panel_ctx, target)
    }
  )
)

#' Grob-name prefix ggplot2 gives a geom's layer grob
#'
#' ggplot2 names a layer's grob after the snake-cased class of its geom, so
#' \code{GeomSmooth} draws \code{geom_smooth.gTree.<n>} and \code{GeomDensity}
#' draws \code{geom_density.gTree.<n>}.
#'
#' @param geom A ggproto Geom object
#' @return Character scalar prefix
#' @keywords internal
geom_grob_prefix <- function(geom) {
  cls <- class(geom)[[1]]
  tolower(gsub("([a-z0-9])([A-Z])", "\\1_\\2", cls))
}
