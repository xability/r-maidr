#' lattice Utilities
#'
#' What the lattice system needs to know about a trellis object before and
#' after it is drawn: which high-level function and panel function made it,
#' how its packets are laid out on the page, how its labels read, and how the
#' grobs lattice draws are addressed in the exported SVG.
#'
#' Everything here reads the trellis object's own fields or lattice's
#' exported API. lattice ships as byte code without its sources, and its
#' internals (`lattice:::compute.layout()`, `lattice:::getLabelList()`) are
#' re-implemented here rather than reached with `:::`, so a change to them
#' shows up as a failing test rather than as a silent change in reading. The
#' one internal touched is lattice's record of the chart it drew last, which
#' cannot be re-implemented: [lattice_draw_scene()] puts it back as it was
#' after drawing, and does nothing should it move.
#'
#' @name lattice_utils
#' @keywords internal
NULL

#' The grob-name prefix the lattice system draws with
#'
#' lattice names every grob it draws `<prefix>.<name>...`, with the prefix
#' `plot_01`, `plot_02`, ... counted across prints unless one is given.
#' Drawing with a fixed prefix gives the same ids every time, so selectors
#' can be written before the chart is exported.
#'
#' @keywords internal
LATTICE_PREFIX <- "maidr"

#' The panel functions each supported high-level function draws with
#'
#' A trellis object is read only while its panel function is the stock one
#' for the function that made it: the reading of each chart is written
#' against what that panel function draws, and a custom panel function can
#' draw anything, including exactly the same grobs as a stock one with
#' different meaning. `levelplot(useRaster = TRUE)` switches to
#' `panel.levelplot.raster`, which draws one image rather than cells, and is
#' left out for that reason.
#'
#' `xyplot()` of a time series draws with `panel.superpose()`, or with
#' `panel.superpose.plain()` when each series has a panel of its own; both
#' draw each series with `panel.xyplot()`, and so the same grobs, as long as
#' no `panel.groups` of the chart's own replaces it -- which
#' [lattice_static_check()] refuses.
#'
#' @keywords internal
LATTICE_SUPPORTED_PANELS <- list(
  xyplot = c("panel.xyplot", "panel.superpose", "panel.superpose.plain"),
  barchart = "panel.barchart",
  bwplot = "panel.bwplot",
  histogram = "panel.histogram",
  densityplot = "panel.densityplot",
  dotplot = "panel.dotplot",
  stripplot = "panel.stripplot",
  levelplot = "panel.levelplot",
  contourplot = "panel.contourplot",
  qqmath = "panel.qqmath",
  qq = "panel.qq"
)

#' The high-level function a trellis object was made by
#'
#' `p$call[[1]]` is the bare symbol of the generic whatever method built the
#' object -- lattice sets it so -- and `update()` keeps it. latticeExtra's
#' `+ layer()` and `c()` rewrite it to `update`, and `doubleYScale()` to its
#' own name, which is how those compositions are told apart. A function that
#' keeps the call as it was written is named as it was called, so
#' `latticeExtra::doubleYScale()` is read through its `::`.
#'
#' @param plot A trellis object
#' @return The function's name, or `NA` when the call names none.
#' @keywords internal
lattice_high_level_name <- function(plot) {
  call <- plot$call
  if (!is.call(call)) {
    return(NA_character_)
  }
  fun <- call[[1]]
  if (is.call(fun) && length(fun) == 3L &&
    (identical(fun[[1]], as.name("::")) || identical(fun[[1]], as.name(":::")))) {
    fun <- fun[[3]]
  }
  if (!is.symbol(fun)) {
    return(NA_character_)
  }
  as.character(fun)
}

