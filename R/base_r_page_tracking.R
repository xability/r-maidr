# The page and panel R draws each recorded Base R call on.
#
# R's device shows one page: the last. A high-level plot starts a new page
# when it moves past the last panel of the page it is on -- every plot on a
# page of one panel, the fifth under `par(mfrow = c(2, 2))`, the first after
# `par(mfrow = )`, `par(mfcol = )` or `layout()` sets a page up again --
# while one drawn after `par(new = TRUE)` stays in the panel of the plot
# before it, and one drawn with `add = TRUE` starts no plot at all.
# `plot.new()` and `frame()` move on a panel as a plot does.
#
# R says which a plot does just before it does it: `par("page")` is TRUE
# when the next `plot.new()` starts a page, and `par("new")` when it stays
# in the panel of the last plot. R calls the `before.plot.new` hook at that
# moment for every plot, whatever starts it -- a recorded call, a
# `plot.new()` or `frame()` the author called directly, a function that
# draws several plots or sets up a layout of its own, as `heatmap()` does.
# So the hook follows, on each device, the page R is on, the panel and the
# number of the plot on that page, and every recorded call is stamped with
# them (`log_plot_call_to_device()`): a chart is read from the calls on the
# last page (`last_page_calls()`), each plot in the panel R drew it in
# (`compute_panel_slots()`). Simulating R's rule from the recorded calls
# instead would have to know what each function does to the page, and
# would miss the calls that are not recorded at all.
#
# Once it has started a plot, R says where it put it, and the `plot.new`
# hook reads it: `par("mfg")`, the cell of the grid, which `par(mfg = )`
# can move a plot to out of turn, and `par("fig")`, the region of the page,
# which `par(fig = )` sets for an inset and `screen()` for a screen of
# `split.screen()`, outside any grid. A plot is drawn again where R drew it
# from them (`replay_page()`).

.maidr_base_r_pages <- new.env(parent = emptyenv())
# Where R is on each device, by device number: the pages it has started
# since maidr was loaded, and the panel and the plot it is on in the last.
# Counted while recording is off too: a page drawn then is no less the page
# R shows, and a call recorded after it is on it.
# Only the order of the pages matters: a device's count runs on when its
# calls are cleared, or when a device of the same number replaces it.
.maidr_base_r_pages$at <- list()
# The recorded calls drawing on each device (`begin_base_r_call()`), by
# device number, the one drawing now last: a recorded call can make
# another, as `plot(x, panel.first = grid())` does, or a method an author
# wrote for `plot()` of their own class that calls `plot()` and `lines()`.
# Each keeps where the plot it started first on its last page is, and
# whether it started a plot itself rather than through a call it made.
.maidr_base_r_pages$calls <- list()
# The number the next recorded call is known by, while it draws and once
# it is recorded (`standalone_calls()`).
.maidr_base_r_pages$next_id <- 1L
# What names this R session in the marks its recorded calls leave on the
# pages they are drawn on (`mark_base_r_page()`), set once one is made.
.maidr_base_r_pages$session <- NULL
# Whether the plot R is starting opens the device it is drawn on: started
# with no device open, it is counted once it is (`note_base_r_plot_started()`).
.maidr_base_r_pages$opening <- FALSE
# What maidr last let go of on each device, by device number
# (`note_base_r_calls_cleared()`).
.maidr_base_r_pages$let_go <- list()

#' Where R is drawing, on a device
#'
#' @param device_id Graphics device ID
#' @return A list: `page`, the pages R has started on the device since
#'   maidr was loaded; `figure`, the panel of the last page it is in, and
#'   `plot`, the plots started on that page. Each 0 for none.
#' @keywords internal
#' @noRd
base_r_device_position <- function(device_id = grDevices::dev.cur()) {
  .maidr_base_r_pages$at[[as.character(device_id)]] %||%
    list(page = 0L, figure = 0L, plot = 0L)
}

