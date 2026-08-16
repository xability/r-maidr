# Undo a layer's jitter before its positions are read
#
# `position_jitter()` displaces every point by a random amount so overlapping
# observations stay separable. The displacement is a drawing decision, not an
# observation -- but it is what lands in the built data frame, and that is
# what a layer processor reads.
#
# Measured on `ggplot(df, aes(g, v)) + geom_jitter()` against the same data
# drawn with `geom_point()`:
#
# ```
# geom_jitter        x= 1.310872   y= -0.6257439
# geom_point         x= 1.000000   y= -0.6264538   <- the actual datum
# ```
#
# Both coordinates are wrong, and the `y` is the serious one. `geom_jitter()`
# displaces **both** axes by default -- `height` is 40% of the data's
# resolution -- so the number announced as the measurement is not the
# measurement. On continuous data the resolution is tiny and the error is
# negligible; on the overplotted integer data the geom actually exists for it
# is not. Measured on 60 responses on a 1-5 scale:
#
# | | max|dy| | first point drawn | first point true |
# |---|---|---|---|
# | `geom_jitter()` | 0.3960 | 1.1477 | 1 |
# | `geom_jitter(height = 0.5)` | 0.4969 | 1.3736 | 1 |
#
# A respondent who answered 1 was announced as having answered 1.1477, which
# on a five-point scale is not a possible answer at all (#174).
#
# A random displacement cannot be inverted, so the positions are recovered by
# asking ggplot2 to lay the layer out again without one. That is exact rather
# than approximate, and it costs no assumption about column names or row
# order: a position adjustment neither adds nor removes rows, so the rebuilt
# frame lines up with the original one for one. Verified against the source
# column directly, and on a faceted plot, in `test-ggplot2-jitter.R`.
#

#' Position classes that displace a point from where its data puts it
#'
#' `PositionJitterdodge` does **not** inherit from `PositionJitter` -- both
#' descend straight from `Position` -- so it has to be named rather than
#' caught by inheritance. Its dodge is removed along with its jitter, which is
#' correct for the same reason: the offset that separates hue groups is drawn
#' geometry, and the group itself is carried as an aesthetic, so nothing is
#' lost by putting the point back on its category.
#'
#' @keywords internal
JITTER_POSITION_CLASSES <- c("PositionJitter", "PositionJitterdodge")

#' One rebuilt frame per layer, so a facet does not pay for it per panel
#'
#' `process_facet_panel()` runs once per panel, so a jittered layer asked for
#' its undisplaced positions once per panel too -- and each of those rebuilds
#' the *whole* plot, every panel of it. Measured by counting
#' `ggplot2::ggplot_build` calls through a facet of P panels: 3, 5 and 9 calls
#' for P of 2, 4 and 8. One build is the original; the other P are the same
#' answer computed P times over, so the work is quadratic in the panel count
#' while the answer never varies -- `undisplaced_layer_data()` depends only on
#' the plot and the layer index.
#'
#' Keyed on the layer itself rather than on the plot. ggplot2 `Layer` objects
#' are ggproto, ggproto objects are environments, and `identical()` on two
#' environments is a pointer comparison -- so the lookup is O(1) and exact,
#' where hashing or deep-comparing the plot could cost as much as the rebuild
#' it saves. A layer belongs to one plot, so its identity settles the question.
#'
#' One entry per layer index, each holding the layer it was computed from, and
#' the whole cache emptied when a plot starts being processed.
#'
#' All three parts are load-bearing. The index bounds the cache at the number
#' of layers a plot has and stops two jittered layers evicting each other once
#' per panel, which is the cost this exists to remove. The layer catches the
#' ordinary case of a second plot built from its own `geom_jitter()`. And the
#' reset catches the case the layer cannot: ggplot2 documents a layer as
#' reusable across plots, and `+.gg` appends the same ggproto object rather
#' than a clone, so
#'
#' ```
#' shared <- geom_jitter()
#' p1 <- ggplot(df1, aes(g, score)) + shared
#' p2 <- ggplot(df2, aes(g, score)) + shared
#' ```
#'
#' gives two plots that are `identical()` at that layer. Measured before the
#' reset went in: `p2` was announced with every one of `df1`'s values, and the
#' row-count check waved it through because the two frames were the same
#' length.
#'
#' @keywords internal
.jitter_cache <- new.env(parent = emptyenv())

#' Forget every rebuilt frame
#'
#' Called when a plot starts being processed, so an entry can only ever be
#' answered to the run that computed it. See `Ggplot2PlotOrchestrator$initialize`
#' for why a layer alone cannot identify a plot.
#'
#' @return Invisibly `NULL`.
#' @keywords internal
reset_jitter_cache <- function() {
  rm(list = ls(envir = .jitter_cache, all.names = TRUE), envir = .jitter_cache)
  invisible(NULL)
}

