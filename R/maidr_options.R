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
#'   \item{\code{maidr.dotpad_sdk_url}}{Character. URL of a copy of the DotPad
#'     tactile-display SDK module (\code{DotPadSDK-3.0.2.js}) that you serve
#'     yourself. maidr.js does not bundle the SDK, whose licence does not
#'     permit redistribution; unless told otherwise it imports the vendor's
#'     copy from jsDelivr the first time a DotPad is connected, from a
#'     document rendered with \code{use_cdn = FALSE} as much as any other.
#'     Set this to keep that path off the network too. Falls back to the
#'     environment variable \code{MAIDR_DOTPAD_SDK_URL}. Default: unset.}
#'   \item{\code{maidr.dotpad_asset_base_url}}{Character. URL of the directory
#'     holding the SDK's braille engine (\code{liblouis.js}, \code{.wasm},
#'     \code{.data}), needed only when it is not the \code{lib/} folder
#'     beside the module. Falls back to the environment variable
#'     \code{MAIDR_DOTPAD_ASSET_BASE_URL}. Default: unset.}
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
#'
#' # Serve the DotPad SDK from your own server instead of jsDelivr
#' options(
#'   maidr.dotpad_sdk_url = "https://example.org/vendor/DotPadSDK-3.0.2.js",
#'   maidr.dotpad_asset_base_url = "https://example.org/vendor/lib/"
#' )
#' }
#'
#' @section DotPad SDK and offline documents:
#' The two \code{maidr.dotpad_*} options are written into every document this
#' package produces (\code{show()}, \code{save_html()}, the htmlwidget, knitr
#' and Shiny) as the globals \code{window.MAIDR_DOTPAD_SDK_URL} and
#' \code{window.MAIDR_DOTPAD_ASSET_BASE_URL}, ahead of \code{maidr.js}, which
#' reads them when a DotPad is connected. Nothing is written when neither is
#' set. Without them a DotPad needs network access to jsDelivr on first
#' connect, even from a \code{use_cdn = FALSE} document; the rest of the
#' document works offline either way.
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