#' Follow a plot R starts: the `before.plot.new` hook
#'
#' Called by `plot.new()` for every plot, before it is started; see the top
#' of this file. A plot started with no device open opens a device, and is
#' counted once it has (`note_base_r_plot_started()`).
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
note_base_r_plot_new <- function() {
  tryCatch(
    {
      device <- grDevices::dev.cur()
      .maidr_base_r_pages$opening <- device == 1L
      if (device != 1L) {
        key <- as.character(device)
        at <- base_r_device_position(device)
        # One query: the hook runs for every plot, recorded or not.
        next_plot <- graphics::par(c("page", "new"))
        if (isTRUE(next_plot$page)) {
          at <- list(page = at$page + 1L, figure = 1L, plot = 1L, opened = TRUE)
        } else {
          if (!isTRUE(next_plot$new)) {
            at$figure <- at$figure + 1L
          }
          at$plot <- at$plot + 1L
          at$opened <- FALSE
        }
        .maidr_base_r_pages$at[[key]] <- at
        drawing <- .maidr_base_r_pages$calls[[key]]
        # The plot is the first on this page of the call drawing it, and of
        # each that made that call, out to one whose arguments it was made
        # from (`begin_base_r_call()`), which drew nothing of its own yet.
        for (i in rev(seq_along(drawing))) {
          if (!identical(drawing[[i]]$first$page, at$page)) {
            drawing[[i]]$first <- at
          }
          if (is.null(drawing[[i]]$start)) {
            drawing[[i]]$start <- at
          }
          if (isTRUE(drawing[[i]]$apart)) {
            break
          }
        }
        if (length(drawing) > 0L) {
          drawing[[length(drawing)]]$own_plot <- TRUE
          .maidr_base_r_pages$calls[[key]] <- drawing
        }
      }
    },
    error = function(e) NULL
  )
  invisible(NULL)
}

#' Leave a mark of a recorded call on the page it was drawn on
#'
#' R does not call the `before.plot.new` hook when `replayPlot()` puts a
#' page back on a device, from a plot `recordPlot()` saved, as RStudio's
#' plot history does too, and the page R shows is then not the last it
#' started; nor, for a page saved before all of it was drawn, all of that
#' page. What R shows is the device's display list, which a device keeps
#' when it can redraw its page. Each recorded call leaves a mark on it: a
#' `par()` setting that sets `lheight` to the value it has, so draws nothing
#' and changes nothing, carrying the call's number in this session. The
#' display list says which of the calls are on the page R shows
#' (`base_r_display_list_marks()`). A device that keeps no display list
#' keeps no mark, and replays no page.
#'
#' Any reader of the display list replays the mark as the `par()` call it
#' is: R's own replay, `dev.copy()`, a saved plot replayed in a session
#' without maidr, and gridGraphics, whose `grid.echo()` maidr draws its
#' charts with, and which cannot replay an entry made with
#' `grDevices::recordGraphics()`. Not in a knit, where knitr replays each
#' figure and the chart's own markers say which it is (see
#' knitr_figure_map.R).
#'
#' @param id The number the call is known by (`end_base_r_call()`)
#' @param device_id The device the call was drawn on
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
mark_base_r_page <- function(id, device_id = grDevices::dev.cur()) {
  elsewhere <- !identical(as.integer(device_id), as.integer(grDevices::dev.cur()))
  if (is.null(id) || elsewhere || isTRUE(getOption("knitr.in.progress"))) {
    return(invisible(NULL))
  }
  state <- .maidr_base_r_pages
  if (is.null(state$session)) {
    state$session <- paste0(Sys.getpid(), "-", format(unclass(Sys.time()), digits = 16))
  }
  tryCatch(
    graphics::par(structure(
      list(lheight = graphics::par("lheight")),
      maidr_mark = paste0(state$session, ":", id)
    )),
    error = function(e) NULL
  )
  invisible(NULL)
}

