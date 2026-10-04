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
          at <- list(page = at$page + 1L, figure = 1L, plot = 1L)
        } else {
          if (!isTRUE(graphics::par("new"))) {
            at$figure <- at$figure + 1L
          }
          at$plot <- at$plot + 1L
        }
        .maidr_base_r_pages$at[[key]] <- at
        drawing <- .maidr_base_r_pages$calls[[key]]
        for (i in seq_along(drawing)) {
          if (!identical(drawing[[i]]$first$page, at$page)) {
            drawing[[i]]$first <- at
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

#' Follow the plots R starts, from now on
#'
#' Set when maidr is loaded, and again, where something took it out, before
#' each recorded call draws (`ensure_maidr_device()`); `.onUnload()` removes
#' it (`remove_base_r_page_hook()`).
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
set_base_r_page_hook <- function() {
  if (!any(vapply(getHook("before.plot.new"), identical, logical(1), note_base_r_plot_new))) {
    setHook("before.plot.new", note_base_r_plot_new)
  }
  invisible(NULL)
}

#' Stop following the plots R starts
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
remove_base_r_page_hook <- function() {
  hooks <- getHook("before.plot.new")
  keep <- !vapply(hooks, identical, logical(1), note_base_r_plot_new)
  if (!all(keep)) {
    setHook("before.plot.new", hooks[keep], action = "replace")
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
    function(call) identical(call$class_level, "HIGH") || isTRUE(call$new_plot),
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
  .maidr_base_r_pages$calls[[key]] <- c(drawing, list(list(depth = depth, id = id)))
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
#' @return A list: `page`, `figure`, `plot`, `new_plot`, whether the call
#'   started a plot, and `end_figure` and `end_plot`, the panel and plot R
#'   was on when the call was done; `id`, the number the call is known by,
#'   `outer`, the number of the recorded call that made it while drawing,
#'   if one did, and `own_plot`, whether it started a plot itself (see
#'   `standalone_calls()`). Only `page` for a call no recording wrapper
#'   drew, recorded by code that records calls itself.
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
    new_plot = started,
    end_figure = at$figure,
    end_plot = at$plot,
    id = call$id,
    outer = if (this > 1L) drawing[[this - 1L]]$id,
    own_plot = isTRUE(call$own_plot)
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
#' @param calls Recorded call entries, in the order they were recorded
#' @return The entries that stand, in the same order
#' @keywords internal
#' @noRd
standalone_calls <- function(calls) {
  ids <- vapply(calls, function(call) call$id %||% NA_integer_, integer(1))
  outers <- vapply(calls, function(call) call$outer %||% NA_integer_, integer(1))
  made <- !is.na(ids) & ids %in% outers
  stands <- function(i) {
    if (identical(calls[[i]]$class_level, "LAYOUT")) {
      return(TRUE)
    }
    if (made[[i]] && !isTRUE(calls[[i]]$own_plot)) {
      return(FALSE)
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
