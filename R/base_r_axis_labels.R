#' Base R Axis-Title Defaults
#'
#' Base R's high-level plotting functions derive their axis titles inside the
#' call (`hist()` names the y axis "Frequency", `boxplot.formula()` reads both
#' titles off the formula) instead of recording them, and `barplot()` and
#' `pie()` draw no title at all. Either way the recorded call carries no
#' `xlab=`/`ylab=`, so a processor that only reads those arguments announces a
#' nameless axis.
#'
#' What a chart can honestly put there is a property of the chart type rather
#' than of the data, so the shapes shared by several processors are resolved
#' here once.
#'
#' @name base_r_axis_labels
#' @keywords internal
NULL

#' Resolve one axis title from a recorded Base R call
#'
#' The author's own `xlab=`/`ylab=` always wins. An empty string counts as
#' unsupplied: Base R draws no title for it, so falling through to the chart
#' type's default announces more than the blank would, and the renderer would
#' otherwise substitute its generic "X"/"Y" anyway. This is how the
#' candlestick processor has always read these arguments.
#'
#' @param args Recorded argument list, or NULL
#' @param name Argument to read: `"xlab"` or `"ylab"`
#' @param default What this chart type can honestly say when the author said
#'   nothing. Pass NULL when it can say nothing: an absent label leaves the
#'   generic to the renderer, which is where that decision belongs.
#' @return Character scalar, or `default`
#' @keywords internal
recorded_axis_label <- function(args, name, default = NULL) {
  supplied <- if (is.list(args)) args[[name]] else NULL
  if (!is.null(supplied)) {
    label <- tryCatch(as.character(supplied)[1], error = function(e) NULL)
    if (!is.null(label) && !is.na(label) && nzchar(label)) {
      return(label)
    }
  }
  default
}

#' Canonical axes for a categorical Base R chart
#'
#' `barplot()`, `boxplot()` and `pie()` all plot one categorical axis against
#' one measured axis, and none of them writes a title unless the author does.
#' Naming those axes for what they hold -- "Category" against "Value" -- says
#' what the numbers mean, where the renderer's positional "X"/"Y" fallback
#' only says where they sit, and it claims nothing beyond the shape of the
#' call. py-maidr's pie chart defaults to the same two words.
#'
#' @param args Recorded argument list, or NULL
#' @param horizontal TRUE when the chart draws its value axis horizontally,
#'   which swaps which visual axis holds the categories
#' @return Canonical axes list
#' @keywords internal
base_r_categorical_axes <- function(args, horizontal = FALSE) {
  category <- "Category"
  value <- "Value"

  build_axes(
    x = recorded_axis_label(args, "xlab", if (horizontal) value else category),
    y = recorded_axis_label(args, "ylab", if (horizontal) category else value)
  )
}