#' The recorded calls a device's display list holds
#'
#' The marks the recorded calls left on the page R shows
#' (`mark_base_r_page()`), read from the display list of the device, which
#' holds that page from its start: after `replayPlot()` put a page back,
#' the page it put back, and only what had been drawn on it when
#' `recordPlot()` saved it, with what was drawn on it since. A page that
#' holds none of this session's marks holds no call maidr recorded: one
#' drawn while `maidr_off()` was in effect, or saved in another session,
#' that `replayPlot()` put back. Not in a knit, where no call leaves a mark.
#' `NULL` where the device keeps no display list, or one that does not hold
#' its page from the start, as one `dev.control("enable")` turned on with a
#' plot already drawn does; or where no call of this session left a mark.
#'
#' @param device_id Graphics device ID
#' @return `NULL`, or a list: `ids`, the numbers of the calls marked on it
#'   (see `end_base_r_call()`), and `plots`, the number of plots R had
#'   started on the page when each was done; each empty for none
#' @keywords internal
#' @noRd
base_r_display_list_marks <- function(device_id = grDevices::dev.cur()) {
  session <- .maidr_base_r_pages$session
  if (is.null(session) || isTRUE(getOption("knitr.in.progress")) ||
        !(as.integer(device_id) %in% grDevices::dev.list())) {
    return(NULL)
  }
  current <- grDevices::dev.cur()
  if (current != device_id) {
    grDevices::dev.set(device_id)
    on.exit(grDevices::dev.set(current), add = TRUE)
  }
  entries <- tryCatch(suppressWarnings(grDevices::recordPlot())[[1L]], error = function(e) NULL)
  if (!is.list(entries) || length(entries) == 0L) {
    return(NULL)
  }
  names <- vapply(entries, display_list_entry_name, character(1))
  # A page R started begins with the plot that started it; a list turned
  # on later begins with whatever was drawn next.
  if (!identical(names[[1L]], "C_plot_new")) {
    return(NULL)
  }
  prefix <- paste0(session, ":")
  started <- cumsum(names == "C_plot_new")
  ids <- integer()
  plots <- integer()
  for (i in which(names == "C_par")) {
    mark <- attr(entries[[i]][[2L]][[2L]], "maidr_mark", exact = TRUE)
    if (is.character(mark) && length(mark) == 1L && startsWith(mark, prefix)) {
      ids <- c(ids, as.integer(substring(mark, nchar(prefix) + 1L)))
      plots <- c(plots, started[[i]])
    }
  }
  list(ids = ids, plots = plots)
}

#' The name of the graphics operation an entry of a display list records
#'
#' @param entry An entry of `recordPlot()[[1]]`
#' @return The name of the C routine, such as `"C_plot_new"` or
#'   `"C_par"`; `""` for an entry that names none
#' @keywords internal
#' @noRd
display_list_entry_name <- function(entry) {
  args <- if (is.list(entry) && length(entry) >= 2L) entry[[2L]]
  routine <- if (is.list(args) && length(args) >= 1L) args[[1L]]
  if (inherits(routine, "NativeSymbolInfo") && is.character(routine$name)) {
    routine$name[[1L]]
  } else {
    ""
  }
}

#' Note where R put the plot it started: the `plot.new` hook
#'
#' Called by `plot.new()` once the plot is started; see the top of this
#' file. The cell (`par("mfg")`: its row and column, and the grid's rows
#' and columns) and the region of the page (`par("fig")`) are kept with the
#' plot's place, and with that of each recorded call this plot is the
#' first of on its page. A plot started with no device open, as
#' `plot.new()` or `frame()` is to begin a drawing, opened the device it
#' is on: it is the first plot of the device's first page, which R
#' started with it, as the `before.plot.new` hook could not say.
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
note_base_r_plot_started <- function() {
  tryCatch(
    {
      device <- grDevices::dev.cur()
      key <- as.character(device)
      at <- .maidr_base_r_pages$at[[key]]
      if (device != 1L && isTRUE(.maidr_base_r_pages$opening)) {
        .maidr_base_r_pages$opening <- FALSE
        at <- list(page = (at$page %||% 0L) + 1L, figure = 1L, plot = 1L, opened = TRUE)
      }
      if (device != 1L && !is.null(at)) {
        before <- at[c("page", "plot")]
        placed <- graphics::par(c("mfg", "fig"))
        at$cell <- as.integer(placed$mfg)
        at$fig <- placed$fig
        .maidr_base_r_pages$at[[key]] <- at
        drawing <- .maidr_base_r_pages$calls[[key]]
        for (i in seq_along(drawing)) {
          if (identical(drawing[[i]]$first[c("page", "plot")], before)) {
            drawing[[i]]$first <- at
          }
        }
        .maidr_base_r_pages$calls[[key]] <- drawing
      }
    },
    error = function(e) NULL
  )
  invisible(NULL)
}

