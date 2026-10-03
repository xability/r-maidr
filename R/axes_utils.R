#' Canonical Axes Schema Helpers
#'
#' Utilities for constructing and validating the canonical per-axis
#' \code{axes} object emitted by the MAIDR payload. Only \code{x}, \code{y},
#' and \code{z} keys are permitted at the top level of \code{axes}; each maps
#' to an \code{AxisConfig} list with optional \code{label} (string),
#' \code{min}, \code{max}, \code{tickStep} (numbers), and \code{format} (an
#' \code{AxisFormat} list). The legacy flat form (bare string labels and
#' top-level format/min/max/tickStep/fill/level) has been removed with no
#' deprecation path.
#'
#' @name axes_utils
#' @keywords internal
NULL

#' Normalize a single axis value into AxisConfig shape
#'
#' Accepts legacy or partial inputs (bare string label, already-wrapped list,
#' or NULL) and returns either NULL (when nothing to emit) or a named list
#' conforming to the AxisConfig schema.
#'
#' @param value Raw axis input (string, list, or NULL)
#' @return A named list (AxisConfig) or NULL
#' @keywords internal
as_axis_config <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }
  if (is.list(value)) {
    # An axis with nothing to say is not emitted at all: an empty list
    # serializes as `[]`, and a key holding it would claim an axis config
    # that carries neither a label nor a navigation grid.
    if (length(value) == 0) {
      return(NULL)
    }
    return(value)
  }
  if (is.character(value) || is.numeric(value)) {
    return(list(label = as.character(value)))
  }
  stop(
    "Axis value must be a list, string, numeric, or NULL. Got: ",
    paste(class(value), collapse = "/"),
    call. = FALSE
  )
}

#' Extract a label from a possibly-wrapped axis value
#'
#' Accepts a bare string, an AxisConfig list with a \code{label} field, or
#' NULL. Returns a character scalar.
#'
#' @param value Raw axis input
#' @param default Default label when no value is present
#' @return Character scalar label
#' @keywords internal
extract_axis_label <- function(value, default = "") {
  if (is.null(value)) {
    return(default)
  }
  if (is.list(value)) {
    if (!is.null(value$label)) {
      return(as.character(value$label))
    }
    return(default)
  }
  as.character(value)
}

#' Build a single AxisConfig
#'
#' Drops the fields that are absent, so an axis only carries what its caller
#' could establish. Returns a named empty list when nothing could be: passed
#' to [build_axes()], that drops the axis key entirely.
#'
#' @param label Axis label, or NULL
#' @param min Axis minimum, or NULL
#' @param max Axis maximum, or NULL
#' @param tickStep Distance between ticks, or NULL
#' @return A named list (AxisConfig), possibly empty
#' @keywords internal
build_axis_config <- function(label = NULL, min = NULL, max = NULL, tickStep = NULL) {
  cfg <- structure(list(), names = character(0))
  if (!is.null(label)) cfg$label <- as.character(label)
  if (!is.null(min)) cfg$min <- min
  if (!is.null(max)) cfg$max <- max
  if (!is.null(tickStep)) cfg$tickStep <- tickStep
  cfg
}

#' Build a canonical axes object
#'
#' Convenience constructor for a per-axis axes list. Drops NULL and empty
#' axes, so a caller that can say nothing about an axis simply omits the key
#' and leaves the generic to the renderer.
#'
#' @param x Label string or AxisConfig list for the x axis (or NULL)
#' @param y Label string or AxisConfig list for the y axis (or NULL)
#' @param z Label string or AxisConfig list for the z axis (or NULL)
#' @return A canonical axes list with only non-NULL axes set. Named even when
#'   empty, so it serializes as the JSON object `{}` rather than as `[]`.
#' @keywords internal
build_axes <- function(x = NULL, y = NULL, z = NULL) {
  axes <- structure(list(), names = character(0))
  x_cfg <- as_axis_config(x)
  y_cfg <- as_axis_config(y)
  z_cfg <- as_axis_config(z)
  if (!is.null(x_cfg)) axes$x <- x_cfg
  if (!is.null(y_cfg)) axes$y <- y_cfg
  if (!is.null(z_cfg)) axes$z <- z_cfg
  axes
}

