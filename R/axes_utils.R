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
