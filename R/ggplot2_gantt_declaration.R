# One decided case, one function. A generic `maidr_declare(geom_rect(...),
# type = "gantt")` was considered and deferred: it would have to wrap a layer
# built by someone else, and a wrapper around `ggplot2::geom_rect()` records
# `::/ggplot2/geom_rect` in `layer$constructor` -- measured, at one and two
# wrappers deep -- so the generic form loses the constructor carrier and
# rides on the field alone. There is also only
# one ambiguous geom so far. When a second one needs declaring, that is the
# point to generalise, and `maidr_gantt()` can be written in terms of
# whatever replaces it.
#
# This is the package's first *per-layer* author declaration. Every other
# `maidr_*` export in NAMESPACE acts on the session or on the installation --
# `maidr_on`, `maidr_off`, `maidr_get_fallback`, `maidr_set_fallback`,
# `maidr_output`, and `maidr_download_dotpad_sdk`, which is not an option at
# all but fetches and checksums the SDK onto disk -- never on one layer. Once
# exported it cannot be withdrawn without deprecation.

#' Declare that a rectangle layer draws a schedule
#'
#' @description
#' `maidr_gantt()` is `ggplot2::geom_rect()` with one thing added: the author
#' saying that these rectangles are intervals in lanes. A declared layer is
#' read as a `gantt` -- lanes named, intervals announced, every bar
#' highlightable -- where the same rectangles drawn with `geom_rect()` are
#' left unread and cost the whole chart its interactivity.
#'
#' Nothing about the picture changes. The declaration is carried on the layer
#' object, not in the aesthetics, so the same `xmin`/`xmax`/`ymin`/`ymax` the
#' author would have written to `geom_rect()` produce the same chart: measured
#' on ggplot2 3.4.4, the built data is `identical()` to the bare
#' `geom_rect()` layer's and the panel's `x.range` and `y.range` are identical
#' too. Swapping `geom_rect(` for `maidr_gantt(` moves nothing on the page.
#'
#' @details
#' # Why the author is asked
#'
#' A rectangle layer carries no evidence of what it means. Five structural
#' rules were measured against eight charts on ggplot2 3.4.4, and the best of
#' them -- bands partition on the lane axis, more than one band, more than one
#' distinct span, minus a complete-lattice veto -- scored 6 of 8 and still
#' claimed a heatmap with one cell missing and a two-region highlight. The
#' table is recorded above the reading itself, in
#' `R/ggplot2_adapter.R`. A monotone waterfall and a one-task-per-lane
#' schedule are the same rectangles, so there is nothing in the geometry to
#' separate; asking the author is the only unfalsified rule.
#'
#' The consequence is that this is trusted. `maidr_gantt()` over heatmap
#' coordinates announces a heatmap as a schedule, and the package believes it,
#' because any guard strong enough to catch that is the rule the measurements
#' above ruled out.
#'
#' # What it costs not to declare
#'
#' An undeclared `geom_rect()` layer reads as `"unknown"`, which drops the
#' whole plot to a static image with the "Plot contains unsupported elements"
#' warning. That is unchanged by this function, deliberately: every chart
#' already written keeps exactly the reading it has today.
#'
#' # Lane names
#'
#' With numeric `ymin`/`ymax` the lane axis is continuous and has no level
#' names to borrow, so a lane is named by the single explicit tick drawn
#' inside it -- `scale_y_continuous(breaks = 1:3, labels = c("design",
#' "build", "test"))` -- and by its position on the axis otherwise. A tick
#' whose label is a rendering of its own number is a coordinate rather than a
#' name: measured on the default scale the panel's labels are `NA, 1, 2, 3,
#' NA`, each one its own break written out, and a lane called `"2"` says less
#' than a lane called by the position 2 it sits at.
#'
#' @param mapping Aesthetics, as for [ggplot2::geom_rect()]: `xmin`, `xmax`,
#'   `ymin` and `ymax` are required, and every other rectangle aesthetic
#'   (`fill`, `colour`, `alpha`, ...) behaves exactly as it does there.
#' @param data The layer's data, as for [ggplot2::geom_rect()].
#' @param position Position adjustment, as for [ggplot2::geom_rect()].
#' @param ... Other arguments passed to the layer, as for
#'   [ggplot2::geom_rect()] -- except `stat`, which that function takes as a
#'   formal and this one does not accept. A declared schedule is always drawn
#'   from the author's own bounds, so the stat is fixed at `"identity"`;
#'   measured, a `stat` written here lands in `params`, is recognised by
#'   neither the geom nor the stat, and is dropped with the warning
#'   `Ignoring unknown parameters`. Aesthetics and geom parameters pass through
#'   exactly as they do to [ggplot2::geom_rect()] -- measured, a misspelled
#'   aesthetic and a misspelled parameter each raise the identical warning
#'   from both.
#' @param lane_axis Which axis the lanes run up: `"y"` (the default) for the
#'   ordinary horizontal schedule -- lanes stacked up y, spans running along x
#'   -- or `"x"` for the mirror image. It selects which pair of bounds becomes
#'   the span and which becomes the lane; it is not a guess the package makes.
#' @param na.rm If `FALSE` (the default), rows with missing values are removed
#'   with a warning.
#' @param show.legend Whether this layer is included in the legends.
#' @param inherit.aes If `FALSE`, the plot's default aesthetics are not
#'   inherited.
#'
#' @return A ggplot2 layer, to be added to a plot with `+`.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   tasks <- data.frame(
#'     lane = c(1, 2, 3, 2),
#'     start = c(0, 3, 8, 12),
#'     end = c(3, 8, 11, 15)
#'   )
#'
#'   schedule <- ggplot2::ggplot(tasks) +
#'     maidr_gantt(ggplot2::aes(
#'       xmin = start, xmax = end,
#'       ymin = lane - 0.4, ymax = lane + 0.4
#'     )) +
#'     ggplot2::scale_y_continuous(
#'       breaks = 1:3,
#'       labels = c("design", "build", "test")
#'     ) +
#'     ggplot2::labs(x = "week", y = "task")
#'
#'   # The same rectangles written with `geom_rect()` draw the same chart and
#'   # are left unread, which costs the plot its interactivity.
#'   if (interactive()) {
#'     show(schedule)
#'   }
#' }
#'
#' @seealso [save_html()] and [show()] for rendering the declared chart
#' @export
maidr_gantt <- function(mapping = NULL,
                        data = NULL,
                        position = "identity",
                        ...,
                        lane_axis = c("y", "x"),
                        na.rm = FALSE,
                        show.legend = NA,
                        inherit.aes = TRUE) {
  lane_axis <- match.arg(lane_axis)

  # `ggplot2::layer()` directly, never a wrapper around `geom_rect()`, and
  # the difference is the whole mechanism. `layer()` records
  # `frame_call(call_env)` -- the call in the frame that called it -- as
  # `layer$constructor`, which is the field `layer_is_annotation()` already
  # reads. Measured on ggplot2 3.4.4:
  #
  #     maidr_gantt(m)                        head  maidr_gantt
  #     a user wrapper around maidr_gantt     head  maidr_gantt
  #     two wrappers deep around maidr_gantt  head  maidr_gantt
  #     a wrapper around ggplot2::geom_rect() head  ::/ggplot2/geom_rect
  #
  # so a helper that called `geom_rect()` internally would record ggplot2's
  # name -- the *inner* call, however deep the nesting -- and be invisible to
  # the reading in `R/ggplot2_adapter.R`.
  #
  # `lane_axis` is consumed here rather than passed down: `layer()` partitions
  # `params` between the geom and the stat and drops what neither knows, and
  # with the default `check.param = TRUE` it says `Ignoring unknown
  # parameters` on the way. `check.aes` and `check.param` are left on for the
  # same reason -- a typo in an aesthetic should be reported here exactly as
  # `geom_rect()` reports it.
  layer <- ggplot2::layer(
    stat = "identity",
    geom = ggplot2::GeomRect,
    data = data,
    mapping = mapping,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(na.rm = na.rm, ...)
  )

  # The second carrier, on the layer instance rather than on
  # `ggplot2::GeomRect` -- measured, `GeomRect$maidr_type` stays NULL, so the
  # shared prototype is untouched and no other rect layer is tagged. A
  # `LayerInstance` is an environment, so a layer object reused in two plots
  # carries the declaration in both; the value is the same in both and
  # nothing downstream writes to it.
  #
  # Two carriers because they fail in opposite directions, both measured:
  # `do.call(maidr_gantt, list(m))` leaves the closure itself at
  # `constructor[[1]]`, where `as.character()` raises "cannot coerce type
  # 'closure'", and the field answers instead; a future ggplot2 that
  # re-instantiates layers through `ggproto()` would drop an unknown field,
  # and the constructor answers instead.
  layer$maidr_type <- "gantt"
  layer$maidr_lane_axis <- lane_axis
  layer
}