#' Resolve the legend title for a grouping aesthetic
#'
#' Returns the title ggplot2 prints above the legend for a grouping
#' aesthetic, which is what the MAIDR payload emits as the z axis label.
#' A \code{labs()} override wins (ggplot2 stores it on the built plot's
#' \code{labels}, normalising \code{color} to \code{colour}); otherwise the
#' mapped expression is used, with the layer's own mapping taking precedence
#' over the plot-level one. Returns NULL when the aesthetic carries neither.
#'
#' Callers are responsible for only asking about an aesthetic the layer is
#' actually grouped by: \code{labs()} records a title even for an unmapped
#' aesthetic, so an unguarded lookup would invent a legend that the plot does
#' not draw.
#'
#' @param plot The ggplot object
#' @param built Built plot from \code{ggplot2::ggplot_build()}, or NULL to
#'   build one on demand
#' @param aes_names Aesthetic names to try, in order. Pass spelling variants
#'   of one aesthetic (for example \code{c("colour", "color")}), never
#'   unrelated aesthetics.
#' @param layer_index Index of the layer whose mapping takes precedence, or
#'   NULL to consult only the plot-level mapping
#' @return Character scalar, or NULL when the aesthetic has no title
#' @keywords internal
resolve_legend_label <- function(plot, built = NULL, aes_names = "fill",
                                 layer_index = NULL) {
  labels <- if (!is.null(built)) {
    built$plot$labels
  } else {
    tryCatch(ggplot2::ggplot_build(plot)$plot$labels, error = function(e) NULL)
  }

  for (aes_name in aes_names) {
    label <- labels[[aes_name]]
    if (!is.null(label) && length(label) == 1L && !is.na(label) &&
      nzchar(as.character(label))) {
      return(as.character(label))
    }
  }

  mappings <- list()
  if (!is.null(layer_index) && length(plot$layers) >= layer_index) {
    mappings[[length(mappings) + 1L]] <- plot$layers[[layer_index]]$mapping
  }
  mappings[[length(mappings) + 1L]] <- plot$mapping

  for (mapping in mappings) {
    if (is.null(mapping)) next
    for (aes_name in aes_names) {
      quo <- mapping[[aes_name]]
      if (!is.null(quo)) {
        return(rlang::as_label(quo))
      }
    }
  }

  NULL
}

#' Resolve the printed label for a positional axis
#'
#' The name ggplot2 prints beside the x or y axis, which is the name a
#' reader needs in order to know what the numbers are. A \code{labs()}
#' override wins, then the layer's own mapping, then the plot's -- the same
#' chain \code{resolve_legend_label()} walks for a legend title, because it
#' is the same chain ggplot2 walks.
#'
#' The difference from the legend case is only what to do when none of them
#' answers. A legend that has no title should have none; a positional axis
#' always has one printed on the chart, so the aesthetic name is emitted
#' rather than nothing. That is a poor label, but it is a label, and the
#' alternative is a number announced with no name at all.
#'
#' \code{resolve_legend_label()}'s documented caution -- that \code{labs()}
#' records a title even for an unmapped aesthetic, so only ask about one the
#' layer is grouped by -- does not apply here. A layer with no x or y mapping
#' has no positions to announce and does not reach a processor that would
#' ask.
#'
#' @param plot The ggplot object
#' @param built Built plot from \code{ggplot2::ggplot_build()}, or NULL to
#'   build one on demand
#' @param aes_name \code{"x"} or \code{"y"}
#' @param layer_index Index of the layer whose mapping takes precedence, or
#'   NULL to consult only the plot-level mapping
#' @return Character scalar, never NULL
#' @keywords internal
positional_axis_label <- function(plot, built = NULL, aes_name = "x",
                                  layer_index = NULL) {
  label <- resolve_legend_label(
    plot, built,
    aes_names = aes_name, layer_index = layer_index
  )
  if (is.null(label)) aes_name else label
}

