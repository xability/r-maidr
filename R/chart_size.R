#' The size a chart is drawn at
#'
#' Every chart is drawn on a canvas measured in inches, as [ggplot2::ggsave()]
#' and knitr's `fig.width` measure one, and exported at 72 pixels to the inch:
#' a 7 x 5 in chart is an SVG 504 px wide and 360 px high. The size sets the
#' room the chart is laid out in -- how far apart its ticks and labels are,
#' how much text fits beside a panel -- and nothing a reader hears: the data,
#' axes and titles maidr announces are the same at every size. A page still
#' shrinks a chart wider than itself to fit.
#'
#' @noRd
NULL

#' The canvas a chart is drawn on when none is asked for, in inches
#' @keywords internal
MAIDR_CHART_SIZE <- c(width = 7, height = 5)

#' The smallest canvas a candlestick chart is drawn on, in inches
#'
#' quantmod's `chartSeries()` lays out its title, the bracketed date range on
#' its right and its two-line month and year labels for a page this wide and
#' no narrower (quantmod issue #129); maidr's ggplot2 candlestick is held to
#' the same so the two agree.
#'
#' @keywords internal
MAIDR_CANDLESTICK_SIZE <- c(width = 12, height = 6)

#' Check a requested chart width or height
#'
#' @param value The value given: `NULL`, or a size in inches.
#' @param arg The argument's name, as the caller gave it.
#' @return `value`, invisibly. Stops unless it is `NULL` or one positive,
#'   finite number.
#' @keywords internal
check_chart_size <- function(value, arg) {
  ok <- is.null(value) ||
    (is.numeric(value) && length(value) == 1L && is.finite(value) && value > 0)
  if (!ok) {
    stop(
      "`", arg, "` must be NULL or a single positive number of inches, not ",
      format_chart_size_value(value), ".",
      call. = FALSE
    )
  }
  invisible(value)
}

#' A value that is not a chart size, as an error names it
#' @param value Any value
#' @return One string
#' @keywords internal
#' @noRd
format_chart_size_value <- function(value) {
  if (is.numeric(value) && length(value) == 1L) {
    return(format(value))
  }
  if (is.character(value) && length(value) == 1L) {
    return(sprintf('"%s"', value))
  }
  if (length(value) != 1L) {
    return(sprintf("%s of length %d", class(value)[1L], length(value)))
  }
  class(value)[1L]
}

#' The canvas a chart is drawn on
#'
#' The size asked for, each side that was not asked for taken from
#' [MAIDR_CHART_SIZE], or from [MAIDR_CANDLESTICK_SIZE] for a candlestick
#' chart. A candlestick chart smaller than [MAIDR_CANDLESTICK_SIZE] on either
#' side is drawn at that size on that side instead, and a message (of class
#' `maidr_chart_size_message`) names the size it is drawn at: a size asked
#' for is never changed silently.
#'
#' @param width,height The size asked for in inches, or `NULL` for none.
#'   Checked by the caller, with [check_chart_size()].
#' @param candlestick Whether the chart holds a candlestick layer.
#' @return A named numeric vector, `width` and `height`, in inches.
#' @keywords internal
chart_canvas_size <- function(width = NULL, height = NULL, candlestick = FALSE) {
  default <- if (candlestick) MAIDR_CANDLESTICK_SIZE else MAIDR_CHART_SIZE
  asked <- c(width = width %||% default[["width"]], height = height %||% default[["height"]])
  if (!candlestick) {
    return(asked)
  }
  used <- pmax(asked, MAIDR_CANDLESTICK_SIZE)
  if (any(used != asked)) {
    # Classed, so that a knitted chart can say it where the rest of what its
    # build says is kept out of the document (see `knit_chart_content()`).
    rlang::inform(
      paste0(
        "maidr: this candlestick chart is drawn at ", format_inches(used),
        " rather than the ", format_inches(asked), " asked for: a candlestick ",
        "chart is drawn at least ", format_inches(MAIDR_CANDLESTICK_SIZE),
        " so that its date labels fit."
      ),
      class = "maidr_chart_size_message"
    )
  }
  used
}

#' A canvas size as a message names it
#' @param size A named numeric vector, `width` and `height`, in inches
#' @return One string, such as "12 x 6 in"
#' @keywords internal
#' @noRd
format_inches <- function(size) {
  paste0(format(size[["width"]]), " x ", format(size[["height"]]), " in")
}
