# The page R draws each recorded Base R call on.
#
# R's device shows one page: the last. A high-level plot starts a new page
# when it moves past the last panel of the page it is on -- every plot on a
# page of one panel, the fifth under `par(mfrow = c(2, 2))`, the first after
# `par(mfrow = )`, `par(mfcol = )` or `layout()` sets a page up again --
# while one drawn after `par(new = TRUE)`, or with `add = TRUE`, stays on
# the page. `plot.new()` and `frame()` move on a panel as a plot does.
#
# R says which a plot does just before it does it: `par("page")` is TRUE
# when the next `plot.new()` starts a page. R calls the `before.plot.new`
# hook at that moment for every plot, whatever starts it -- a recorded call,
# a `plot.new()` or `frame()` the author called directly, a function that
# draws several plots or sets up a layout of its own, as `heatmap()` does.
# So the hook counts the pages R starts on each device, every recorded call
# is stamped with the page it was drawn on (`log_plot_call_to_device()`),
# and a chart is read from the calls on the last page (`last_page_calls()`).
# Simulating R's rule from the recorded calls instead would have to know
# what each function does to the page, and would miss the calls that are
# not recorded at all.

.maidr_base_r_pages <- new.env(parent = emptyenv())
# The pages R has started on each device while maidr recorded, by device
# number. Only the order matters: a device's count runs on when its calls
# are cleared, or when a device of the same number replaces it.
.maidr_base_r_pages$count <- list()

#' The page R is drawing on, on a device
#'
#' @param device_id Graphics device ID
#' @return The number of pages R has started on the device while maidr
#'   recorded, 0 for none
#' @keywords internal
#' @noRd
base_r_device_page <- function(device_id = grDevices::dev.cur()) {
  .maidr_base_r_pages$count[[as.character(device_id)]] %||% 0L
}

#' Count a page R starts: the `before.plot.new` hook
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
      if (device != 1L && is_patching_enabled() && isTRUE(graphics::par("page"))) {
        key <- as.character(device)
        .maidr_base_r_pages$count[[key]] <- base_r_device_page(device) + 1L
      }
    },
    error = function(e) NULL
  )
  invisible(NULL)
}

#' Count the pages R starts, from now on
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

#' Stop counting the pages R starts
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
#' The calls drawn on the last page any of them was drawn on, and every
#' layout call: `par()` and `layout()` draw nothing, and what they set holds
#' on every page after them. A call recorded without a page, by code that
#' records calls itself, is kept.
#'
#' @param calls Recorded call entries, in the order they were recorded
#' @return The entries R's device shows, in the same order
#' @keywords internal
#' @noRd
last_page_calls <- function(calls) {
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
  calls[is.na(pages) | pages == max(pages, na.rm = TRUE)]
}