# The hooks that follow the plots R starts, by the hook R calls each from.
base_r_page_hooks <- function() {
  list(before.plot.new = note_base_r_plot_new, plot.new = note_base_r_plot_started)
}

#' Follow the plots R starts, from now on
#'
#' Set when maidr is loaded, and again, where something took them out,
#' before each recorded call draws (`ensure_maidr_device()`); `.onUnload()`
#' removes them (`remove_base_r_page_hook()`).
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
set_base_r_page_hook <- function() {
  hooks <- base_r_page_hooks()
  for (name in names(hooks)) {
    if (!any(vapply(getHook(name), identical, logical(1), hooks[[name]]))) {
      setHook(name, hooks[[name]])
    }
  }
  invisible(NULL)
}

#' Stop following the plots R starts
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
remove_base_r_page_hook <- function() {
  hooks <- base_r_page_hooks()
  for (name in names(hooks)) {
    set <- getHook(name)
    keep <- !vapply(set, identical, logical(1), hooks[[name]])
    if (!all(keep)) {
      setHook(name, set[keep], action = "replace")
    }
  }
  invisible(NULL)
}

#' The recorded calls on the page R shows
#'
#' The calls drawn on the page R's device is on, and every layout call:
#' `par()` and `layout()` draw nothing, and what they set holds on every
#' page after them. A call recorded without a page, by code that records
#' calls itself, is kept. A page R started since the last call maidr
#' recorded -- with `plot.new()`, a plot maidr does not record, or one drawn
#' while `maidr_off()` was in effect -- holds none of the calls recorded
#' before it, and they are all left out.
#'
#' @param calls Recorded call entries, in the order they were recorded
#' @param page The page R's device is on (`base_r_device_position()`);
#'   `NULL` for the last page any call was drawn on
#' @return The entries R's device shows, in the same order
#' @keywords internal
#' @noRd
last_page_calls <- function(calls, page = NULL) {
  pages <- vapply(
    calls,
    function(entry) {
      if (identical(entry$class_level, "LAYOUT") || is.null(entry$page)) {
        NA_real_
      } else {
        as.numeric(entry$page)
      }
    },
    numeric(1)
  )
  if (all(is.na(pages))) {
    return(calls)
  }
  shown <- max(c(page, pages), na.rm = TRUE)
  calls[is.na(pages) | pages == shown]
}

#' The recorded calls on the page a device's display list holds
#'
#' The calls whose marks the display list holds (`base_r_display_list_marks()`),
#' and every layout call, as `last_page_calls()` keeps them. Each is
#' numbered among the plots of that page as the list numbers it: a call
#' drawn after `replayPlot()` put a page back was numbered by the
#' `before.plot.new` hook from the page R had drawn before, which the
#' replay did not tell it of. The panel R's count reached moves by as much
#' (`figure`), where no plot of the page it replaced was drawn over
#' another; R's cell (`cell`) places it in any case.
#'
#' @param calls Recorded call entries, in the order they were recorded
#' @param marks The marks on the display list, from
#'   `base_r_display_list_marks()`, or `NULL`
#' @return The entries, in the same order: only layout calls, where the
#'   list holds no recorded call, as on a page `replayPlot()` put back that
#'   holds none; `NULL` where `marks` is
#' @keywords internal
#' @noRd
marked_page_calls <- function(calls, marks) {
  if (is.null(marks)) {
    return(NULL)
  }
  ids <- vapply(calls, function(call) call$id %||% NA_integer_, integer(1))
  kept <- list()
  for (i in seq_along(calls)) {
    call <- calls[[i]]
    unmarked <- identical(call$class_level, "LAYOUT") || is.null(call$page)
    if (!unmarked && !(ids[[i]] %in% marks$ids)) {
      next
    }
    plots <- marks$plots[match(ids[[i]], marks$ids)]
    if (!unmarked && length(call$end_plot) == 1L && !is.na(plots)) {
      moved <- plots - call$end_plot
      for (field in c("plot", "end_plot", "figure", "end_figure")) {
        if (length(call[[field]]) == 1L) {
          call[[field]] <- call[[field]] + moved
        }
      }
    }
    kept <- c(kept, list(call))
  }
  kept
}

