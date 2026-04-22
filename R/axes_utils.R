#' Canonical Axes Schema Helpers
#'
#' Utilities for constructing and validating the canonical per-axis
#' \code{axes} object emitted by the MAIDR payload. The schema is:
#' \preformatted{
#'   axes: {
#'     x?: AxisConfig,
#'     y?: AxisConfig,
#'     z?: AxisConfig
#'   }
#'
#'   AxisConfig: {
#'     label?:    string,
#'     min?:      number,
#'     max?:      number,
#'     tickStep?: number,
#'     format?:   AxisFormat
#'   }
#' }
#'
#' Only \code{x}, \code{y}, \code{z} keys are permitted at the top level of
#' \code{axes}. The legacy flat form (bare string labels, top-level
#' \code{format}/\code{min}/\code{max}/\code{tickStep}/\code{fill}/\code{level})
#' has been removed with no deprecation path.
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

#' Build a canonical axes object
#'
#' Convenience constructor for a per-axis axes list. Drops NULL axes.
#'
#' @param x Label string or AxisConfig list for the x axis (or NULL)
#' @param y Label string or AxisConfig list for the y axis (or NULL)
#' @param z Label string or AxisConfig list for the z axis (or NULL)
#' @return A canonical axes list with only non-NULL axes set
#' @keywords internal
build_axes <- function(x = NULL, y = NULL, z = NULL) {
  axes <- list()
  x_cfg <- as_axis_config(x)
  y_cfg <- as_axis_config(y)
  z_cfg <- as_axis_config(z)
  if (!is.null(x_cfg)) axes$x <- x_cfg
  if (!is.null(y_cfg)) axes$y <- y_cfg
  if (!is.null(z_cfg)) axes$z <- z_cfg
  axes
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
#' @param default_label Label to use if the axis slot is being created
#' @return The mutated axes list
#' @keywords internal
attach_axis_format <- function(axes, which, format_obj, default_label = "") {
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
    axes[[which]] <- list(label = default_label)
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
