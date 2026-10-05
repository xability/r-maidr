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

#' A layer's axes, titled as the `title()` and `mtext()` calls written on
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
#' - `mtext()` writes any text in a margin. One string centred on the side
#'   an axis is drawn on, as an axis title is, titles that axis where the
#'   layer has no title of its own, as `plot(x, y, ann = FALSE)` leaves it:
#'   maidr's "Category" and "Value", and a title `hist()` or `curve()`
#'   derives, are the layer's own. One set off to a side, with `adj` or
#'   `at`, is a note, and so is one written farther out than another on
#'   that side: a note under the title, such as where the data came from, is
#'   written on a line farther from the axis. Of those on one line the last
#'   one written is the one on top, and one inside the plot, on a line below
#'   0, titles the axis only where the margin has none.
#'
#' Which axis each one titles is `margin_titles()`'s to say.
#'
#' @param axes The layer's canonical axes, or NULL
#' @param titles The titles written on the axes of the layer's plot, from
#'   [margin_titles()], in the order they were written
#' @return `axes`, with those titles
#' @keywords internal
with_margin_titles <- function(axes, titles) {
  for (axis in c("x", "y")) {
    label <- NULL
    noted <- NULL
    for (title in titles) {
      if (!identical(title$axis, axis)) {
        next
      }
      if (identical(title$kind, "title")) {
        label <- title$text
      } else if (is.null(noted) || !farther_from_axis(title$line, noted$line)) {
        noted <- title
      }
    }
    if (is.null(label) && is.null(axes[[axis]]$label)) {
      label <- noted$text
    }
    if (!is.null(label)) {
      # First, where `build_axis_config()` puts it.
      config <- axes[[axis]]
      axes <- axes %||% build_axes()
      axes[[axis]] <- c(list(label = label), config[setdiff(names(config), "label")])
    }
  }
  axes
}

#' The titles written in the margins of each plot, by the axis they title
#'
#' A title written after a plot, with `title()` or `mtext()`, is drawn in a
#' margin, and titles the axis drawn on that side of it: `title(xlab =)` is
#' drawn on side 1, `title(ylab =)` on side 2, and `mtext()` on the side it
#' is given. A chart of two y axes draws its second series over the first,
#' with `par(new = TRUE)` and `axes = FALSE`, gives it an axis of its own on
#' the right with `axis(4)`, and often writes every title after it:
#' `mtext("Squares", side = 2)` for the first series' axis and
#' `mtext("Roots", side = 4)` for the second's. Read on the plot each was
#' written after, the second series was titled "Squares", after the axis of
#' the first, and the first had no title at all.
#'
#' So each title goes to the plots, of those drawn over one another
#' (`overlay_runs()`) in the plot R draws it on (`plot_drawn_on()`), whose
#' axis is drawn on its side (`axis_sides()`), and nearest it where several
#' are (`nearest_axes()`), and to each chart drawn onto them with
#' `add = TRUE`, as `contour(add = TRUE)` draws onto an `image()`. A
#' plot placed beside another or inset in it, with `par(fig = , new = TRUE)`,
#' is drawn in a plot region of its own, not over the other, and the titles
#' written after it are its own.
#' Where none of them draws an axis on the bottom or the left, a title there
#' titles the plot R draws it on, as `plot(x, y, axes = FALSE);
#' title(xlab = "Time")` does; on the top or the right, it titles none.
#' Either one in the outer margin (`outer = TRUE`) titles the page rather
#' than a plot, and is not read.
#'
#' @param groups The plot groups, from [group_device_calls()]
#' @param layout_calls The recorded LAYOUT calls, from [group_device_calls()]
#' @return One list per group: the titles written on its axes, in the order
#'   they were written. Each is a list with the `axis` it titles, `"x"` or
#'   `"y"`, the `side` it is drawn on, its `text`, its `kind`, `"title"` or
#'   `"mtext"`, and the `line` it is written on.
#' @keywords internal
margin_titles <- function(groups, layout_calls) {
  runs <- overlay_runs(groups, layout_calls)
  # A chart drawn onto a plot with `add = TRUE` draws against its axes.
  plots <- shared_plots(groups)
  sides <- lapply(plots, function(plot) axis_sides(groups[plots == plot]))
  titles <- rep(list(list()), length(groups))
  for (g in seq_along(groups)) {
    for (call in groups[[g]]$low_calls) {
      on <- plot_drawn_on(call, groups[seq_len(g)])
      run <- which(runs == runs[[on]])
      for (title in titles_written(call)) {
        owners <- run[vapply(
          sides[run], function(drawn) isTRUE(drawn[[title$axis]] == title$side), logical(1)
        )]
        owners <- nearest_axes(owners, sides, title)
        if (!length(owners) && title$side <= 2) {
          owners <- which(plots == plots[[on]])
        }
        for (owner in owners) {
          titles[[owner]] <- c(titles[[owner]], list(title))
        }
      }
    }
  }
  titles
}

