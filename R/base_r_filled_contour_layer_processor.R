#' Base R Filled Contour Layer Processor
#'
#' Reads a base R `filled.contour()` call as the contour it draws.
#'
#' `filled.contour` draws the same level curves `contour()` does and fills the
#' bands between them, so it is read the same way: one curve per level, from
#' `grDevices::contourLines()`, which is the computation the drawing itself
#' runs. One chart with two spellings gets one reading.
#'
#' Two things differ from `contour()`, and only two:
#'
#' **The level default.** `contour.default` takes `nlevels = 10` and
#' `filled.contour` takes `nlevels = 20`, and the number decides the whole
#' announced set through `pretty(zlim, nlevels)`. Everything else about
#' resolving the call -- the `(x, y, z, ...)` slots, the
#' `if (missing(z)) z <- x` fallback, the `list(x =, y =, z =)` unpacking,
#' the `zlim` default -- is identical in both, so this class overrides the
#' number and inherits the rest.
#'
#' **The chart cannot be highlighted, and the inherited code already knows
#' it.** `contour()` writes one `lines` grob per curve, which is what
#' `generate_selectors()` pairs against. `filled.contour` writes one
#' `polygon` grob for the entire field, and gridSVG exports it as a flat run
#' of pieces. Measured on a 6x5 grid drawn at the 17 default levels:
#'
#'     grobs written    graphics-plot-2-filled-contour-1   (one)
#'     SVG polygons     graphics-plot-2-filled-contour-1.1.1 .. .1.160
#'     curves announced 40
#'
#' 160 pieces against 40 curves, and against 17 levels: the polygons are the
#' grid's cells cut by the level crossings, not the bands and not the curves.
#' Nothing pairs, so nothing is emitted -- the inherited
#' `generate_selectors()` finds no `-contour-N-N` grob, its count check fails,
#' and it withholds the list, which is the same answer it gives a `contour()`
#' whose grobs and curves disagree. A layer with no selectors is announced,
#' sonified and navigated; it is the visual highlight alone that is missing,
#' and that is the established degradation here (#89) rather than a reason to
#' ship a picture.
#'
#' Note also that the field is drawn in the **second** plot region: the call
#' lays out a colour key as `graphics-plot-1` and the field as
#' `graphics-plot-2`. Nothing here depends on that, because nothing here
#' addresses a grob, but a later attempt to highlight this chart will.
#'
#' py-maidr declines the equivalent call. Its reason -- recorded in
#' `maidr/patch/contour.py` -- is that `contourf` hands back the filled paths
#' and "an outline of one runs along two different level curves", which is a
#' statement about deriving curves from what was drawn. It does not apply
#' here: R hands over `contourLines()`, so the curves announced are the level
#' curves themselves rather than an inference from the fill, and every one of
#' them is on the page as the boundary between two bands.
#'
#' @keywords internal
BaseRFilledContourLayerProcessor <- R6::R6Class(
  "BaseRFilledContourLayerProcessor",
  inherit = BaseRContourLayerProcessor,
  public = list(
    #' @description How many levels `filled.contour()` defaults to
    #'
    #'   Twice `contour()`'s, and the only number that separates the two.
    #' @return 20
    default_nlevels = function() {
      20
    }
  )
)
