#' The Pointer's Hover Mode a Chart Starts With
#'
#' maidr.js reads an optional top-level `hoverMode` from a chart's schema:
#' how the pointer moves the reader's position in the chart, and with it the
#' highlight, sound and announcement. It is the chart's starting value for
#' the reader's Hover Mode setting, not a lock on it: a reader who has
#' changed that setting keeps theirs. It is read by the maidr.js releases
#' after 4.14.0 (xability/maidr#1382); older ones, the 4.14.0 bundled with
#' this package among them, ignore it, so writing it is always safe.
#'
#' Set per chart by `hover_mode` in [show()], [save_html()],
#' [maidr_htmlwidget()] and [render_maidr()], and for every chart that does
#' not set one, in R Markdown and Quarto documents and at the console too,
#' by `options(maidr.hover_mode = )`.
#'
#' @name hover-mode
#' @keywords internal
#' @noRd
NULL

# The values maidr.js reads, the default first.
HOVER_MODES <- c("pointermove", "click", "off")

#' Check a Hover Mode
#'
#' @param hover_mode `NULL`, or one of `HOVER_MODES`.
#' @param arg How the value was given, for the error.
#' @return `hover_mode`, invisibly
#' @keywords internal
#' @noRd
check_hover_mode <- function(hover_mode, arg = "`hover_mode`") {
  if (is.null(hover_mode)) {
    return(invisible(NULL))
  }
  valid <- is.character(hover_mode) && length(hover_mode) == 1L &&
    !is.na(hover_mode) && hover_mode %in% HOVER_MODES
  if (!valid) {
    given <- paste(deparse(hover_mode, nlines = 1L), collapse = " ")
    stop(
      arg, " must be one of \"pointermove\", \"click\" or \"off\", or NULL, ",
      "not ", given, ".",
      call. = FALSE
    )
  }
  invisible(hover_mode)
}

#' The Hover Mode a Chart Is Written With
#'
#' The one given, or, when none is, `getOption("maidr.hover_mode")`.
#'
#' @param hover_mode `NULL`, or one of `HOVER_MODES`.
#' @return One of `HOVER_MODES`, or `NULL` for none
#' @keywords internal
#' @noRd
resolve_hover_mode <- function(hover_mode = NULL) {
  if (!is.null(hover_mode)) {
    return(check_hover_mode(hover_mode))
  }
  check_hover_mode(getOption("maidr.hover_mode"), "`options(maidr.hover_mode)`")
}

#' Write a Hover Mode Into a Chart's Schema
#'
#' The one place `hoverMode` is set, at the top level of the schema beside
#' `id` and `title`. `NULL` leaves the schema as it was, so maidr.js uses the
#' reader's setting.
#'
#' @param maidr_data The chart's schema, as `generate_maidr_data()` makes it.
#' @param hover_mode `NULL`, or one of `HOVER_MODES`, already checked.
#' @return `maidr_data`
#' @keywords internal
#' @noRd
with_hover_mode <- function(maidr_data, hover_mode) {
  if (!is.null(hover_mode)) {
    maidr_data$hoverMode <- hover_mode
  }
  maidr_data
}
