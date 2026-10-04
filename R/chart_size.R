#' The size a chart is drawn at
#'
#' Every chart is drawn on a canvas measured in inches, as [ggplot2::ggsave()]
#' and knitr's `fig.width` measure one, and exported at 72 pixels to the inch:
#' a 7 x 5 in chart is an SVG 504 px wide and 360 px high. The size sets the
#' room the chart is laid out in -- how far apart its ticks and labels are,
#' how much text fits beside a panel -- and not what a reader hears: the
#' data, axes and titles maidr announces are the same at every size. The one
#' thing it changes for a reader is the grid of a lattice chart conditioned
#' on one variable with no `layout =`, whose panels lattice arranges for the
#' page's shape, and so the order a reader moves through them in. A page
#' still shrinks a chart wider than itself to fit.
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

#' The largest a chart is drawn, on either side, in inches
#'
#' As [ggplot2::ggsave()] refuses a larger size: one given in pixels by
#' mistake -- `maidr_output()` and the widget take pixels -- would draw a
#' chart hundreds of inches across, which nobody who cannot see it would
#' notice.
#'
#' @keywords internal
MAIDR_MAX_CHART_SIZE <- 50

#' Check a requested chart width or height
#'
#' @param value The value given: `NULL`, or a size in inches.
#' @param arg The argument's name, as the caller gave it.
#' @return `value`, invisibly. Stops unless it is `NULL` or one positive
#'   number no larger than [MAIDR_MAX_CHART_SIZE].
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
  if (!is.null(value) && value > MAIDR_MAX_CHART_SIZE) {
    stop(
      "`", arg, "` is ", format(value), " inches, larger than the ",
      MAIDR_MAX_CHART_SIZE, " a chart can be. A chart's size is in inches, ",
      "not pixels: ", format(value), " pixels would be ",
      format(round(value / 72, 2)), " in, at 72 pixels to the inch.",
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
#' side is drawn at that size on that side instead. When that size was asked
#' for, a message (of class `maidr_chart_size_message`) names the size it is
#' drawn at: a size asked for is never changed silently. One that was not --
#' a knitted document's figure size, which every chunk that sets none is
#' drawn at -- is enlarged without a word, as before maidr read a chunk's
#' size. A Base R chart too small for a size no one asked for is enlarged
#' too, and says so ([base_r_page_that_fits()]).
#'
#' @param width,height The size in inches, or `NULL` for none.
#'   Checked by the caller, with [check_chart_size()].
#' @param candlestick Whether the chart holds a candlestick layer.
#' @param asked Whether `width` and `height` were asked for: by default when
#'   either is given. A knitted chunk's are asked for only when they are not
#'   the document's own (`knitr_chart_size()`).
#' @return A named numeric vector, `width` and `height`, in inches.
#' @keywords internal
chart_canvas_size <- function(width = NULL, height = NULL, candlestick = FALSE,
                              asked = !is.null(width) || !is.null(height)) {
  default <- if (candlestick) MAIDR_CANDLESTICK_SIZE else MAIDR_CHART_SIZE
  size <- c(width = width %||% default[["width"]], height = height %||% default[["height"]])
  if (!candlestick) {
    return(size)
  }
  used <- pmax(size, MAIDR_CANDLESTICK_SIZE)
  if (asked && any(used != size)) {
    # Classed, so that a knitted chart can say it where the rest of what its
    # build says is kept out of the document (see `knit_chart_content()`).
    rlang::inform(
      paste0(
        "maidr: this candlestick chart is drawn at ", format_inches(used),
        " rather than the ", format_inches(size), " asked for: a candlestick ",
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