#' A mapped expression as ggplot2 names it
#'
#' The expression a mapping plots, with what ggplot2 leaves out of the names it
#' gives mappings taken out too (its internal `make_labels()`): the stage it is
#' evaluated at (`after_stat(density)`, `stage(hwy, after_stat = density)`),
#' the older spellings of a computed variable (`stat(density)`, `..density..`)
#' and the `.data` pronoun (`.data$hwy`, `.data[["hwy"]]`), wherever they sit.
#'
#' A mapping that names no variable -- a constant such as `aes(y = 0)`,
#' `aes(x = "")` or `aes(x = factor(1))` -- is NULL, as if the layer had none:
#' it places the layer rather than plotting something, and ggplot2 does not
#' name an axis after it either.
#'
#' @param mapping A quosure or expression from `aes()`, or NULL
#' @return The expression, or NULL
#' @keywords internal
mapping_expr <- function(mapping) {
  if (is.null(mapping)) {
    return(NULL)
  }
  env <- emptyenv()
  expr <- mapping
  if (rlang::is_quosure(mapping)) {
    env <- rlang::quo_get_env(mapping)
    expr <- rlang::quo_get_expr(mapping)
  }

  repeat {
    if (rlang::is_call(expr, c("after_stat", "after_scale"), n = 1)) {
      expr <- expr[[2]]
    } else if (rlang::is_call(expr, "stage")) {
      stage <- tryCatch(
        as.list(match.call(
          function(start = NULL, after_stat = NULL, after_scale = NULL) NULL,
          expr
        )),
        error = function(e) list()
      )
      inner <- stage$after_stat %||% stage$start %||% stage$after_scale
      if (is.null(inner)) {
        break
      }
      expr <- inner
    } else {
      break
    }
  }

  strip <- function(e) {
    if (is.symbol(e)) {
      name <- as.character(e)
      if (!nzchar(name)) {
        return(e)
      }
      return(as.symbol(sub("^\\.\\.([a-zA-Z._]+)\\.\\.$", "\\1", name)))
    }
    if (!is.call(e)) {
      return(e)
    }
    if (rlang::is_call(e, "stat", n = 1)) {
      return(strip(e[[2]]))
    }
    if (rlang::is_call(e, "$", n = 2) && identical(e[[2]], quote(.data))) {
      return(strip(e[[3]]))
    }
    if (rlang::is_call(e, "[[", n = 2) && identical(e[[2]], quote(.data))) {
      name <- tryCatch(eval(e[[3]], env), error = function(err) NULL)
      return(if (rlang::is_string(name)) as.symbol(name) else e[[3]])
    }
    for (i in seq_along(e)[-1]) {
      # An empty argument (`x[, 1]`) cannot be bound to a name, and a
      # constant is left alone: assigning NULL would drop the argument.
      if (identical(e[[i]], quote(expr = ))) next
      if (is.symbol(e[[i]]) || is.call(e[[i]])) {
        e[[i]] <- strip(e[[i]])
      }
    }
    e
  }

  expr <- strip(expr)
  if (length(all.vars(expr)) == 0) {
    return(NULL)
  }
  expr
}

#' The name ggplot2 gives a mapped expression
#'
#' The default title ggplot2 derives from a mapping: [mapping_expr()]'s
#' expression, deparsed and cut at the end of its first line, as
#' `make_labels()` cuts it. So `after_stat(density)`, `stat(density)`,
#' `..density..` and `.data$density` are all "density", and
#' `..count.. / sum(..count..)` is "count/sum(count)".
#'
#' A name, not a key: two long expressions can share their first line. Compare
#' mappings with [mapping_key()].
#'
#' @param mapping A quosure or expression from `aes()`, or NULL
#' @return Character scalar, or NULL when the mapping cannot be named
#' @keywords internal
mapping_label <- function(mapping) {
  expr <- mapping_expr(mapping)
  if (is.null(expr)) {
    return(NULL)
  }
  if (is.symbol(expr)) {
    return(as.character(expr))
  }
  tryCatch(
    gsub("\n.*$", "...", rlang::expr_text(expr)),
    error = function(e) NULL
  )
}

