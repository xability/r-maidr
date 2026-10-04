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
# Where the plot a recorded call started first on its last page is, while
# the call is drawing (`begin_base_r_call()`), by device number: an empty
# list until it starts one.
.maidr_base_r_pages$calls <- list()

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
        call <- .maidr_base_r_pages$calls[[key]]
        if (!is.null(call) && !identical(call$page, at$page)) {
          .maidr_base_r_pages$calls[[key]] <- at
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
#' Those on the page it is on (`last_page_calls()`).
#'
#' @param device_id Graphics device ID
#' @return The entries, in the order they were recorded
#' @keywords internal
#' @noRd
shown_device_calls <- function(device_id = grDevices::dev.cur()) {
  last_page_calls(get_device_calls(device_id), base_r_device_position(device_id)$page)
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
#'
#' @param device_id The device it draws on
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
begin_base_r_call <- function(device_id = grDevices::dev.cur()) {
  .maidr_base_r_pages$calls[[as.character(device_id)]] <- list()
  invisible(NULL)
}

#' Where a recorded call was drawn, once it has drawn
#'
#' The page it ended on, and the panel and number of the plot it started
#' first on that page; for a call that started no plot -- `lines()`, or a
#' plot drawn with `add = TRUE` -- the panel and plot it drew on.
#'
#' @param device_id The device it drew on
#' @return A list: `page`, `figure`, `plot`, `new_plot`, whether the call
#'   started a plot, and `end_figure` and `end_plot`, the panel and plot R
#'   was on when the call was done. Only `page` for a call no recording
#'   wrapper drew, recorded by code that records calls itself.
#' @keywords internal
#' @noRd
end_base_r_call <- function(device_id = grDevices::dev.cur()) {
  key <- as.character(device_id)
  at <- base_r_device_position(device_id)
  call <- .maidr_base_r_pages$calls[[key]]
  .maidr_base_r_pages$calls[[key]] <- NULL
  if (is.null(call)) {
    return(list(page = at$page))
  }
  started <- !is.null(call$page)
  first <- if (started) call else at
  list(
    page = at$page,
    figure = first$figure,
    plot = first$plot,
    new_plot = started,
    end_figure = at$figure,
    end_plot = at$plot
  )
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