#' The recorded calls a device shows
#'
#' Those on the page its display list holds (`marked_page_calls()`), or,
#' where it keeps none that says, on the page it is on
#' (`last_page_calls()`); each drawing once (`standalone_calls()`).
#'
#' @param device_id Graphics device ID
#' @return The entries, in the order they were recorded
#' @keywords internal
#' @noRd
shown_device_calls <- function(device_id = grDevices::dev.cur()) {
  calls <- get_device_calls(device_id)
  shown <- marked_page_calls(calls, base_r_display_list_marks(device_id)) %||%
    last_page_calls(calls, base_r_device_position(device_id)$page)
  standalone_calls(shown)
}

#' Whether the page a device shows holds no plot maidr recorded
#'
#' Something was drawn on the device, but no plot maidr recorded is on the
#' page R shows: R started that page with `plot.new()` or `frame()`, with a
#' plot maidr does not record, or with one drawn while `maidr_off()` was in
#' effect, or `replayPlot()` put back a page drawn so, or saved in another
#' session or on another device; and anything recorded on it since is a
#' low-level call that started no plot, such as `lines()` or `text()`. A
#' device holding only layout calls has drawn nothing, and is not such a
#' device.
#'
#' @param device_id Graphics device ID
#' @return Logical
#' @keywords internal
#' @noRd
base_r_page_without_plot <- function(device_id = grDevices::dev.cur()) {
  drawn <- vapply(
    get_device_calls(device_id),
    function(call) call$class_level %in% c("HIGH", "LOW"),
    logical(1)
  )
  plots <- vapply(
    shown_device_calls(device_id),
    starts_base_r_plot,
    logical(1)
  )
  any(drawn) && !any(plots)
}

#' Start following a recorded call as it draws
#'
#' Called by every recording wrapper before it draws (`ensure_maidr_device()`).
#' A call that made it while drawing still draws; one in a frame as deep as
#' this or deeper is done, without having been recorded -- it stopped with an
#' error, or drew nothing, as `hist(x, plot = FALSE)` does -- and is no
#' longer followed.
#'
#' @param device_id The device it draws on
#' @param depth The number of the wrapper's frame (`sys.parent()` in it)
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
begin_base_r_call <- function(device_id = grDevices::dev.cur(), depth = 0L) {
  key <- as.character(device_id)
  drawing <- Filter(function(call) call$depth < depth, .maidr_base_r_pages$calls[[key]])
  id <- .maidr_base_r_pages$next_id
  .maidr_base_r_pages$next_id <- id + 1L
  # The shape of the grid the call starts in: one it lays out itself, as
  # `pairs()` and `heatmap()` do, gives its plots cells of another.
  grid <- tryCatch(as.integer(graphics::par("mfg")[3:4]), error = function(e) NULL)
  # Made from the frame the call drawing now was made from, so while its
  # arguments were evaluated -- the `barplot()` of `text(barplot(h), h)` --
  # rather than by its body, before it drew a plot of its own: it draws
  # before that call, which draws over it once it has.
  outer <- if (length(drawing) > 0L) drawing[[length(drawing)]]
  caller <- if (depth >= 1L) sys.parents()[depth] else NA_integer_
  apart <- !is.null(outer) && isTRUE(caller < outer$depth) && !isTRUE(outer$own_plot)
  .maidr_base_r_pages$calls[[key]] <- c(
    drawing,
    list(list(depth = depth, id = id, grid = grid, apart = apart))
  )
  invisible(NULL)
}