#' Whether two mappings plot the same thing, as a string
#'
#' The whole of [mapping_expr()]'s expression, on one line, so that mappings
#' which differ only past the end of [mapping_label()]'s name still differ.
#'
#' Less the ways a category is drawn somewhere else on its own axis: a change
#' of type, and a category's position offset by a number. `factor(cyl)` is
#' `cyl`, `as.numeric(term) + 0.1` is `term` dodged by hand, and
#' `as.numeric(factor(class)) - 0.3` is `class` nudged beside its boxes, so
#' none of them is something else plotted on that axis. An offset of anything
#' else -- `sales + 1` -- is a different value, and stays one.
#'
#' @param mapping A quosure or expression from `aes()`, or NULL
#' @return Character scalar, or NULL
#' @keywords internal
mapping_key <- function(mapping) {
  expr <- mapping_expr(mapping)
  if (is.null(expr)) {
    return(NULL)
  }
  is_coercion <- function(e) {
    rlang::is_call(e, c(
      "as.numeric", "as.double", "as.integer",
      "factor", "as.factor", "as.character"
    ), n = 1)
  }
  if (rlang::is_call(expr, c("+", "-"), n = 2) &&
    is.numeric(expr[[3]]) && is_coercion(expr[[2]])) {
    expr <- expr[[2]]
  } else if (rlang::is_call(expr, "+", n = 2) &&
    is.numeric(expr[[2]]) && is_coercion(expr[[3]])) {
    expr <- expr[[3]]
  }
  while (is_coercion(expr)) {
    expr <- expr[[2]]
  }
  paste(deparse(expr, width.cutoff = 500L), collapse = " ")
}

#' What a ggplot2 layer plots on a positional axis
#'
#' The layer's own mapping for the aesthetic, else the plot's when the layer
#' inherits it, else the value its stat computes by default -- the
#' `after_stat(count)` a histogram plots on y without being asked to. NULL
#' when the layer plots nothing there, or a constant it was given as a
#' parameter.
#'
#' A stat default named for the aesthetic itself -- `stat_function()`'s
#' `after_scale(y)`, `stat_qq_line()`'s `after_stat(y)` -- is NULL as well:
#' it is the stat's output with no name of its own, not a variable another
#' layer could plot differently.
#'
#' @param plot The ggplot object
#' @param layer One of its layers
#' @param aes_name \code{"x"} or \code{"y"}
#' @return A quosure or expression, or NULL
#' @keywords internal
layer_position_mapping <- function(plot, layer, aes_name) {
  if (aes_name %in% names(layer$aes_params)) {
    return(NULL)
  }
  own <- layer$mapping[[aes_name]]
  if (!is.null(own)) {
    return(own)
  }
  if (isTRUE(layer$inherit.aes) && !is.null(plot$mapping[[aes_name]])) {
    return(plot$mapping[[aes_name]])
  }
  computed <- layer$stat$default_aes[[aes_name]]
  if (!is.language(computed) || identical(mapping_label(computed), aes_name)) {
    return(NULL)
  }
  computed
}

#' The label a ggplot2 layer's values are read under on a positional axis
#'
#' The axis title -- `labs()`, or the name ggplot2 gave the axis -- unless
#' the layer maps the aesthetic itself and another layer read beside it puts
#' something else on that axis. Only then is the axis title no description
#' of this layer in particular, and the layer is named for what it plots:
#' `geom_col(aes(y = sales)) + geom_line(aes(y = target))` reads "sales" and
#' "target". A layer's own mapping that every other layer agrees with, or that
#' no other layer has, is what the axis title already describes, so a
#' one-layer plot keeps its `labs()` title (#349).
#'
#' Layers are compared by what they plot once ggplot2's own spellings are
#' taken out (see [mapping_expr()]), so `aes(y = after_stat(density))` on a
#' histogram agrees with a `geom_density()` beside it, which plots
#' `after_stat(density)` without being asked to. Where it is named for itself,
#' the layer is named as ggplot2 would name it -- "density", never
#' "after_stat(density)". Decoration maidr does not read (see
#' [layer_is_decoration()]) takes no part: an `annotate()` arrow does not make
#' a one-layer chart a two-layer one.
#'
#' @param plot The ggplot object
#' @param layer_index Index of the layer being read
#' @param aes_name \code{"x"} or \code{"y"}
#' @param axis_label The axis title from the plot's layout
#' @return Character scalar
#' @keywords internal
layer_axis_label <- function(plot, layer_index, aes_name, axis_label) {
  layers <- plot$layers
  if (layer_index > length(layers)) {
    return(axis_label)
  }
  own_mapping <- layers[[layer_index]]$mapping[[aes_name]]
  own <- mapping_label(own_mapping)
  if (is.null(own)) {
    return(axis_label)
  }
  # No title to keep -- removed, or not one string (`labs(y = 5)`,
  # `labs(y = c("a", "b"))`) -- and the layer's own name is better than none.
  if (!rlang::is_string(axis_label) || !nzchar(axis_label)) {
    return(own)
  }

  # Before 4.0, ggplot2 titled an axis after the plot's own mapping even when
  # every layer replaced it, so a title that is that mapping's name need not
  # describe anything a layer plots.
  plot_mapping <- plot$mapping[[aes_name]]
  stale_title <- !is.null(plot_mapping) &&
    identical(axis_label, mapping_label(plot_mapping)) &&
    !identical(mapping_key(plot_mapping), mapping_key(own_mapping))
  if (stale_title) {
    return(own)
  }

  read <- Filter(Negate(layer_is_decoration), layers)
  plotted <- unique(unlist(lapply(read, function(layer) {
    mapping_key(layer_position_mapping(plot, layer, aes_name))
  })))
  if (length(plotted) > 1) own else axis_label
}