#' The name of the lattice panel function a panel is, or NA
#'
#' `plot.trellis()` resolves a character panel with `get()` from inside the
#' lattice namespace, so a name means lattice's own function whatever the
#' caller's search path holds. A function object counts only when it is
#' lattice's own, `identical()` to it; any closure is custom, even one that
#' only calls a stock panel function.
#'
#' @param panel The `panel` field of a trellis object
#' @return A panel function name, or `NA`.
#' @keywords internal
lattice_panel_name <- function(panel) {
  ns <- asNamespace("lattice")
  if (is.character(panel) && length(panel) == 1L && !is.na(panel)) {
    return(if (exists(panel, envir = ns, inherits = FALSE)) panel else NA_character_)
  }
  if (is.function(panel)) {
    for (name in unique(unlist(LATTICE_SUPPORTED_PANELS))) {
      if (identical(panel, get(name, envir = ns))) {
        return(name)
      }
    }
  }
  NA_character_
}

#' Why a trellis object cannot be read, before it is drawn
#'
#' Each reason is something a stock chart never carries: a high-level
#' function the lattice system does not read, a panel function other than
#' that function's own, a superpanel or `panel.groups` a stock call never
#' sets, the marker latticeExtra leaves on a panel it has layered, or no
#' packets at all. The grobs drawn are audited as well, after drawing
#' ([lattice_panel_audit()]), because some of these draw exactly what a
#' stock chart does.
#'
#' @param plot A trellis object
#' @return Character vector of reasons, empty when the object can be read.
#' @keywords internal
lattice_static_check <- function(plot) {
  why <- character(0)
  high_level <- lattice_high_level_name(plot)
  if (is.na(high_level)) {
    why <- c(why, "the function that made it is not known")
  } else if (!high_level %in% names(LATTICE_SUPPORTED_PANELS)) {
    why <- c(why, sprintf("'%s()' is not read", high_level))
  }

  # `[[` rather than `$`: `$` partial-matches, and a cloud() object answers
  # `$panel` with another `panel.*` argument.
  common <- plot$panel.args.common
  if (!is.null(common[["panel"]])) {
    why <- c(why, "a superpanel is set")
  }
  if (!is.null(common[["panel.groups"]])) {
    why <- c(why, "a custom `panel.groups` is set")
  }

  panel <- plot[["panel"]]
  if (is.function(panel) &&
    exists(".is.a.layer", envir = environment(panel), inherits = FALSE)) {
    why <- c(why, "latticeExtra layers were added")
  }
  panel_name <- lattice_panel_name(panel)
  if (!is.na(high_level) && high_level %in% names(LATTICE_SUPPORTED_PANELS) &&
    (is.na(panel_name) || !panel_name %in% LATTICE_SUPPORTED_PANELS[[high_level]])) {
    why <- c(why, "the panel function is not the stock one")
  }

  if (prod(dim(plot)) == 0L) {
    why <- c(why, "it has no packets")
  }

  unique(why)
}

#' The display order of each conditioning variable's levels
#'
#' What `plot.trellis()` calls `used.condlevels`: `index.cond` applied to each
#' variable's levels, the variables then permuted by `perm.cond`.
#'
#' @param plot A trellis object
#' @return A list of integer vectors, one per conditioning variable.
#' @keywords internal
lattice_used_levels <- function(plot) {
  used <- mapply(
    function(levels, index) seq_along(levels)[index],
    plot$condlevels, plot$index.cond,
    SIMPLIFY = FALSE
  )
  used[plot$perm.cond]
}

#' The layout `plot.trellis()` will use: columns, rows and pages
#'
#' A re-implementation of lattice's internal `compute.layout()`. `columns`
#' is 0 when lattice is left to choose the arrangement from the device's
#' aspect ratio at draw time; the page count never depends on the device.
#'
#' @param plot A trellis object
#' @return Numeric `c(columns, rows, pages)`.
#' @keywords internal
lattice_layout <- function(plot) {
  cond_max <- lengths(lattice_used_levels(plot))
  nplots <- prod(cond_max)
  skip <- plot$skip
  layout <- plot$layout

  if (is.null(layout)) {
    layout <- c(0, 1, 1)
    if (length(cond_max) == 1L) {
      layout[2] <- nplots
    } else {
      layout[1:2] <- cond_max[1:2]
    }
    skip <- rep(skip, length.out = max(layout[1] * layout[2], layout[2]))
    layout[3] <- ceiling(nplots / sum(!skip))
  } else {
    if (is.na(layout[1])) {
      layout[1] <- ceiling(nplots / layout[2])
    }
    if (is.na(layout[2])) {
      layout[2] <- ceiling(nplots / layout[1])
    }
    skip <- rep(skip, length.out = max(layout[1] * layout[2], layout[2]))
    if (length(layout) == 2L) {
      layout[3] <- ceiling(nplots / sum(!skip))
    }
  }

  layout
}