#' Where a recorded call was drawn, once it has drawn
#'
#' The page it ended on, and the panel and number of the plot it started
#' first on that page; for a call that started no plot -- `lines()`, or a
#' plot drawn with `add = TRUE` -- the panel and plot it drew on.
#'
#' @param device_id The device it drew on
#' @param depth The number of the wrapper's frame, as `begin_base_r_call()`
#'   was given it
#' @return A list: `page`, `figure`, `plot`, `cell` and `fig`, where R put
#'   that plot (`note_base_r_plot_started()`), `new_plot`, whether the call
#'   started a plot, and `end_figure`, `end_plot` and `end_cell`, the panel,
#'   plot and cell R was on when the call was done, and `window`, the
#'   coordinates of that plot then (`base_r_plot_window()`); `drawn_cell`
#'   and `drawn_fig`, the cell and region of the page R was drawing in
#'   then, which `par(mfg = )` and `screen()` move to another plot's
#'   without starting one (`base_r_drawing_region()`); `opens_page`, whether R started a
#'   page with the plot the call started first on it, which under a grid
#'   is in the grid's first panel (`plot_in_grid()`), and `laid_out`,
#'   whether that plot is in a grid of another shape than the one the call
#'   started in, which it laid out itself; `id`, the number the
#'   call is known by,
#'   `outer`, the number of the recorded call that made it while drawing,
#'   if one did, `apart`, whether it was made from that call's arguments
#'   before that call drew a plot of its own, and `own_plot`, whether it
#'   started a plot itself (see `standalone_calls()`); and `spans_pages`,
#'   whether the call started its first plot on a page before its last, as
#'   a call that draws several plots, as `plot()` of a fitted model does,
#'   can, and `start_figure`, the panel of that plot. Only `page`
#'   for a call no recording wrapper drew, recorded by code that records
#'   calls itself.
#' @keywords internal
#' @noRd
end_base_r_call <- function(device_id = grDevices::dev.cur(), depth = 0L) {
  key <- as.character(device_id)
  at <- base_r_device_position(device_id)
  drawing <- .maidr_base_r_pages$calls[[key]]
  depths <- vapply(drawing, function(call) call$depth, integer(1))
  this <- match(depth, depths)
  if (is.na(this)) {
    return(list(page = at$page))
  }
  call <- drawing[[this]]
  .maidr_base_r_pages$calls[[key]] <- drawing[seq_len(this - 1L)]
  started <- !is.null(call$first)
  first <- if (started) call$first else at
  region <- base_r_drawing_region()
  list(
    page = at$page,
    figure = first$figure,
    plot = first$plot,
    cell = first$cell,
    fig = first$fig,
    new_plot = started,
    spans_pages = started && isTRUE(call$start$page < at$page),
    start_figure = call$start$figure,
    opens_page = started && isTRUE(first$opened),
    laid_out = started && length(call$grid) == 2L && length(first$cell) == 4L &&
      !identical(call$grid, as.integer(first$cell[3:4])),
    end_figure = at$figure,
    end_plot = at$plot,
    end_cell = at$cell,
    window = base_r_plot_window(),
    drawn_cell = region$cell,
    drawn_fig = region$fig,
    id = call$id,
    outer = if (this > 1L) drawing[[this - 1L]]$id,
    apart = isTRUE(call$apart),
    own_plot = isTRUE(call$own_plot)
  )
}

#' The coordinates the plot R is drawing on has
#'
#' A low-level call drawn on a plot no recorded call started -- a panel
#' `plot.new()` or `frame()` took, or a plot maidr does not record, such as
#' `smoothScatter()` -- is drawn again on a plot started for it, in these
#' coordinates (`replay_page()`): what set them was not recorded.
#'
#' @return A list: `usr`, `par("usr")`, and `xlog` and `ylog`; or NULL
#' @keywords internal
#' @noRd
base_r_plot_window <- function() {
  tryCatch(graphics::par(c("usr", "xlog", "ylog")), error = function(e) NULL)
}

