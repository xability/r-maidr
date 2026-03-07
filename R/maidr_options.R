#' MAIDR Package Options
#'
#' Configure MAIDR interception and display behavior using R's options system.
#'
#' @section Available Options:
#' \describe{
#'   \item{\code{maidr.auto_show}}{Logical. Master switch for all MAIDR interception.
#'     When FALSE, all plotting functions behave as standard R. Default: TRUE.}
#'   \item{\code{maidr.base_r}}{Logical. Enable Base R plot interception.
#'     When TRUE, Base R plots are captured and displayed in the MAIDR viewer.
#'     Default: TRUE.}
#'   \item{\code{maidr.ggplot2}}{Logical. Enable ggplot2 auto-display.
#'     When TRUE, ggplot2 objects are automatically rendered in the MAIDR viewer
#'     instead of the standard graphics device. Default: TRUE.}
#'   \item{\code{maidr.startup_message}}{Logical. Show startup message when
#'     package is loaded. Default: TRUE.}
#' }
#'
#' @section Setting Options:
#' Options can be set in your \code{.Rprofile} to persist across sessions:
#' \preformatted{
#' # Disable ggplot2 interception by default
#' options(maidr.ggplot2 = FALSE)
#'
#' # Disable all interception
#' options(maidr.auto_show = FALSE)
#'
#' # Suppress startup message
#' options(maidr.startup_message = FALSE)
#' }
#'
#' @name maidr-options
#' @keywords internal
NULL

#' Initialize MAIDR default options
#'
#' Sets default values for MAIDR options during package load.
#' Does not override options already set by the user (e.g. in .Rprofile).
#'
#' @keywords internal
initialize_maidr_options <- function() {
  defaults <- list(
    maidr.auto_show = TRUE,
    maidr.base_r = TRUE,
    maidr.ggplot2 = TRUE,
    maidr.startup_message = TRUE,
    maidr.fallback_enabled = TRUE,
    maidr.fallback_format = "png",
    maidr.fallback_warning = TRUE
  )

  # Only set options that aren't already set by the user
  current <- options()
  toset <- !(names(defaults) %in% names(current))
  if (any(toset)) options(defaults[toset])

  invisible(NULL)
}

#' Check if MAIDR interception is globally enabled
#'
#' @return TRUE if the master switch is on
#' @keywords internal
is_maidr_enabled <- function() {
  isTRUE(getOption("maidr.auto_show", TRUE))
}

#' Check if Base R interception is enabled
#'
#' @return TRUE if Base R interception is active
#' @keywords internal
is_base_r_enabled <- function() {
  is_maidr_enabled() && isTRUE(getOption("maidr.base_r", TRUE))
}

#' Check if ggplot2 interception is enabled
#'
#' @return TRUE if ggplot2 interception is active
#' @keywords internal
is_ggplot2_enabled <- function() {
  is_maidr_enabled() && isTRUE(getOption("maidr.ggplot2", TRUE))
}
