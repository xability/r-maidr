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

#' The text an argument of a recorded call was written as
#'
#' @param plot_call A recorded call
#' @param formal The formal the argument was matched to
#' @return A string, or NULL when the call kept no text for it: see
#'   `written_arg_text()`
#' @keywords internal
written_arg <- function(plot_call, formal) {
  text <- plot_call$arg_text
  at <- match(formal, names(text))
  if (is.na(at) || is.na(text[[at]])) NULL else text[[at]]
}

#' The axis titles a Base R call writes after how its arguments were written
#'
#' `hist(x)` titles its x axis after how `x` was written, `qqplot(x, y)`
#' both its axes, and `plot(x, y)` whatever `xy.coords()` makes of the two:
#' `plot(v)` is titled "Index" against `v`, and a matrix by its column
#' names. The recorded call keeps that text (`written_arg_text()`), so these
#' are the titles R drew rather than a guess at them, and an axis is named
#' in the data as it is in the picture.
#'
#' `plot()` is read by the method it reached, as `plot_axis_titles()` says.
#'
#' @param plot_call A recorded call
#' @return List with `x` and `y`, each NULL when the call writes no such
#'   title
#' @keywords internal
written_axis_titles <- function(plot_call) {
  if (is.null(plot_call)) {
    return(list())
  }
  switch(plot_call$function_name %||% "",
    hist = list(x = written_arg(plot_call, "x")),
    qqplot = list(x = written_arg(plot_call, "x"), y = written_arg(plot_call, "y")),
    plot = plot_axis_titles(plot_call),
    list()
  )
}

#' The axis titles a recorded `plot()` call writes
#'
#' Each method of `plot()` titles its axes its own way, so the titles are
#' read by the method the call reached.
#'
#' - `plot.default()`: whatever `xy.coords()` makes of `x` and `y`.
#' - `plot.ts()`, for one series: "Time" against the series' one column
#'   name or, without one, the series as written.
#' - `plot.table()`, for a one-way table: the table's dimension name, when it
#'   has one, against the table as written.
#' - `plot.data.frame()`, for a frame of two columns: the two column names.
#'
#' Any other method gives none, and so do these where they draw something
#' else: several series in panels, a mosaic, a strip chart or a pairs plot.
#' An argument written before the one the method was dispatched on, as in
#' `plot(main = "Nile", Nile)`, changes none of this.
#'
#' @param plot_call A recorded `plot()` call
#' @return List with `x` and `y`, or an empty list when the method reached
#'   writes no titles maidr reads
#' @keywords internal
plot_axis_titles <- function(plot_call) {
  args <- plot_call$args
  plot_generic <- get_original_function("plot")
  target <- dispatched_definition("plot", plot_generic, args)
  xy <- resolve_xy_args(args)

  if (identical(target, utils::getS3method("plot", "ts"))) {
    if (!is.null(xy$y) || NCOL(xy$x) != 1L) {
      return(list())
    }
    name <- colnames(xy$x)
    return(list(
      x = "Time",
      y = if (length(name) == 1L) name else written_arg(plot_call, "x")
    ))
  }
  if (identical(target, utils::getS3method("plot", "table"))) {
    if (length(dim(xy$x)) != 1L) {
      return(list())
    }
    name <- names(dimnames(xy$x))
    return(list(
      x = if (length(name) == 1L && nzchar(name)) name,
      y = written_arg(plot_call, "x")
    ))
  }
  if (identical(target, utils::getS3method("plot", "data.frame"))) {
    if (!is.data.frame(xy$x) || ncol(xy$x) != 2L) {
      return(list())
    }
    return(list(x = names(xy$x)[1L], y = names(xy$x)[2L]))
  }
  if (!identical(target, graphics::plot.default)) {
    return(list())
  }

  coords <- tryCatch(
    suppressWarnings(grDevices::xy.coords(
      xy$x, xy$y,
      written_arg(plot_call, "x"), written_arg(plot_call, "y")
    )),
    error = function(e) NULL
  )
  if (is.null(coords)) {
    return(list())
  }
  list(x = coords$xlab, y = coords$ylab)
}