#' The trellis object restricted to its first page
#'
#' `plot.trellis()` draws every page, starting a new one for each, so the
#' device -- and the SVG exported from it -- ends up holding only the last
#' page. A chart laid out over several pages is read from its first, which
#' is the page a reader would come to first; the number of pages it had is
#' kept in the `maidr_pages` attribute so the caller can say what was left
#' out.
#'
#' @param plot A trellis object
#' @return The object, laid out on one page.
#' @keywords internal
lattice_first_page <- function(plot) {
  layout <- lattice_layout(plot)
  pages <- layout[3]
  if (isTRUE(pages > 1)) {
    plot$layout <- c(layout[1], layout[2], 1)
  }
  attr(plot, "maidr_pages") <- if (isTRUE(pages >= 1)) pages else 1
  plot
}

#' Draw a trellis object the way the lattice system reads it
#'
#' Always `plot.trellis()`, lattice's own drawer, which neither consults
#' `print.function` nor comes back through MAIDR's print hook, and never a
#' bare `plot()`, which inside this namespace is MAIDR's recording wrapper.
#' The layout arguments are given explicitly: `plot.trellis()` falls back to
#' `plot$plot.args` for any it is not given, and a `split =` stored there by
#' `update()` would draw the chart into part of the page. A panel function
#' that fails is not drawn around as lattice does by default: the error is
#' raised, so the chart falls back to an image rather than being read with a
#' panel missing.
#'
#' `packet.panel` is not given: it chooses which packets the page holds, not
#' where the chart goes, and `plot.trellis()` takes one stored in
#' `plot$plot.args` -- `?packet.panel.default`'s way to draw a later page --
#' when it is not.
#'
#' What is drawn is not saved as lattice's last object: it is the copy
#' [lattice_prepare()] made, which may hold only the chart's first page, and
#' `update(trellis.last.object())` would carry on from it without the pages
#' left out.
#'
#' @param plot A trellis object
#' @param prefix The grob-name prefix
#' @return NULL, invisibly
#' @keywords internal
lattice_draw <- function(plot, prefix = LATTICE_PREFIX) {
  # Looked up from lattice's namespace, which loads it: the method is only
  # registered once lattice is, and the object may still be an unevaluated
  # `lattice::xyplot(...)` at this point.
  plot_trellis <- utils::getS3method("plot", "trellis", envir = asNamespace("lattice"))
  plot_trellis(
    plot,
    prefix = prefix,
    position = NULL,
    split = NULL,
    more = FALSE,
    newpage = TRUE,
    draw.in = NULL,
    panel.error = NULL,
    save.object = FALSE
  )
  invisible(NULL)
}

#' Keep lattice's record of the chart it drew last
#'
#' lattice keeps one record, for the whole session, of the chart it drew
#' last: the chart `trellis.focus()`, `trellis.currentLayout()` and
#' `trellis.last.object()` act on, and whether a `print(more = TRUE)` page
#' is still being composed. A chart MAIDR draws to read it, or to picture it,
#' would replace the record of the reader's own chart with one of a drawing
#' no device shows, so the record is taken before and put back after -- except
#' for a print the console hook opens the viewer for, which is the reader's
#' own print of their chart.
#'
#' The record has no exported accessor. Should it ever not be where it is
#' looked for, nothing is put back and the chart is drawn all the same.
#'
#' @return A function that puts the record back as it was when this was
#'   called; it does nothing when there is nothing to put back.
#' @keywords internal
lattice_keep_status <- function() {
  status_env <- lattice_status_env()
  if (isTRUE(.maidr_lattice_state$busy) || is.null(status_env) ||
    !exists("lattice.status", envir = status_env, inherits = FALSE)) {
    return(function() invisible(NULL))
  }
  status <- get("lattice.status", envir = status_env, inherits = FALSE)
  function() {
    assign("lattice.status", status, envir = status_env)
    invisible(NULL)
  }
}

