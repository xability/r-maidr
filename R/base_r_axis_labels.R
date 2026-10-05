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

#' A layer's axes, titled as the plot's `title()` and `mtext()` calls title
#' them
#'
#' An author who blanks a plot's own titles, with `xlab = ""` or
#' `ann = FALSE`, often writes them with `title()` or `mtext()` instead, on
#' a line of their own choosing. R draws those on the axes, but a layer's
#' axes are read from the plot's own call, so the reader heard them
#' untitled: "X is 1.51" where R drew "Weight".
#'
#' - `title(xlab =, ylab =)` draws where the plot's own title goes, so it
#'   titles that axis, over whatever the plot drew there: the last one
#'   written is the one on top.
#' - `mtext()` writes any text in a margin. One string centred on side 1 or
#'   2, as an axis title is, titles that axis where the plot left it
#'   untitled. One set off to a side, with `adj` or `at`, is a note.
#'
#' Either one in the outer margin (`outer = TRUE`) titles the page rather
#' than this plot, and is not read.
#'
#' @param axes The layer's canonical axes, or NULL
#' @param low_calls The LOW-level calls recorded on the layer's plot
#' @return `axes`, with those titles
#' @keywords internal
with_margin_titles <- function(axes, low_calls) {
  written <- list()
  noted <- list()
  for (call in low_calls) {
    args <- call$args
    if (recorded_flag(args, "outer")) {
      next
    }
    if (identical(call$function_name, "title")) {
      written$x <- recorded_axis_label(args, "xlab", written$x)
      written$y <- recorded_axis_label(args, "ylab", written$y)
    } else if (identical(call$function_name, "mtext")) {
      title <- mtext_axis_title(args)
      if (!is.null(title)) {
        noted[[title$axis]] <- title$text
      }
    }
  }

  for (axis in c("x", "y")) {
    label <- written[[axis]]
    if (is.null(label) && is.null(axes[[axis]]$label)) {
      label <- noted[[axis]]
    }
    if (!is.null(label)) {
      axes <- axes %||% build_axes()
      axes[[axis]]$label <- label
    }
  }
  axes
}

#' The axis title an `mtext()` call writes, if it writes one
#'
#' @param args The recorded arguments of the `mtext()` call. Its `text`,
#'   the formal it is dispatched on, is left unnamed when written first, as
#'   `match_recorded_args()` leaves it.
#' @return List with `axis`, `"x"` for one string centred on side 1 or `"y"`
#'   on side 2, and its `text`; or NULL
#' @keywords internal
mtext_axis_title <- function(args) {
  unset <- function(value) is.null(value) || all(is.na(value))
  arg_names <- names(args) %||% rep("", length(args))
  text <- if ("text" %in% arg_names) {
    args[["text"]]
  } else if (any(!nzchar(arg_names))) {
    args[[which(!nzchar(arg_names))[1L]]]
  }
  side <- args[["side"]] %||% 3
  adj <- args[["adj"]]
  centred <- unset(adj) || (length(adj) == 1L && isTRUE(adj == 0.5))
  placed <- length(text) == 1L && length(side) == 1L && is.numeric(side) &&
    unset(args[["at"]]) && centred
  if (!placed) {
    return(NULL)
  }
  axis <- if (isTRUE(side == 1)) "x" else if (isTRUE(side == 2)) "y"
  text <- recorded_axis_label(list(text = text), "text")
  if (is.null(axis) || is.null(text)) {
    return(NULL)
  }
  list(axis = axis, text = text)
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
#' `plot()` is read by the method it reached, as `plot_axis_titles()` says,
#' and only for the axes R draws those titles on (`drawn_default_titles()`).
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
    plot = drawn_default_titles(
      plot_call$args, plot_axis_titles(plot_call), plot_call$par_ann %||% TRUE
    ),
    list()
  )
}

#' The titles a `plot()` method derives that R draws
#'
#' A method of `plot()` draws the title it derives for an axis, such as
#' "Time" or the series as written, only where the call gives that axis no
#' title of its own: `ylab = ""` is drawn as the blank it is, in place of
#' the title, and `ann = FALSE` draws no titles at all. Without an `ann` of
#' its own, the call draws them as `par("ann")` said when it was made, so
#' `par(ann = FALSE)` turns them off too. Read through
#' `recorded_axis_label()`, which takes a blank for no title, the title R
#' did not draw was announced: "AirPassengers" for
#' `plot(AirPassengers, ylab = "")`.
#'
#' A title given as NULL is no title of the call's own: where the method
#' draws one for it, `plot_axis_titles()` says which. A title the call
#' writes itself is `recorded_axis_label()`'s to read.
#'
#' @param args Recorded argument list
#' @param titles List with `x` and `y`, the titles the method derives
#' @param ann What `par("ann")` was when the call was made
#' @return `titles`, without each one R does not draw
#' @keywords internal
drawn_default_titles <- function(args, titles, ann = TRUE) {
  if (!recorded_flag(args, "ann", default = ann)) {
    return(list())
  }
  if (!is.null(args[["xlab"]])) {
    titles$x <- NULL
  }
  if (!is.null(args[["ylab"]])) {
    titles$y <- NULL
  }
  titles
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
#' An `xlab` or `ylab` given as NULL is the method's to read too.
#' `plot.default()` and `plot.table()` draw their own title for it, but
#' `plot.ts()` draws none, and `plot.data.frame()` hands it on to
#' `plot.default()`, which titles the axis after the column it was handed,
#' `x[[1L]]` or `x[[2L]]`.
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
  # Given, if only as NULL; `args[["xlab"]]` cannot tell NULL from absent.
  given <- c("xlab", "ylab") %in% names(args)

  if (identical(target, utils::getS3method("plot", "ts"))) {
    if (!is.null(xy$y) || NCOL(xy$x) != 1L) {
      return(list())
    }
    name <- colnames(xy$x)
    return(list(
      x = if (!given[1L]) "Time",
      y = if (!given[2L]) {
        if (length(name) == 1L) name else written_arg(plot_call, "x")
      }
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
    return(list(
      x = if (given[1L]) "x[[1L]]" else names(xy$x)[1L],
      y = if (given[2L]) "x[[2L]]" else names(xy$x)[2L]
    ))
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