#' Attach a format object to a specific axis
#'
#' Mutates a single axis's \code{format} field. Creates the axis slot
#' (with \code{label = default_label}) if it does not exist. No-ops when
#' \code{format_obj} is NULL.
#'
#' @param axes Canonical axes list
#' @param which Axis key: one of \code{"x"}, \code{"y"}, \code{"z"}
#' @param format_obj AxisFormat list (or NULL)
#' @param default_label Label to use if the axis slot is being created. NULL
#'   (the default) creates the slot without one, so attaching a format to an
#'   axis whose processor had no title to give does not put an empty label
#'   back in front of the renderer's generic.
#' @return The mutated axes list
#' @keywords internal
attach_axis_format <- function(axes, which, format_obj, default_label = NULL) {
  if (is.null(format_obj)) {
    return(axes)
  }
  if (!which %in% c("x", "y", "z")) {
    stop(
      "attach_axis_format(): 'which' must be one of 'x','y','z', got '",
      which, "'",
      call. = FALSE
    )
  }
  if (is.null(axes[[which]])) {
    axes[[which]] <- if (is.null(default_label)) {
      structure(list(), names = character(0))
    } else {
      list(label = default_label)
    }
  } else if (!is.list(axes[[which]])) {
    # Defensive: wrap a stray bare string before mutating
    axes[[which]] <- list(label = as.character(axes[[which]]))
  }
  axes[[which]]$format <- format_obj
  axes
}

#' Validate a canonical axes object (strict)
#'
#' Enforces the canonical schema. On any violation, throws an error
#' with a descriptive message.
#'
#' Rules:
#' \itemize{
#'   \item \code{axes} must be NULL or a list.
#'   \item Keys must be a subset of \code{\{"x","y","z"\}}.
#'   \item Each axis value must be a list (AxisConfig), never a string/
#'         number/array.
#'   \item No \code{format}, \code{min}, \code{max}, \code{tickStep},
#'         \code{fill}, or \code{level} at the top level of \code{axes}.
#'   \item \code{min}, \code{max}, \code{tickStep} (when present inside an
#'         axis) must be numeric scalars.
#' }
#'
#' @param axes Axes list to validate (or NULL)
#' @param context Optional string describing the call site (for errors)
#' @return Invisibly returns \code{axes} if valid
#' @keywords internal
validate_axes <- function(axes, context = "") {
  prefix <- if (nzchar(context)) paste0("[", context, "] ") else ""

  if (is.null(axes)) {
    return(invisible(NULL))
  }
  if (!is.list(axes)) {
    stop(prefix, "axes must be a list or NULL, got ",
      paste(class(axes), collapse = "/"),
      call. = FALSE
    )
  }

  allowed <- c("x", "y", "z")
  keys <- names(axes)
  if (is.null(keys) || any(!nzchar(keys))) {
    stop(prefix, "axes must be a named list with keys from {x,y,z}",
      call. = FALSE
    )
  }
  bad <- setdiff(keys, allowed)
  if (length(bad) > 0) {
    stop(prefix,
      "axes must only contain keys {x,y,z}. Disallowed keys: ",
      paste(bad, collapse = ", "),
      ". Nested formatter/min/max/tickStep/fill/level inside x|y|z instead.",
      call. = FALSE
    )
  }

  numeric_fields <- c("min", "max", "tickStep")
  for (key in keys) {
    cfg <- axes[[key]]
    if (!is.list(cfg)) {
      stop(prefix,
        "axes$", key, " must be a list (AxisConfig), got ",
        paste(class(cfg), collapse = "/"),
        call. = FALSE
      )
    }
    for (nf in numeric_fields) {
      v <- cfg[[nf]]
      if (!is.null(v) && !(is.numeric(v) && length(v) == 1)) {
        stop(prefix,
          "axes$", key, "$", nf, " must be a numeric scalar",
          call. = FALSE
        )
      }
    }
    if (!is.null(cfg$label) && !is.character(cfg$label)) {
      stop(prefix,
        "axes$", key, "$label must be a character string",
        call. = FALSE
      )
    }
    if (!is.null(cfg$format) && !is.list(cfg$format)) {
      stop(prefix,
        "axes$", key, "$format must be a list (AxisFormat)",
        call. = FALSE
      )
    }
  }

  invisible(axes)
}