#' Whether lattice's current page is still being composed
#'
#' Read from the record [lattice_keep_status()] keeps: a chart drawn with
#' `more = TRUE` leaves its page open, and `plot.trellis()` draws the next
#' chart onto that page rather than starting one. Should the record not be
#' where it is looked for, no page is taken to be open.
#'
#' @return `TRUE` when the next chart lattice draws joins the current page.
#' @keywords internal
lattice_page_open <- function() {
  status_env <- lattice_status_env()
  status <- if (!is.null(status_env)) status_env[["lattice.status"]]
  is.list(status) && isTRUE(status[["print.more"]])
}

#' Where lattice keeps its record of the chart it drew last
#'
#' lattice's own environment, which it does not export. Read in one place,
#' so that [lattice_keep_status()] and [lattice_page_open()] find it, or
#' find it gone, the same way.
#'
#' @return The environment, or `NULL` should lattice no longer have it.
#' @keywords internal
lattice_status_env <- function() {
  status_env <- tryCatch(
    asNamespace("lattice")[[".LatticeEnv"]],
    error = function(e) NULL
  )
  if (is.environment(status_env)) status_env
}

#' A trellis object carrying the theme of the device the reader looks at
#'
#' lattice keeps a theme per kind of device and draws with the theme of the
#' device it draws on, so a chart MAIDR draws off-screen to read it would be
#' drawn with that device's own. A theme the reader set with
#' `trellis.par.set()` on the current device -- larger text, colours they can
#' tell apart -- goes with the chart as its own `par.settings`, which lattice
#' applies for that drawing only, under whatever settings the chart was given
#' itself. With no device open nothing has been set, and asking lattice would
#' open a device.
#'
#' @param plot A trellis object
#' @return The trellis object, carrying the theme.
#' @keywords internal
lattice_carry_theme <- function(plot) {
  if (grDevices::dev.cur() == 1L) {
    return(plot)
  }
  theme <- tryCatch(lattice::trellis.par.get(), error = function(e) NULL)
  if (is.list(theme)) {
    plot$par.settings <- utils::modifyList(theme, as.list(plot$par.settings))
  }
  plot
}

#' A trellis object carrying what the reader changed on MAIDR's hidden device
#'
#' A chart MAIDR moves off its hidden device onto a screen
#' ([lattice_draw_on_screen()]) is drawn with the screen's own lattice theme,
#' which holds whatever the reader set on a screen of that kind before. What
#' they set while the hidden device was current went to the hidden device's
#' kind, `pdf`, since they had no other device. So only that goes with the
#' chart, as its own `par.settings`: the settings in which the hidden device's
#' theme differs from the theme lattice starts a device of its kind with
#' ([lattice_starting_theme()]). Carried whole, the `pdf` defaults would
#' replace what the reader set on the screen's kind.
#'
#' @param plot A trellis object
#' @return The trellis object, carrying the settings the reader changed.
#' @keywords internal
lattice_carry_reader_settings <- function(plot) {
  if (grDevices::dev.cur() == 1L) {
    return(plot)
  }
  theme <- tryCatch(lattice::trellis.par.get(), error = function(e) NULL)
  if (!is.list(theme)) {
    return(plot)
  }
  changed <- lattice_changed_settings(theme, lattice_starting_theme())
  if (length(changed) > 0L) {
    plot$par.settings <- utils::modifyList(changed, as.list(plot$par.settings))
  }
  plot
}