#' The plot a low-level call draws on
#'
#' A low-level call draws on the plot drawn last, unless `par(mfg = )` moved
#' back to an earlier panel of a grid first: `par(mfrow = c(1, 2));
#' plot(a); plot(b); par(mfg = c(1, 1)); title(xlab = "A")` draws "A" under
#' the first plot. It is recorded with the plot it was written after, so it
#' is read on the plot, of those drawn up to it, that R drew in the region it
#' was drawn in (`device_plot_region()`).
#'
#' @param call A recorded LOW-level call
#' @param groups The plot groups drawn up to it, from [group_device_calls()]
#' @return The index in `groups` of the last one drawn in the call's region,
#'   or of the last one where none was, or where either region was not
#'   recorded
#' @keywords internal
plot_drawn_on <- function(call, groups) {
  region <- call$plot_region
  last <- length(groups)
  if (is.null(region)) {
    return(last)
  }
  for (g in rev(seq_len(last))) {
    drawn <- groups[[g]]$high_call$plot_region
    if (is.null(drawn)) {
      return(last)
    }
    if (isTRUE(all.equal(drawn, region))) {
      return(g)
    }
  }
  last
}

#' The sides a plot draws its axes on
#'
#' A plot draws its x axis on side 1 and its y axis on side 2, unless the
#' call turns them off, with `axes = FALSE`, `xaxt = "n"` or `yaxt = "n"`.
#' `axis()` draws one on the side it is given. A chart drawn onto the plot
#' with `add = TRUE` draws none of its own, and an `axis()` written after it
#' is drawn against the plot's axes.
#'
#' @param groups The plot group that drew the plot, from
#'   [group_device_calls()], and those drawn onto it (`shared_plots()`)
#' @return List with `x`, 1 or 3, and `y`, 2 or 4: the side the axis is
#'   drawn on, the bottom or the left where it is drawn on both; NA where it
#'   is drawn on neither. Its `lines` hold, for `x` and `y`, the margin
#'   lines the axes on that side are drawn on: 0, the edge of the plot, for
#'   the plot's own, and the `line` an `axis()` call is given.
#' @keywords internal
axis_sides <- function(groups) {
  args <- groups[[1L]]$high_call$args
  drawn <- recorded_flag(args, "axes", default = TRUE)
  sides <- c(
    if (drawn && !identical(args[["xaxt"]], "n")) 1,
    if (drawn && !identical(args[["yaxt"]], "n")) 2
  )
  lines <- rep(0, length(sides))
  for (group in groups) {
    for (call in group$low_calls) {
      if (identical(call$function_name, "axis")) {
        line <- suppressWarnings(as.numeric(call$args[["line"]]))[1]
        sides <- c(sides, suppressWarnings(as.numeric(call$args[["side"]]))[1])
        lines <- c(lines, if (is.na(line)) 0 else line)
      }
    }
  }
  x <- if (1 %in% sides) 1 else if (3 %in% sides) 3 else NA
  y <- if (2 %in% sides) 2 else if (4 %in% sides) 4 else NA
  list(
    x = x,
    y = y,
    lines = list(x = lines[sides %in% x], y = lines[sides %in% y])
  )
}

