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
# Where R was when each recorded call was done, by the token of the marker
# it left on its page (`mark_base_r_page()`), and whether a marker is being
# made now, which evaluates it once.
.maidr_base_r_pages$marks <- new.env(hash = TRUE, parent = emptyenv())
.maidr_base_r_pages$mark_count <- 0L
.maidr_base_r_pages$marking <- FALSE

#' Where R is drawing, on a device
#'
#' @param device_id Graphics device ID
#' @return A list: `page`, the page R is on, by the number of pages it
#'   had started on the device since maidr was loaded when it started it
#'   -- one `replayPlot()` put back is on its own -- and `last`, the most
#'   it has started; `figure`, the panel of the page it is in, and `plot`,
#'   the plots started on that page. Each 0 for none.
#' @keywords internal
#' @noRd
base_r_device_position <- function(device_id = grDevices::dev.cur()) {
  .maidr_base_r_pages$at[[as.character(device_id)]] %||%
    list(page = 0L, figure = 0L, plot = 0L)
}

#' Follow a plot R starts: the `before.plot.new` hook
#'
#' Called by `plot.new()` for every plot, before it is started; see the top
#' of this file. A plot started with no device open opens a device, whose
#' first page is counted with its next.
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
note_base_r_plot_new <- function() {
  tryCatch(
    {
      device <- grDevices::dev.cur()
      if (device != 1L) {
        key <- as.character(device)
        at <- base_r_device_position(device)
        if (isTRUE(graphics::par("page"))) {
          # Numbered past every page the device has started: one
          # `replayPlot()` put back is shown again under its own number.
          page <- max(at$page, at$last %||% 0L) + 1L
          at <- list(page = page, figure = 1L, plot = 1L, opened = TRUE, last = page)
        } else {
          if (!isTRUE(graphics::par("new"))) {
            at$figure <- at$figure + 1L
          }
          at$plot <- at$plot + 1L
          at$opened <- FALSE
          at$replayed <- NULL
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

#' Leave a marker of a recorded call on the page it was drawn on
#'
#' R does not call the `before.plot.new` hook when `replayPlot()` puts a
#' page back on a device, from a plot `recordPlot()` saved, and the page R
#' shows is then one before the last it started. Each recorded call leaves a
#' marker on its page, an entry on the device's display list made with
#' `grDevices::recordGraphics()`, that draws nothing and, each time the page
#' is replayed, says where R was when the call was done
#' (`note_base_r_page_replayed()`). A device that keeps no display list
#' keeps no marker, and replays no page. Not in a knit, where knitr replays
#' each figure and the chart's own markers say which it is (see
#' knitr_figure_map.R).
#'
#' @param device_id The device the call was drawn on
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
mark_base_r_page <- function(device_id = grDevices::dev.cur()) {
  elsewhere <- !identical(as.integer(device_id), as.integer(grDevices::dev.cur()))
  if (elsewhere || isTRUE(getOption("knitr.in.progress"))) {
    return(invisible(NULL))
  }
  state <- .maidr_base_r_pages
  if (is.null(state$session)) {
    state$session <- paste0(Sys.getpid(), "-", format(unclass(Sys.time()), digits = 16))
  }
  state$mark_count <- state$mark_count + 1L
  token <- paste0(state$session, "-", state$mark_count)
  assign(
    token,
    list(device = as.character(device_id), at = base_r_device_position(device_id)),
    envir = state$marks
  )
  state$marking <- TRUE
  on.exit(state$marking <- FALSE, add = TRUE)
  # Only base R is needed to evaluate it: a saved plot can be replayed in a
  # session with another maidr, or none, whose marks it is not among.
  tryCatch(
    grDevices::recordGraphics(
      {
        if ("maidr" %in% loadedNamespaces()) {
          replayed <- get0(
            "note_base_r_page_replayed",
            envir = asNamespace("maidr"),
            inherits = FALSE
          )
          if (is.function(replayed)) replayed(token)
        }
      },
      list(token = token),
      baseenv()
    ),
    error = function(e) NULL
  )
  invisible(NULL)
}

#' Note that a page with a recorded call's marker was replayed
#'
#' The device is put back where R was when the call was done, so the chart
#' is read from that page (`last_page_calls()`), and a call drawn on it next
#' is recorded on it. A page replayed where it already is, as a window
#' redrawn at a new size is, is left as it is.
#'
#' @param token The marker's token (`mark_base_r_page()`)
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
note_base_r_page_replayed <- function(token) {
  state <- .maidr_base_r_pages
  if (isTRUE(state$marking)) {
    return(invisible(NULL))
  }
  mark <- get0(token, envir = state$marks, inherits = FALSE)
  key <- as.character(grDevices::dev.cur())
  if (is.null(mark) || !identical(mark$device, key)) {
    return(invisible(NULL))
  }
  now <- base_r_device_position(grDevices::dev.cur())
  if (identical(mark$at$page, now$page) && !isTRUE(now$replayed)) {
    return(invisible(NULL))
  }
  at <- mark$at
  at$last <- max(now$last %||% 0L, now$page, at$last %||% 0L)
  at$replayed <- TRUE
  state$at[[key]] <- at
  invisible(NULL)
}

#' Note where R put the plot it started: the `plot.new` hook
#'
#' Called by `plot.new()` once the plot is started; see the top of this
#' file. The cell (`par("mfg")`: its row and column, and the grid's rows
#' and columns) and the region of the page (`par("fig")`) are kept with the
#' plot's place, and with that of each recorded call this plot is the
#' first of on its page.
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
      if (device != 1L && !is.null(at)) {
        before <- at[c("page", "plot")]
        at$cell <- as.integer(graphics::par("mfg"))
        at$fig <- graphics::par("fig")
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
#' @param page The page R's device is on (`base_r_device_position()`), one
#'   `replayPlot()` put back among them; `NULL` for the last page any call
#'   was drawn on
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
  shown <- if (is.null(page)) max(pages, na.rm = TRUE) else page
  calls[is.na(pages) | pages == shown]
}

#' The recorded calls a device shows
#'
#' Those on the page it is on (`last_page_calls()`), each drawing once
#' (`standalone_calls()`).
#'
#' @param device_id Graphics device ID
#' @return The entries, in the order they were recorded
#' @keywords internal
#' @noRd
shown_device_calls <- function(device_id = grDevices::dev.cur()) {
  standalone_calls(
    last_page_calls(get_device_calls(device_id), base_r_device_position(device_id)$page)
  )
}

#' Whether the page a device shows holds no plot maidr recorded
#'
#' Something was drawn on the device, but no plot maidr recorded is on the
#' page R shows: R started that page with `plot.new()` or `frame()`, with a
#' plot maidr does not record, or with one drawn while `maidr_off()` was in
#' effect, and anything recorded on it since is a low-level call that
#' started no plot, such as `lines()` or `text()`. A device holding only
#' layout calls has drawn nothing, and is not such a device.
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
#'   started a plot, and `end_figure` and `end_plot`, the panel and plot R
#'   was on when the call was done, and `window`, the coordinates of that
#'   plot then (`base_r_plot_window()`); `opens_page`, whether R started a
#'   page with the plot the call started first on it, which under a grid
#'   is in the grid's first panel (`plot_in_grid()`), and `laid_out`,
#'   whether that plot is in a grid of another shape than the one the call
#'   started in, which it laid out itself; `id`, the number the
#'   call is known by,
#'   `outer`, the number of the recorded call that made it while drawing,
#'   if one did, `apart`, whether it was made from that call's arguments
#'   before that call drew a plot of its own, and `own_plot`, whether it
#'   started a plot itself (see `standalone_calls()`); and `start_page`
#'   and `start_figure`, the page and panel of the first plot the call
#'   started, which a call that draws several plots, as `plot()` of a
#'   fitted model does, started on a page before its last. Only `page`
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
  list(
    page = at$page,
    figure = first$figure,
    plot = first$plot,
    cell = first$cell,
    fig = first$fig,
    new_plot = started,
    start_page = call$start$page,
    start_figure = call$start$figure,
    opens_page = started && isTRUE(first$opened),
    laid_out = started && length(call$grid) == 2L && length(first$cell) == 4L &&
      !identical(call$grid, as.integer(first$cell[3:4])),
    end_figure = at$figure,
    end_plot = at$plot,
    window = base_r_plot_window(),
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

#' Stop unless the page a device shows holds a Base R plot maidr recorded
#'
#' For `show()`, `save_html()` and `maidr_widget()` asked for the Base R
#' chart. Nothing recorded at all says so as before
#' (`no_base_r_plots_message()`). A page holding no plot maidr recorded
#' (`base_r_page_without_plot()`) says that instead. The plots maidr
#' recorded before it are on pages R no longer shows, and maidr can neither
#' read nor draw the page R does show: what started it was not recorded.
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
    stop(
      paste0(
        "The page R's device shows holds no Base R plot maidr recorded, ",
        "so maidr cannot read it. R started that page with plot.new() or ",
        "frame(), with a plot maidr does not record, or with a plot drawn ",
        "while maidr_off() was in effect, and any plot maidr recorded is on ",
        "an earlier page, which R no longer shows. Draw the chart with ",
        "maidr on, from a plot such as plot() or hist(), to read it."
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}