#' The theme lattice starts a device of the current kind with
#'
#' What `trellis.device()` sets for a kind of device lattice has not drawn on
#' yet: `standard.theme()`, in colour except on `postscript()`, with the
#' `default.theme` lattice option -- a list, a function, or a function's
#' name -- over it.
#'
#' @return A lattice theme.
#' @keywords internal
lattice_starting_theme <- function() {
  kind <- names(grDevices::dev.cur())
  theme <- lattice::standard.theme(color = kind != "postscript")
  default <- lattice::lattice.getOption("default.theme")
  if (is.character(default)) {
    default <- get(default, envir = asNamespace("lattice"))
  }
  if (is.function(default)) {
    default <- default()
  }
  if (is.list(default)) {
    theme <- utils::modifyList(theme, default)
  }
  theme
}

#' The settings in which one lattice theme differs from another
#'
#' Compared setting by setting, down to the leaves: `plot.symbol$pch` changed
#' is that alone, not the whole of `plot.symbol`. A function compares without
#' its environment, as lattice builds a new one for `shade.colors$palette`
#' every time it builds a theme.
#'
#' @param theme The theme in use
#' @param base The theme it started from
#' @return A list of the settings of `theme` that differ from `base`.
#' @keywords internal
lattice_changed_settings <- function(theme, base) {
  changed <- list()
  for (name in names(theme)) {
    value <- theme[[name]]
    if (is.list(value) && is.list(base[[name]])) {
      value <- lattice_changed_settings(value, base[[name]])
      if (length(value) > 0L) {
        changed[[name]] <- value
      }
    } else if (!identical(value, base[[name]], ignore.environment = TRUE)) {
      changed[name] <- list(value)
    }
  }
  changed
}

#' Draw a picture of a trellis object: its first page, as lattice draws it
#'
#' A file holds one page, and the first is the one the interactive reading
#' of a multi-page chart describes. The picture is no print of the reader's,
#' so lattice's record of the chart it drew last is kept as it was
#' ([lattice_keep_status()]); where it is not -- a print the console hook
#' opened the viewer for -- a first page cut from a longer chart is not saved
#' as lattice's last object, where `update(trellis.last.object())` would
#' carry on from it without the pages left out.
#'
#' @param plot A trellis object
#' @return The number of pages the chart is laid out on, invisibly.
#' @keywords internal
lattice_draw_picture <- function(plot) {
  restore_status <- lattice_keep_status()
  on.exit(restore_status(), add = TRUE)
  first <- lattice_first_page(plot)
  pages <- attr(first, "maidr_pages")
  if (isTRUE(pages > 1)) {
    print_trellis_natively(first, save.object = FALSE)
  } else {
    print_trellis_natively(plot)
  }
  invisible(pages)
}

#' The text a lattice label is drawn with
#'
#' A re-implementation of lattice's `getLabelList()`: `NULL` draws nothing; a
#' character vector, expression, call or symbol is the label; a list whose
#' first element is unnamed takes that element, and a `label =` element
#' overrides it; anything else -- `TRUE`, `list(cex = 2)` -- draws the
#' default. A grob draws itself, and is read when it is a text grob.
#'
#' A label taken out of a list is drawn whatever it is, so a number there
#' reads as the number grid prints -- `list(2024, cex = 2)` draws "2024" --
#' where a bare number, `main = 2024`, is not a label and draws the default.
#'
#' @param label A `main`, `sub`, `xlab` or `ylab` field
#' @param default The label lattice draws in place of `TRUE`
#' @return A string, or `NULL` when nothing would be drawn.
#' @keywords internal
lattice_label_text <- function(label, default = NULL) {
  expression_text <- function(e) paste(deparse(e, width.cutoff = 500L), collapse = " ")
  as_text <- function(value) {
    if (is.null(value) || length(value) == 0L) {
      return(NULL)
    }
    if (is.call(value) || is.symbol(value)) {
      value <- as.expression(value)
    }
    text <- if (is.expression(value)) {
      vapply(as.list(value), expression_text, character(1))
    } else if (is.atomic(value)) {
      as.character(value)
    } else {
      return(NULL)
    }
    text <- text[!is.na(text) & nzchar(text)]
    if (length(text) == 0L) NULL else paste(text, collapse = " ")
  }

  if (is.null(label)) {
    return(NULL)
  }
  if (grid::is.grob(label)) {
    return(if (inherits(label, "text")) as_text(label$label) else NULL)
  }

  drawable <- function(x) {
    is.character(x) || is.expression(x) || is.call(x) || is.symbol(x)
  }
  text <- if (drawable(label)) {
    label
  } else if (is.list(label) && (is.null(names(label)) || names(label)[1] == "")) {
    label[[1]]
  } else {
    default
  }
  if (is.list(label) && "label" %in% names(label)) {
    text <- label[["label"]]
  }

  as_text(text)
}