#' Where on the page R is drawing
#'
#' The cell of the grid (`par("mfg")`) and the region of the page
#' (`par("fig")`) a low-level call draws in. They are those of the plot R
#' started last, until `par(mfg = )`, or `screen()` of `split.screen()`,
#' sends R back to the cell or screen of another without starting a plot:
#' what is drawn then is drawn there, on that plot (`group_device_calls()`).
#'
#' @return A list: `cell`, the row and column and the grid's rows and
#'   columns, and `fig`; or NULL
#' @keywords internal
#' @noRd
base_r_drawing_region <- function() {
  tryCatch(
    {
      region <- graphics::par(c("mfg", "fig"))
      list(cell = as.integer(region$mfg), fig = region$fig)
    },
    error = function(e) NULL
  )
}

#' The recorded calls that stand for a drawing, each once
#'
#' A recorded call made by another as it drew -- `grid()` given as
#' `plot(x, panel.first = grid())`, or the `plot()` and `lines()` an
#' author's own method for `plot()` calls -- is recorded as it finishes,
#' before the call that made it. Read as a call of its own, it took the
#' place of the plot before it, and was drawn twice, once by the call that
#' made it. So where the call that made it started a plot itself, that call
#' stands for the drawing, and those it made are left out: drawn again, it
#' makes them again. Where it started none, as the method that only calls
#' `plot()` and `lines()` does, the calls it made stand for it, and it is
#' left out: what it drew is theirs. Layout calls are kept.
#'
#' A call made from another's arguments before that one drew a plot of its
#' own (`apart`, see `begin_base_r_call()`) -- the `barplot()` of
#' `text(barplot(h), h, labels)` -- is drawn before it, and not again by
#' it, which is given the value it returned: both stand. The labels were
#' left out of the chart and the drawing.
#'
#' @param calls Recorded call entries, in the order they were recorded
#' @return The entries that stand, in the same order
#' @keywords internal
#' @noRd
standalone_calls <- function(calls) {
  ids <- vapply(calls, function(call) call$id %||% NA_integer_, integer(1))
  outers <- vapply(calls, function(call) call$outer %||% NA_integer_, integer(1))
  apart <- vapply(calls, function(call) isTRUE(call$apart), logical(1))
  made <- !is.na(ids) & ids %in% outers[!apart]
  stands <- function(i) {
    if (identical(calls[[i]]$class_level, "LAYOUT")) {
      return(TRUE)
    }
    if (made[[i]] && !isTRUE(calls[[i]]$own_plot)) {
      return(FALSE)
    }
    if (apart[[i]]) {
      return(TRUE)
    }
    outer <- if (is.na(outers[[i]])) NA_integer_ else match(outers[[i]], ids)
    is.na(outer) || !stands(outer)
  }
  calls[vapply(seq_along(calls), stands, logical(1))]
}

#' Note that the calls recorded on a device were let go of
#'
#' `show()` and `save_html()` let go of the calls recorded on a device once
#' they have read its page (`clear_device_storage()`): of that page's, and
#' of those of every page before it. What is drawn on that page afterwards
#' is all that is recorded on it, and may start no plot, as a line added to
#' the plot they read does not. So is what is drawn on a page from before
#' it that `replayPlot()` puts back. Noted with where R is on the device,
#' until R starts a page there (`note_base_r_plot_new()`), and for the
#' device, until its calls are let go of again: the numbers of the calls
#' on the page read, from the first to the last, and of the last call
#' recorded then (`base_r_page_let_go()`).
#'
#' @param device_id Graphics device ID
#' @param read The numbers of the calls on the page read
#'   (`end_base_r_call()`)
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
note_base_r_calls_cleared <- function(device_id, read = integer()) {
  key <- as.character(device_id)
  if (!is.null(.maidr_base_r_pages$at[[key]])) {
    .maidr_base_r_pages$at[[key]]$cleared <- TRUE
  }
  .maidr_base_r_pages$let_go[[key]] <- list(
    read = if (length(read) > 0L) range(read),
    upto = .maidr_base_r_pages$next_id - 1L
  )
  invisible(NULL)
}