#' Look up a layer's rebuilt frame
#'
#' @param layer The ggplot2 `Layer` the frame was computed from.
#' @param layer_index Index of that layer within its plot.
#' @return The cached data frame, or `NULL` on a miss.
#' @keywords internal
jitter_cache_get <- function(layer, layer_index) {
  entry <- .jitter_cache[[as.character(layer_index)]]
  if (is.null(entry) || !identical(entry$layer, layer)) {
    return(NULL)
  }
  entry$data
}

#' Remember a layer's rebuilt frame
#'
#' @param layer The ggplot2 `Layer` the frame was computed from.
#' @param layer_index Index of that layer within its plot.
#' @param data The rebuilt data frame, or `NULL` when the rebuild failed.
#' @return Invisibly `NULL`.
#' @keywords internal
jitter_cache_set <- function(layer, layer_index, data) {
  if (is.null(data)) {
    return(invisible(NULL))
  }
  assign(
    as.character(layer_index),
    list(layer = layer, data = data),
    envir = .jitter_cache
  )
  invisible(NULL)
}

#' Whether a layer's points were displaced from their data positions
#'
#' @param layer A ggplot2 `Layer`.
#' @return `TRUE` when the layer carries a jittering position adjustment.
#' @keywords internal
layer_is_jittered <- function(layer) {
  if (is.null(layer) || is.null(layer$position)) {
    return(FALSE)
  }

  any(class(layer$position) %in% JITTER_POSITION_CLASSES)
}

#' The positions a layer's points would have without its jitter
#'
#' Rebuilds `plot` with the one layer's position adjustment replaced by
#' `position_identity()` and returns that layer's built data.
#'
#' The replacement is a fresh `ggproto` child rather than an assignment to the
#' layer's own `position` field. ggplot2 `Layer` objects are `ggproto` and have
#' **reference** semantics, so `plot$layers[[i]]$position <- ...` would alter
#' the caller's plot -- the object they still hold and may draw again. A child
#' shadows the field instead, leaving the parent untouched; asserted in the
#' tests rather than left as a claim.
#'
#' @param plot The ggplot2 object.
#' @param layer_index Index of the layer to undisplace.
#' @return A data frame of the layer's undisplaced built data, or `NULL` when
#'   the rebuild fails or does not line up row for row with the original.
#' @keywords internal
undisplaced_layer_data <- function(plot, layer_index) {
  if (is.null(plot) || is.null(plot$layers) ||
    layer_index < 1L || layer_index > length(plot$layers)) {
    return(NULL)
  }

  layer <- plot$layers[[layer_index]]
  cached <- jitter_cache_get(layer, layer_index)
  if (!is.null(cached)) {
    return(cached)
  }

  rebuilt <- tryCatch(
    {
      without_jitter <- plot
      without_jitter$layers[[layer_index]] <- ggplot2::ggproto(
        NULL,
        plot$layers[[layer_index]],
        position = ggplot2::position_identity()
      )
      ggplot2::ggplot_build(without_jitter)$data[[layer_index]]
    },
    error = function(e) NULL
  )

  jitter_cache_set(layer, layer_index, rebuilt)
  rebuilt
}

#' Put a layer's built points back where its data puts them
#'
#' @param plot The ggplot2 object.
#' @param layer_data The layer's built data, as read from `built$data`.
#' @param layer_index Index of the layer within the plot.
#' @return `layer_data` with `x` and `y` restored when the layer was jittered
#'   and the rebuild lined up, and unchanged otherwise.
#' @keywords internal
undisplace_layer <- function(plot, layer_data, layer_index) {
  if (is.null(layer_data) || is.null(plot) || is.null(plot$layers)) {
    return(layer_data)
  }
  if (layer_index < 1L || layer_index > length(plot$layers)) {
    return(layer_data)
  }
  if (!layer_is_jittered(plot$layers[[layer_index]])) {
    return(layer_data)
  }

  rebuilt <- undisplaced_layer_data(plot, layer_index)

  # Row-for-row correspondence is the whole basis for substituting columns, so
  # it is checked rather than assumed. A mismatch means something other than
  # the position adjustment changed under the rebuild, and the jittered frame
  # -- wrong but coherent -- beats a frame stitched from two different ones.
  if (is.null(rebuilt) || nrow(rebuilt) != nrow(layer_data)) {
    return(layer_data)
  }

  for (aesthetic in c("x", "y")) {
    if (aesthetic %in% names(rebuilt) && aesthetic %in% names(layer_data)) {
      layer_data[[aesthetic]] <- rebuilt[[aesthetic]]
    }
  }

  layer_data
}