#' Which of several axes on one side a title is written beside
#'
#' A chart of three series can draw two y axes on the right, one at the
#' edge of the plot with `axis(4)` and one farther out with
#' `axis(4, line = 3.5)`, each titled with `mtext()` on a line just outside
#' it. A title is written beside the axis nearest it of those drawn inside
#' its line, or, where none is, the innermost.
#'
#' @param owners The plots whose axis is drawn on the title's side
#' @param sides Each plot's axes, from [axis_sides()]
#' @param title The title, from [titles_written()]
#' @return Those of `owners` whose axis on that side the title is written
#'   beside
#' @keywords internal
nearest_axes <- function(owners, sides, title) {
  if (length(owners) < 2L) {
    return(owners)
  }
  lines <- lapply(sides[owners], function(drawn) drawn$lines[[title$axis]])
  inside <- vapply(lines, function(at) {
    at <- at[at <= title$line]
    if (length(at)) title$line - max(at) else Inf
  }, numeric(1))
  if (all(is.infinite(inside))) {
    innermost <- vapply(lines, min, numeric(1))
    return(owners[innermost == min(innermost)])
  }
  owners[inside == min(inside)]
}

#' The axis titles one recorded call writes in a margin
#'
#' @param call A recorded LOW-level call
#' @return A list of titles, as [margin_titles()] describes them: the `xlab`
#'   and `ylab` a `title()` call writes, or the one an `mtext()` call does
#'   (`mtext_axis_title()`); empty for any other call, a blank title, or one
#'   in the outer margin
#' @keywords internal
titles_written <- function(call) {
  args <- call$args
  if (recorded_flag(args, "outer")) {
    return(list())
  }
  if (identical(call$function_name, "mtext")) {
    title <- mtext_axis_title(args)
    return(if (is.null(title)) list() else list(c(title, kind = "mtext")))
  }
  if (!identical(call$function_name, "title")) {
    return(list())
  }
  # Drawn on the line R puts an axis title on, `par("mgp")[1]`, 3 unless
  # the call says otherwise.
  line <- suppressWarnings(as.numeric(args[["line"]]))[1]
  line <- if (is.na(line)) 3 else line
  titles <- list()
  for (axis in c("x", "y")) {
    text <- recorded_axis_label(args, paste0(axis, "lab"))
    if (!is.null(text)) {
      side <- if (axis == "x") 1 else 2
      titles <- c(titles, list(list(
        axis = axis, side = side, text = text, kind = "title", line = line
      )))
    }
  }
  titles
}

#' The axis title an `mtext()` call writes, if it writes one
#'
#' @param args The recorded arguments of the `mtext()` call. Its `text`,
#'   the formal it is dispatched on, is left unnamed when written first, as
#'   `match_recorded_args()` leaves it.
#' @return List with the `axis` one string centred on a side titles, `"x"`
#'   on side 1 or 3 and `"y"` on side 2 or 4, that `side`, its `text`, and
#'   the `line` of the margin it is written on; or NULL
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
  axis <- if (isTRUE(side %in% c(1, 3))) "x" else if (isTRUE(side %in% c(2, 4))) "y"
  text <- recorded_axis_label(list(text = text), "text")
  if (is.null(axis) || is.null(text)) {
    return(NULL)
  }
  line <- suppressWarnings(as.numeric(args[["line"]]))[1]
  list(axis = axis, side = side, text = text, line = if (is.na(line)) 0 else line)
}

#' Whether one margin line is farther from the axis than another
#'
#' The lines of a margin count outwards from the axis, from 0. A line below
#' 0 is inside the plot, so it is farther than every line of the margin,
#' and farther the further in it is.
#'
#' @param line,than Two lines of one margin, as `mtext()` takes them
#' @return TRUE when `line` is the farther of the two
#' @keywords internal
farther_from_axis <- function(line, than) {
  if ((line < 0) != (than < 0)) line < 0 else abs(line) > abs(than)
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