#' Whether, and how, maidr let go of the plot on the page a device shows
#'
#' maidr let go of the calls recorded on the device
#' (`note_base_r_calls_cleared()`), and the page R shows holds a plot of
#' theirs. Where the device keeps a display list, it says which calls are
#' on that page (`base_r_display_list_marks()`): those no longer recorded
#' are on the page the earlier `show()` or `save_html()` read, or on one
#' drawn before it that `replayPlot()` has put back since. Where it keeps
#' none, the page is the one read until R starts another.
#'
#' @param device_id Graphics device ID
#' @return `"read"`, where the page is the one read; `"put back"`, where
#'   it is one drawn before it; or NULL
#' @keywords internal
#' @noRd
base_r_page_let_go <- function(device_id = grDevices::dev.cur()) {
  marks <- base_r_display_list_marks(device_id)
  if (is.null(marks)) {
    return(if (isTRUE(base_r_device_position(device_id)$cleared)) "read")
  }
  # Recorded on any device: a page copied from another, whose calls are
  # still recorded there, was not let go of.
  recorded <- unlist(lapply(names(.maidr_base_r_session$devices), function(key) {
    vapply(get_device_calls(as.integer(key)), function(call) call$id %||% NA_integer_, 1L)
  }))
  gone <- marks$ids[!marks$ids %in% recorded]
  let_go <- .maidr_base_r_pages$let_go[[as.character(device_id)]]
  if (length(gone) == 0L || is.null(let_go)) {
    return(NULL)
  }
  read <- let_go$read
  if (length(read) == 2L && any(gone >= read[[1]] & gone <= read[[2]])) {
    "read"
  } else if (any(gone <= let_go$upto)) {
    "put back"
  }
}

#' Stop unless the page a device shows holds a Base R plot maidr recorded
#'
#' For `show()`, `save_html()` and `maidr_widget()` asked for the Base R
#' chart. Nothing recorded at all says so as before
#' (`no_base_r_plots_message()`). A page holding no plot maidr recorded
#' (`base_r_page_without_plot()`) says that instead, and why: the plot on
#' it was read by an earlier `show()` or `save_html()`, which let go of its
#' calls, or `replayPlot()` put it back from before that, when they were let
#' go of with the rest (`base_r_page_let_go()`); or what started the page, or put it
#' back, was not recorded, and the plots maidr recorded before it are on
#' pages R no longer shows. maidr can neither read nor draw the page R does
#' show.
#'
#' @param device_id Graphics device ID
#' @return NULL (invisible), or stops
#' @keywords internal
#' @noRd
check_base_r_page_recorded <- function(device_id = grDevices::dev.cur()) {
  if (!is_patching_active() || !has_device_calls(device_id)) {
    stop(no_base_r_plots_message(), call. = FALSE)
  }
  if (base_r_page_without_plot(device_id)) {
    let_go <- base_r_page_let_go(device_id)
    why <- if (identical(let_go, "read")) {
      paste0(
        "An earlier show() or save_html() read the plot on that page, and ",
        "maidr let go of what it had recorded of it then: what has been ",
        "drawn on the page since is all maidr holds of it, and starts no ",
        "plot. Draw the plot again, with what was added to it, to read it."
      )
    } else if (identical(let_go, "put back")) {
      paste0(
        "replayPlot() put back a page drawn before an earlier show() or ",
        "save_html() read the device, and maidr let go of what it had ",
        "recorded of that page then, with the rest of the device's: what has ",
        "been drawn on the page since is all maidr holds of it, and starts ",
        "no plot. Draw the plot again, with what was added to it, to read it."
      )
    } else {
      paste0(
        "R started that page with plot.new() or frame(), with a plot maidr ",
        "does not record, or with a plot drawn while maidr_off() was in ",
        "effect, or replayPlot() put back a page drawn so, or saved in ",
        "another session or on another device; any plot maidr recorded is on ",
        "a page R no longer shows. Draw the chart with maidr on, from a plot ",
        "such as plot() or hist(), to read it."
      )
    }
    stop(
      paste0(
        "The page R's device shows holds no Base R plot maidr recorded, ",
        "so maidr cannot read it. ", why
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}