#' The label a reader should hear for an axis
#'
#' What lattice draws, and otherwise the default it would have drawn. A
#' horizontal `barchart()`, `bwplot()` or `dotplot()` draws no title on its
#' category axis (`ylab` is `NULL`), and the default -- the name of the
#' variable -- says what the categories are where the renderer's generic
#' "Y" would only say where they sit.
#'
#' @param label The `xlab` or `ylab` field
#' @param default The `xlab.default` or `ylab.default` field
#' @return A string, or `NULL`.
#' @keywords internal
lattice_axis_label <- function(label, default = NULL) {
  text <- lattice_label_text(label, default)
  if (is.null(text)) {
    text <- lattice_label_text(default)
  }
  text
}

#' Whether a chart is `xyplot()` of a time series
#'
#' `xyplot()` of a time series draws it through a formula of its own making,
#' `x ~ tt`, and a chart is known by what that formula leaves: `xlab.default`
#' `"tt"` and `ylab.default` `"x"`, from a call whose data is not a formula.
#'
#' @param plot A trellis object
#' @return `TRUE` or `FALSE`
#' @keywords internal
lattice_is_time_series <- function(plot) {
  if (!identical(plot$xlab.default, "tt") || !identical(plot$ylab.default, "x")) {
    return(FALSE)
  }
  series <- lattice_call_data(plot)
  !is.null(series) && !(is.call(series) && identical(series[[1L]], as.name("~")))
}

#' The data argument of the call a chart was made by
#'
#' @param plot A trellis object
#' @return The argument as it was written -- an expression, or the value
#'   itself when the call was built with the value in it -- or `NULL`.
#' @keywords internal
lattice_call_data <- function(plot) {
  args <- as.list(plot$call)[-1L]
  if (length(args) == 0L) {
    return(NULL)
  }
  named <- names(args)
  if (!is.null(named) && "x" %in% named) {
    args[["x"]]
  } else if (is.null(named) || !nzchar(named[1])) {
    args[[1L]]
  }
}

#' The name of the series a time-series chart draws
#'
#' `xyplot()` of a time series titles no value axis, so the default a
#' reader would hear for every value is the name of its own variable, "x".
#' The series is named as a formula's variable would be instead: by the
#' expression the chart was made from -- `xyplot(ldeaths)` reads "ldeaths is
#' 3035" ([lattice_is_time_series()]).
#'
#' @param plot A trellis object
#' @return A string; `NULL` for a chart that is not of a time series, or
#'   whose series was handed over as a value rather than named.
#' @keywords internal
lattice_series_name <- function(plot) {
  if (!lattice_is_time_series(plot)) {
    return(NULL)
  }
  series <- lattice_call_data(plot)
  if (!(is.symbol(series) || is.call(series))) {
    return(NULL)
  }
  lattice_label_text(series)
}

