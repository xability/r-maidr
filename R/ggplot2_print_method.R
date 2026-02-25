#' ggplot2 Print Method Interception
#'
#' Intercepts ggplot2's print method so that typing a ggplot object name
#' at the console automatically renders it in the MAIDR interactive viewer.
#'
#' @importFrom utils getS3method
#' @keywords internal

# Internal state for ggplot2 print interception
.maidr_ggplot_state <- new.env(parent = emptyenv())
.maidr_ggplot_state$original_print_ggplot <- NULL
.maidr_ggplot_state$registered <- FALSE

#' Register MAIDR's custom print.ggplot method
#'
#' Stores the original ggplot2 print method and registers MAIDR's version.
#' Called during `.onLoad()`.
#'
#' @keywords internal
register_ggplot2_print_method <- function() {
  if (isTRUE(.maidr_ggplot_state$registered)) {
    return(invisible(NULL))
  }

  # Store the original print method for ggplot objects.
  # In ggplot2 v4+ (S7-based), the class name is "ggplot2::ggplot" (with namespace prefix).
  # In ggplot2 v3 (S3-based), the class name is "ggplot".
  # We try both to ensure compatibility.
  orig <- tryCatch(
    getS3method("print", "ggplot2::ggplot"),
    error = function(e) NULL
  )
  if (is.null(orig)) {
    orig <- tryCatch(
      getS3method("print", "ggplot"),
      error = function(e) NULL
    )
  }
  if (is.null(orig)) {
    orig <- tryCatch(
      get("print.ggplot", envir = asNamespace("ggplot2")),
      error = function(e) NULL
    )
  }

  if (is.null(orig)) {
    # ggplot2 not available — can't register
    return(invisible(NULL))
  }

  .maidr_ggplot_state$original_print_ggplot <- orig

  # Register our custom print method for both S7 and S3 class names.
  # "ggplot2::ggplot" is the S7 class name used in ggplot2 v4+.
  # "ggplot" is the traditional S3 class name used in ggplot2 v3.
  registerS3method("print", "ggplot", maidr_print_ggplot, envir = baseenv())
  tryCatch(
    registerS3method("print", "ggplot2::ggplot", maidr_print_ggplot, envir = baseenv()),
    error = function(e) NULL
  )

  .maidr_ggplot_state$registered <- TRUE

  invisible(NULL)
}

#' Restore the original print.ggplot method
#'
#' @keywords internal
restore_ggplot2_print_method <- function() {
  if (!isTRUE(.maidr_ggplot_state$registered)) {
    return(invisible(NULL))
  }

  if (!is.null(.maidr_ggplot_state$original_print_ggplot)) {
    orig <- .maidr_ggplot_state$original_print_ggplot
    registerS3method("print", "ggplot", orig, envir = baseenv())
    tryCatch(
      registerS3method("print", "ggplot2::ggplot", orig, envir = baseenv()),
      error = function(e) NULL
    )
  }

  .maidr_ggplot_state$registered <- FALSE

  invisible(NULL)
}

#' MAIDR's custom print method for ggplot objects
#'
#' When MAIDR interception is enabled, this renders ggplot objects in the
#' MAIDR interactive viewer. For unsupported plots, it falls back to the
#' original ggplot2 rendering.
#'
#' @param x A ggplot object
#' @param newpage Draw on a new page?
#' @param vp Viewport to draw in
#' @param ... Additional arguments passed to the print method
#' @return Invisible ggplot object
#' @keywords internal
maidr_print_ggplot <- function(x, newpage = is.null(vp), vp = NULL, ...) {
  original_print <- .maidr_ggplot_state$original_print_ggplot

  # Check if ggplot2 interception is enabled
  if (!is_ggplot2_enabled()) {
    return(original_print(x, newpage = newpage, vp = vp, ...))
  }

  # Check if the plot is supported by MAIDR
  supported <- tryCatch(
    {
      registry <- get_global_registry()
      adapter <- registry$get_adapter("ggplot2")
      orchestrator <- adapter$create_orchestrator(x)
      !orchestrator$should_fallback()
    },
    error = function(e) {
      FALSE
    }
  )

  if (!supported) {
    # Unsupported plot — fall back to normal ggplot2 rendering
    return(original_print(x, newpage = newpage, vp = vp, ...))
  }

  # Supported plot — render in MAIDR interactive viewer
  maidr::show(x)

  invisible(x)
}