#' Grid navigation bounds for one axis
#'
#' `min`, `max` and `tickStep` for the axis named, read off the built plot's
#' panel parameters, or `NULL` when any of the three cannot be determined --
#' which leaves the axis with its label and no grid, the graceful degradation
#' #158 settled on.
#'
#' Lifted out of `Ggplot2PointLayerProcessor`, which still calls it, when the
#' rug processor came to need the same answer for the axis its ticks stand on
#' (#222). Two readings of one grid rule is how the two would drift.
#'
#' @param built Built plot data
#' @param axis Character, either "x" or "y"
#' @param panel_id Panel index for faceted plots (optional, defaults to 1)
#' @return List with min, max, tickStep, or NULL
#' @keywords internal
axis_grid_info <- function(built, axis = "x", panel_id = NULL) {
  tryCatch(
    {
      # A transformed axis has no uniform tick step to give. Grid
      # navigation walks the axis in equal increments, and on a log
      # scale the breaks a reader sees -- 10, 100, 1000 -- are equally
      # spaced only in the transformed space the points are no longer
      # announced in. Emitting the transformed range instead would put
      # the grid and the announcement in different spaces, which is
      # worse than today, where the two are at least wrong together.
      #
      # So the axis keeps its label and loses its grid, which is the
      # same graceful degradation this function already takes when a
      # range cannot be read (#158).
      if (!is.null(panel_transformation(built, axis, panel_id))) {
        return(NULL)
      }

      panel_idx <- if (!is.null(panel_id)) as.integer(panel_id) else 1L
      panel_params <- built$layout$panel_params[[panel_idx]]

      if (is.null(panel_params)) {
        return(NULL)
      }

      pp_axis <- panel_params[[axis]]
      if (is.null(pp_axis)) {
        return(NULL)
      }

      # Extract range from continuous_range
      axis_range <- pp_axis$continuous_range
      if (is.null(axis_range) || length(axis_range) < 2) {
        return(NULL)
      }

      axis_min <- axis_range[1]
      axis_max <- axis_range[2]

      # Extract breaks to compute tickStep
      axis_breaks <- pp_axis$breaks
      if (is.null(axis_breaks) || length(axis_breaks) < 2) {
        # Try alternative: get_breaks() from panel_scales
        scale_obj <- if (axis == "x") {
          built$layout$panel_scales_x[[panel_idx]]
        } else {
          built$layout$panel_scales_y[[panel_idx]]
        }
        if (!is.null(scale_obj)) {
          axis_breaks <- tryCatch(scale_obj$get_breaks(), error = function(e) NULL)
        }
      }

      if (is.null(axis_breaks) || length(axis_breaks) < 2) {
        return(NULL)
      }

      # Remove NAs from breaks
      axis_breaks <- axis_breaks[!is.na(axis_breaks)]
      if (length(axis_breaks) < 2) {
        return(NULL)
      }

      # Sort breaks and compute tickStep from first interval
      axis_breaks <- sort(axis_breaks)
      tick_step <- diff(axis_breaks)[1]

      # Validate: all values must be finite and sensible
      if (!is.finite(axis_min) || !is.finite(axis_max) || !is.finite(tick_step)) {
        return(NULL)
      }
      if (axis_min >= axis_max) {
        return(NULL)
      }
      if (tick_step <= 0 || tick_step > (axis_max - axis_min)) {
        return(NULL)
      }

      list(min = axis_min, max = axis_max, tickStep = tick_step)
    },
    error = function(e) {
      NULL
    }
  )
}
