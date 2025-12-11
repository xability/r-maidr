#' Configure MAIDR Fallback Behavior
#'
#' Configure how MAIDR handles unsupported plot types or layers.
#' When fallback is enabled, unsupported plots are rendered as static
#' images instead of failing or returning empty data.
#'
#' @param enabled Logical. If TRUE (default), unsupported plots fall back
#'   to image rendering. If FALSE, unsupported layers return empty data.
#' @param format Character. Image format for fallback: "png" (default),
#'   "svg", or "jpeg".
#' @param warning Logical. If TRUE (default), shows a warning message
#'   when falling back to image rendering.
#'
#' @return Invisibly returns a list of the previous settings.
#'
#' @examples
#' \dontrun{
#' # Disable fallback (unsupported plots will have empty data)
#' maidr_set_fallback(enabled = FALSE)
#'
#' # Use SVG format for fallback images
#' maidr_set_fallback(format = "svg")
#'
#' # Disable warning messages
#' maidr_set_fallback(warning = FALSE)
#'
#' # Configure multiple options
#' maidr_set_fallback(enabled = TRUE, format = "png", warning = TRUE)
#' }
#'
#' @seealso [maidr_get_fallback()] to retrieve current settings
#' @export
maidr_set_fallback <- function(enabled = TRUE, format = "png", warning = TRUE) {
  # Validate inputs
  if (!is.logical(enabled) || length(enabled) != 1) {
    stop("'enabled' must be a single logical value")
  }

  valid_formats <- c("png", "svg", "jpeg")
  if (!format %in% valid_formats) {
    stop("'format' must be one of: ", paste(valid_formats, collapse = ", "))
  }

  if (!is.logical(warning) || length(warning) != 1) {
    stop("'warning' must be a single logical value")
  }

  # Store previous settings
  previous <- maidr_get_fallback()

  # Set new options
  options(
    maidr.fallback_enabled = enabled,
    maidr.fallback_format = format,
    maidr.fallback_warning = warning
  )

  invisible(previous)
}

#' Get Current MAIDR Fallback Settings
#'
#' Retrieves the current fallback configuration for MAIDR.
#'
#' @return A list with the current fallback settings:
#'   \itemize{
#'     \item \code{enabled}: Logical indicating if fallback is enabled
#'     \item \code{format}: Character string of the image format
#'     \item \code{warning}: Logical indicating if warnings are shown
#'   }
#'
#' @examples
#' \dontrun{
#' # Get current settings
#' settings <- maidr_get_fallback()
#' print(settings)
#' }
#'
#' @seealso [maidr_set_fallback()] to configure settings
#' @export
maidr_get_fallback <- function() {
  list(
    enabled = getOption("maidr.fallback_enabled", TRUE),
    format = getOption("maidr.fallback_format", "png"),
    warning = getOption("maidr.fallback_warning", TRUE)
  )
}