#' The strip title of one packet
#'
#' One level per conditioning variable, in formula order, joined with
#' `" & "` as a ggplot2 facet title is. A shingle's level is an interval,
#' which lattice draws as a shaded bar under the variable's name, so it is
#' named with the variable: `"equal.count(wt, 3) [ 2.6175, 3.5725 ]"`.
#' Read from `condlevels` rather than from the drawn strips, whose text is
#' not reliable: some strip styles draw every level under one grob.
#'
#' An unconditioned chart has one packet, under a variable lattice makes up
#' and leaves unnamed. `outer = TRUE` conditions on the variables of an
#' extended formula (`a + b ~ x`) through a variable left unnamed too, whose
#' levels are those variables' names, so the name alone does not tell the
#' two apart.
#'
#' A strip made by `strip.custom(factor.levels = , var.name = )` draws those
#' in place of the levels and names lattice hands it, and is read as drawn.
#' A factor's name is drawn only when the strip asks for it, as
#' `strip.custom(strip.names = TRUE)` does, and then before its level across
#' the strip's `sep`, so the packet is read `"cyl : 4"` as it is drawn.
#'
#' @param plot A trellis object
#' @param level_index The packet's level index for each variable
#' @return A string, `""` for an unconditioned chart.
#' @keywords internal
lattice_packet_label <- function(plot, level_index) {
  names <- names(plot$condlevels)
  unconditioned <- is.null(names) && prod(lengths(plot$condlevels)) == 1L
  if (length(level_index) == 0L || unconditioned) {
    return("")
  }
  custom <- lattice_strip_args(plot)
  # `strip.default()` recycles `strip.names` over a factor and a shingle, in
  # that order, and writes a factor's name out in styles 1 and 3 alone; the
  # others draw the levels by themselves.
  shows_name <- rep_len(as.logical(custom$strip.names %||% FALSE), 2L)[1] &&
    (custom$style %||% 1) %in% c(1, 3)
  sep <- as.character(custom$sep %||% " : ")
  parts <- vapply(seq_along(level_index), function(i) {
    levels <- plot$condlevels[[i]]
    text <- as.character(levels)[level_index[i]]
    name <- if (is.null(names)) "" else names[i]
    if (i <= length(custom$var.name)) {
      name <- as.character(custom$var.name)[i]
    }
    if (inherits(levels, "shingleLevel") && nzchar(name)) {
      return(paste(name, text))
    }
    if (level_index[i] <= length(custom$factor.levels)) {
      text <- as.character(custom$factor.levels)[level_index[i]]
    }
    if (isTRUE(shows_name) && nzchar(name)) paste0(name, sep, text) else text
  }, character(1))
  paste(parts, collapse = " & ")
}

#' The arguments a chart's `strip.custom()` strip was made with
#'
#' `strip.custom(...)` returns a strip function that keeps its arguments in
#' its enclosure, as `args`, and hands them to `strip.default()` over the
#' ones lattice passes -- so a `factor.levels` given there is drawn for
#' every conditioning variable, indexed by the packet's level of it, and a
#' `var.name` indexed by the variable. The top strip wins over the left.
#'
#' @param plot A trellis object
#' @return A list, empty when neither strip was made by `strip.custom()`.
#' @keywords internal
lattice_strip_args <- function(plot) {
  made <- body(lattice::strip.custom())
  for (strip in list(plot$strip, plot$strip.left)) {
    if (is.function(strip) && identical(body(strip), made)) {
      args <- get0("args", envir = environment(strip), inherits = FALSE)
      if (is.list(args)) {
        return(args)
      }
    }
  }
  list()
}

#' The names a chart's key gives its groups
#'
#' `auto.key` draws one entry per group, in the order lattice numbers them,
#' each labelled by its level unless the key's `text` says otherwise. That
#' text is what the legend shows a sighted reader, so the group is named by
#' it. A key given as `key =` is the user's own drawing and says nothing
#' about which group an entry stands for, so it names none.
#'
#' @param plot A trellis object
#' @return Character vector, or `NULL` when the chart has no groups.
#' @keywords internal
lattice_group_names <- function(plot) {
  levels <- lattice_group_levels(plot)
  for (legend in plot$legend) {
    text <- if (identical(legend$fun, "drawSimpleKey")) legend$args$text
    n <- min(length(text), length(levels))
    if (n > 0L) {
      levels[seq_len(n)] <- as.character(text)[seq_len(n)]
      break
    }
  }
  levels
}

#' The names of a chart's groups, in the order lattice numbers them
#'
#' `panel.superpose()` numbers groups over the levels of a factor, or the
#' sorted unique values of anything else, across the whole chart; the
#' `.group.<k>` in a grob's name indexes this vector. A level no panel draws
#' keeps its number.
#'
#' @param plot A trellis object
#' @return Character vector, or `NULL` when the chart has no groups.
#' @keywords internal
lattice_group_levels <- function(plot) {
  groups <- plot$panel.args.common[["groups"]]
  if (is.null(groups)) {
    return(NULL)
  }
  as.character(if (is.factor(groups)) levels(groups) else sort(unique(groups)))
}

#' The plot types one group of a panel is drawn with
#'
#' `panel.superpose()` draws every group with the whole `type` vector,
#' unless `distribute.type = TRUE`, when group `k` is drawn with the `k`-th
#' type alone -- the vector recycled over the groups, so with three groups
#' `type = c("s", "l")` draws the third as a staircase again.
#'
#' @param args The panel's arguments, as its panel function received them
#' @param group The group's number (see [lattice_group_levels()]), or NA for
#'   an ungrouped panel
#' @return The `type` the group is drawn with, `NULL` when none was given.
#' @keywords internal
lattice_group_type <- function(args, group) {
  type <- args[["type"]]
  if (isTRUE(args[["distribute.type"]]) && length(type) > 0L &&
    length(group) == 1L && !is.na(group)) {
    type <- type[[(as.integer(group) - 1L) %% length(type) + 1L]]
  }
  type
}

#' The title of the variable a chart is grouped by
#'
#' The key's own title when it has one, otherwise the expression the chart
#' was grouped by, as `groups = factor(gear)` reads.
#'
#' @param plot A trellis object
#' @return A string, or `NULL`.
#' @keywords internal
lattice_group_title <- function(plot) {
  for (legend in plot$legend) {
    title <- legend$args$title
    if (is.null(title)) {
      title <- legend$args$key$title
    }
    text <- lattice_label_text(title)
    if (!is.null(text)) {
      return(text)
    }
  }
  groups <- plot$call$groups
  if (is.symbol(groups) || is.call(groups)) {
    paste(deparse(groups, width.cutoff = 500L), collapse = " ")
  } else {
    NULL
  }
}

#' Undo a lattice log scale
#'
#' lattice stores and draws a log-scale axis in log units; `log = TRUE`
#' means base 10 and `"e"` the natural logarithm.
#'
#' @param values Numeric values in the units lattice drew them in
#' @param log The axis' `log` scale component
#' @return The values on the data's own scale.
#' @keywords internal
lattice_untransform <- function(values, log) {
  if (is.null(log) || isFALSE(log)) {
    return(values)
  }
  base <- if (isTRUE(log)) {
    10
  } else if (identical(log, "e")) {
    exp(1)
  } else {
    suppressWarnings(as.numeric(log))
  }
  if (length(base) != 1L || is.na(base)) {
    return(values)
  }
  base^values
}

#' The id of an exported grob, escaped for a CSS selector
#'
#' The exporter writes a grob named `N` as `<g id="N.1">`, the `.1` counting
#' draws of that name. lattice grob names can hold spaces as well as dots --
#' `panel.densityplot()` names its rug `density rug.x` -- so every character
#' outside `[A-Za-z0-9_-]` is escaped, not only the dots.
#'
#' @param grob_name The grob's name
#' @return The escaped id of the grob's `<g>`.
#' @keywords internal
lattice_css_id <- function(grob_name) {
  gsub("([^A-Za-z0-9_-])", "\\\\\\1", paste0(grob_name, ".1"))
}

#' A selector for the shapes one lattice grob drew
#'
#' @param grob_name The grob's name
#' @param element The SVG element its shapes are exported as: `use` for
#'   points, `polyline` for lines and segments, `rect`, `polygon`
#' @return A selector string.
#' @keywords internal
lattice_grob_selector <- function(grob_name, element) {
  paste0("g#", lattice_css_id(grob_name), " > ", element)
}

#' A selector for the one shape at a position within a lattice grob
#'
#' @param grob_name The grob's name
#' @param index The shape's position in the grob, 1-based, as the exporter
#'   numbers it: a shape that was not drawn keeps its number
#' @return A selector string.
#' @keywords internal
lattice_shape_selector <- function(grob_name, index) {
  paste0("#", lattice_css_id(grob_name), "\\.", index)
}
