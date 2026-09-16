#' Base R Fourfold Display Layer Processor
#'
#' Processes Base R `fourfoldplot()` layers drawn with
#' `std = "ind.max"` or `std = "all.max"` -- a 2x2 contingency table drawn as
#' four quarter-circles, one per cell, sized so the wedge's AREA is
#' proportional to that cell's count.
#'
#' Read as a `heat` layer, for the same reason `assocplot()` is: the drawing
#' is a 2x2 grid of one number per cell, and row-then-column is how a reader
#' navigates a contingency table. Measured on
#' `fourfoldplot(as.table(matrix(c(10, 40, 90, 160), 2)), std = "ind.max")`,
#' the radii and the counts they recover:
#'
#' \preformatted{
#' grob                       r        quadrant      r^2 * max(count)  cell
#' graphics-plot-1-polygon-1  0.250000 upper LEFT     10               [1, 1]
#' graphics-plot-1-polygon-2  0.500000 lower LEFT     40               [2, 1]
#' graphics-plot-1-polygon-3  0.750000 upper RIGHT    90               [1, 2]
#' graphics-plot-1-polygon-4  1.000000 lower RIGHT   160               [2, 2]
#' }
#'
#' exactly, so `radius / sqrt(count)` is one constant (`0.0790569415` here, with a
#' relative spread of `1.755e-16`). The table's FIRST dimension runs
#' vertically and its SECOND horizontally -- the transpose of `assocplot()`'s
#' arrangement, and measured from the label grobs, which put
#' `names(dimnames(x))[1]` at the top and bottom of the drawing and
#' `names(dimnames(x))[2]` at the left and right.
#'
#' Nothing is inferred from the drawing. `fourfoldplot()` is handed the table,
#' so the recorded call carries every number the trace wants; the grobs are
#' consulted only to decide whether the drawing on the page is the one the
#' recorded call describes.
#'
#' ## What this deliberately does not do
#'
#' **It is not a `mosaic` and it is not a `bar`.** A mosaic's tiles tile a
#' whole and carry proportions of it; these are four independent quarter-discs
#' separated by `space` (default `0.2`) that tile nothing. A bar trace would
#' imply a value axis with a zero baseline and one categorical axis, while
#' measured the radii are on a square-root scale and the quadrants are laid
#' out in two dimensions.
#'
#' **The confidence arcs are dropped.** Measured, a `conf.level` draws 8
#' unfilled arcs (`polygon-5` .. `polygon-12`), arcs `4 + j` and `8 + j` being
#' the lower and upper bound of cell `c(tab)[j]`. A `heat` layer has nowhere
#' to carry an interval, so a reader is told the counts and not that the chart
#' also draws a band around each. Unlike `qqplot`'s band this does not justify
#' declining: the arcs decorate numbers that ARE fully carried.
#'
#' **The odds ratio is never announced.** There is no MAIDR trace for one
#' scalar. Under `ind.max`/`all.max` a reader gets four counts and can compute
#' it.
#'
#' ## Where the two gates live, and what the second one cannot do
#'
#' #268 asks that a chart whose geometry disagrees LOSE the reading rather
#' than get a wrong one. That is not achievable here and this does not pretend
#' it is. Verified against `BaseRPlotOrchestrator$initialize()`, which runs
#' `detect_layers()`, `resolve_fallback_scope()`, `create_layer_processors()`
#' and `process_layers()` at lines 122-125: the picture-versus-chart decision
#' is frozen by line 123, which reads `private$.layers[[i]]$type` through
#' `unsupported_layer_flags()`. That field is written only by the two
#' `private$.layers[[layer_counter]] <- list(type = ...)` assignments at lines
#' 147 and 169, both from `detect_layer_type()`, and is never rewritten from a
#' processor result; line 124 does not even build a processor for a layer
#' already typed `"unknown"` (line 219). A processor that answered
#' `type = "unknown"` would ship that string with `has_unsupported_layers()`
#' still FALSE -- the #214 failure `BaseRProcessorFactory$get_supported_types()`
#' records, where the figure binds and then fails to construct.
#'
#' So the split is:
#'
#' * the **argument** gate is `fourfold_decline_reason()`, called from
#'   `detect_layer_type()`, and it CAN lose the reading;
#' * the **geometry** gate is `radii_agree()` below, and it can only return
#'   `list()` from `generate_selectors()` -- the numbers are still announced
#'   and nothing highlights. That is the shipped pie idiom: "a short list
#'   means these are not this pie's grobs. Filling the gap with a guessed id
#'   would silently highlight another panel's wedges."
#'
#' ## What the geometry gate can and cannot see
#'
#' Measured, and weaker than it looks:
#'
#' * It is **exactly scale-invariant**. A drawing of `tab * 3`, or of
#'   `tab * 1e6`, checked against `tab`'s counts gives a relative deviation of
#'   `1.755e-16` and passes. `radius / sqrt(count) == 1 / sqrt(max(tab))` is an
#'   identity inside `stdize()`, so no table can falsify it and an upstream
#'   change to what `ind.max` means would go uncaught at runtime. That
#'   exposure is carried by the live-drawing assertions in
#'   `test-base-r-fourfoldplot.R`, the same bet the `qqplot` branch makes.
#' * It **passes for a symmetric table drawn under the default `std`**.
#'   Measured, `9, 4, 4, 9` under `std = "margins"` gives a relative deviation
#'   of `0.000e+00`, and so does `7, 7, 7, 7`; algebraically, with
#'   `n11 = n22 = a` and `n12 = n21 = b`, `u / a == (1 - u) / b == 1 / (a + b)`.
#'   It recovers off symmetry fast -- `9, 4, 4, 9.0001` gives `2.778e-06` and
#'   fails at `1e-8` -- but this is why `std` is the first gate and the
#'   geometry only the second.
#'
#' What it does catch is a grob tree that is not this call's: measured,
#' `fourfoldplot(UCBAdmissions, std = "ind.max")` draws 78 polygons, and an
#' asymmetric table's `margins` drawing checked against its own counts gives
#' `7.616e-01`.
#'
#' @keywords internal
BaseRFourfoldLayerProcessor <- R6::R6Class(
  "BaseRFourfoldLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the fourfold display layer.
    #' @param plot Unused for Base R (kept for interface compatibility)
    #' @param layout Unused for Base R (kept for interface compatibility)
    #' @param built Unused for Base R (kept for interface compatibility)
    #' @param gt Gtable object used for selector generation (optional)
    #' @param grob_id Unused for Base R
    #' @param panel_id Unused for Base R
    #' @param panel_ctx Unused for Base R
    #' @param layer_info Information about the recorded plot call
    #' @return List with data, selectors, type, title and axes
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      data <- self$extract_data(layer_info)
      list(
        data = data,
        selectors = self$generate_selectors(layer_info, gt, data),
        type = "heat",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info),
        domMapping = list(order = "row")
      )
    },

    #' @description Whether the plot data must be reordered before drawing; a Base R layer is read
    #'   from the recorded call and never is
    #' @return FALSE
    needs_reordering = function() {
      FALSE
    },

    #' @description The 2x2 table of counts the call was handed, when it is one.
    #'
    #' Guarded by `fourfold_decline_reason()`, the same predicate
    #' `detect_layer_type()` asks, so dispatch and extraction cannot disagree
    #' about which calls are readable.
    #'
    #' Used for the COUNTS and the shape only. The level names and the axis
    #' names come from `drawn_dimnames()` instead, which is not the same
    #' thing -- see there.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return A 2x2 table, or NULL
    recorded_table = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      args <- layer_info$plot_call$args
      if (!fourfold_reads_counts(args)) {
        return(NULL)
      }
      recorded_two_way_table(args)
    },

    #' @description The dimnames `fourfoldplot()` itself labels the chart with.
    #'
    #' NOT `dimnames(recorded_two_way_table(...))`, and the difference is the
    #' whole point. `recorded_two_way_table()` repairs dimnames through
    #' `as.table()`; `graphics::fourfoldplot` repairs them from `dimnames(x)`
    #' as handed, after reshaping a 2-D `x` to `2 x 2 x 1`. Its own source:
    #'
    #' \preformatted{
    #' if (length(dim(x)) == 2L)
    #'     x <- if (is.null(dimnames(x))) array(x, c(dim(x), 1L))
    #'          else array(x, c(dim(x), 1L), c(dimnames(x), list(NULL)))
    #' dnx <- dimnames(x)
    #' if (is.null(dnx)) dnx <- vector("list", 3L)
    #' for (i in which(sapply(dnx, is.null))) dnx[[i]] <- LETTERS[seq_len(dim(x)[i])]
    #' if (is.null(names(dnx))) i <- 1L:3L else i <- which(is.null(names(dnx)))
    #' if (any(i)) names(dnx)[i] <- c("Row", "Col", "Strata")[i]
    #' }
    #'
    #' reproduced here rather than approximated. For an `ftable` the two
    #' disagree completely: `dimnames(ftable(tb))` is NULL, so the chart is
    #' labelled `Row: A`, `Col: A`, `Row: B`, `Col: B` -- measured off the
    #' text grobs -- while `as.table(ftable(tb))` reconstructs
    #' `Treatment`/`Outcome` and `Drug`/`Placebo`/`Cured`/`Not`. Reading the
    #' levels off `as.table()` would announce six strings that appear nowhere
    #' on the page, which is #268's own failure displaced from the numbers
    #' onto the labels.
    #'
    #' The `which(is.null(names(dnx)))` line is upstream's, quirk included:
    #' `is.null()` returns one logical, so that expression is always
    #' `integer(0)` and the `Row`/`Col` default fires only when
    #' `names(dimnames(x))` is entirely NULL. A PARTIALLY named `dimnames` is
    #' therefore never repaired, and measured, `names(dimnames(t)) <-
    #' c("Answer", "")` makes the chart literally draw `": hi"` and `": lo"`.
    #' `extract_axis_titles()` substitutes `"Col"` there rather than announce
    #' an empty label -- deliberately better than the chart, and the one place
    #' this reading is not identical to it. `test-base-r-fourfoldplot.R` pins
    #' the chart's wrong answer as well as ours.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return A length-3 named list of dimnames, or NULL
    drawn_dimnames = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      handed <- resolve_xy_args(layer_info$plot_call$args)$x
      dims <- dim(handed)
      if (is.null(dims) || length(dims) != 2L) {
        return(NULL)
      }
      dims <- c(dims, 1L)

      dnx <- dimnames(handed)
      if (!is.null(dnx)) {
        dnx <- c(dnx, list(NULL))
      } else {
        dnx <- vector("list", 3L)
      }
      for (i in which(vapply(dnx, is.null, logical(1)))) {
        dnx[[i]] <- LETTERS[seq_len(dims[[i]])]
      }
      i <- if (is.null(names(dnx))) 1L:3L else which(is.null(names(dnx)))
      if (any(i)) {
        names(dnx)[i] <- c("Row", "Col", "Strata")[i]
      }
      dnx
    },

    #' @description Read the 2x2 grid of counts out of the recorded call.
    #'
    #' Rows of the emitted grid are the table's FIRST dimension, top to
    #' bottom, and its columns the SECOND, left to right -- measured from the
    #' drawing, where `polygon-1` (cell `[1, 1]`) is the upper-left quadrant
    #' and the top and bottom labels carry `names(dimnames(x))[1]`. That is
    #' the transpose of what `assocplot()` does with the same argument, and
    #' it is not a convention chosen here.
    #'
    #' The level names come from `drawn_dimnames()`, so they are the strings
    #' the chart puts beside each quadrant.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return List with points, x and y, empty when there is no readable table
    extract_data = function(layer_info) {
      table <- self$recorded_table(layer_info)
      if (is.null(table)) {
        return(list(points = list(), x = list(), y = list()))
      }

      # Column-major, which is the order `fourfoldplot()` draws and labels in:
      # its own `text(..., as.character(c(tab)))` prints `c(tab)`.
      counts <- as.numeric(table)
      points <- lapply(seq_len(2L), function(r) {
        lapply(seq_len(2L), function(cc) counts[[(cc - 1L) * 2L + r]])
      })

      named <- self$drawn_dimnames(layer_info)
      row_levels <- self$levels_of(named, 1L, rownames(table))
      col_levels <- self$levels_of(named, 2L, colnames(table))

      list(
        points = points,
        x = as.list(as.character(col_levels)),
        y = as.list(as.character(row_levels))
      )
    },

    #' @description The level names of one table dimension, as drawn.
    #'
    #' `drawn_dimnames()` is NULL only when the recorded first argument has no
    #' 2-D `dim()` at all, which a readable call cannot have; the fallback is
    #' there so a malformed `layer_info` in a test yields level names rather
    #' than an error.
    #'
    #' @param named The list `drawn_dimnames()` returned, or NULL
    #' @param i Which dimension, 1 or 2
    #' @param fallback Level names to use when there are none drawn
    #' @return A character vector of level names
    levels_of = function(named, i, fallback) {
      if (is.null(named) || length(named) < i || is.null(named[[i]])) {
        return(as.character(fallback))
      }
      as.character(named[[i]])
    },

    #' @description Name the axes the way the chart places the dimensions.
    #'
    #' `x` is the SECOND dimension, because measured the columns run left to
    #' right; `y` is the first, because the rows run top to bottom. `z` names
    #' what the numbers are rather than a dimension of the table -- a reader
    #' told "Outcome" for the value would be given a level name where a number
    #' is.
    #'
    #' `"Count"` is the contingency-table convention and not a claim that the
    #' values are whole numbers: measured, `fourfoldplot()` draws non-integer
    #' cells happily (`1.5, 2.5, 3.5, 4.5` gives radii
    #' `0.5774, 0.7454, 0.8819, 1.0000` and the ratio check passes).
    #'
    #' No `recorded_axis_label()` call, unlike the assocplot processor.
    #' Measured, `names(formals(graphics::fourfoldplot))` is exactly
    #' `x, color, conf.level, std, margin, space, main, mfrow, mfcol` -- no
    #' `xlab`, no `ylab`, no `...` -- and `fourfoldplot(tab, xlab = "X")`
    #' stops with "unused argument". Reading a label that the function rejects
    #' would be dead code asserting an argument that cannot exist.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      named <- names(self$drawn_dimnames(layer_info))
      # `fourfoldplot()`'s own `which(is.null(names(dnx)))` quirk leaves a
      # partially named `dimnames` unrepaired, and the chart then draws
      # ": hi". Its own defaults are used for the empty slot instead.
      dimension <- function(i) {
        if (length(named) >= i && !is.na(named[[i]]) && nzchar(named[[i]])) {
          named[[i]]
        } else {
          c("Row", "Col")[[i]]
        }
      }

      build_axes(x = dimension(2L), y = dimension(1L), z = "Count")
    },

    #' @description The title the call was given, if any.
    #' @param layer_info Information about the recorded plot call
    #' @return Character scalar, empty when the author wrote no title
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }
      recorded_main_title(layer_info$plot_call$args)
    },

    #' @description The four wedge grobs of one fourfold panel, or NULL.
    #'
    #' Discriminated by polygon count and vertex count, NOT by `gp$fill`.
    #' Fill looks like the exact discriminator and is not: measured,
    #' `fourfoldplot(tb, std = "ind.max", color = "steelblue")` leaves two
    #' quadrants with `fill = NA`, because `fourfoldplot()` does not validate
    #' `color`'s length and its draw calls index it as
    #' `color[1 + (d > 1)]` / `color[2 - (d > 1)]`. A fill-keyed search finds
    #' two wedges there and the layer would ship with no selectors at all, for
    #' a chart that is perfectly readable.
    #'
    #' What is measured to be stable:
    #'
    #' * one panel draws **exactly 13** polygons (4 wedges, 8 confidence arcs,
    #'   1 frame) or **exactly 5** when `conf.level` is `0` or `FALSE`. The
    #'   arc count is 8 or 0 and never anything else -- `conf.level` produces
    #'   two `for (j in 1:4)` loops guarded by `is.numeric(conf.level)`, and
    #'   every other value (`1`, `-0.1`, `NA`, a length-2 vector, `NULL`) is
    #'   rejected by `fourfoldplot()` itself. Measured, `k` panels draw
    #'   `13k` or `5k`: `UCBAdmissions` gives 78 and 30, so this count also
    #'   refuses another figure's grob tree.
    #' * the wedges are always the first four in `find_graphics_plot_grobs()`
    #'   order, because `drawPie()` runs before the rings and before the
    #'   frame at every `conf.level`;
    #' * every quarter disc has **501** vertices (`drawPie(n = 500)` plus the
    #'   centre point) and the frame is the only **4**-vertex polygon.
    #'
    #' @param gt Grob tree to search
    #' @param plot_index The plot (panel) index the grob names carry
    #' @return The four wedge grob names, or NULL when this is not one panel
    wedge_names = function(gt, plot_index) {
      poly <- find_graphics_plot_grobs(gt, "polygon", plot_index)
      if (!length(poly) %in% c(5L, 13L)) {
        return(NULL)
      }
      vertices <- vapply(
        poly, function(n) length(grid::getGrob(gt, n)$x), integer(1)
      )
      if (any(vertices[seq_len(4L)] <= 4L)) {
        return(NULL)
      }
      if (vertices[[length(vertices)]] != 4L) {
        return(NULL)
      }
      poly[seq_len(4L)]
    },

    #' @description Whether the wedges on the page are the counts in the call.
    #'
    #' `radius / sqrt(count)` constant across the four quadrants, to a
    #' relative spread of `1e-8`. Measured headroom on the worst-conditioned
    #' tables that `fourfoldplot()` will draw at all --
    #' `c(1e-9, 1, 1, 1)` (`2.220e-16`), `c(1, 2, 3, 1e18)` (`2.068e-16`) and
    #' the non-integer `c(1.5, 2.5, 3.5, 4.5)` (`1.178e-16`) -- is eight
    #' orders below the threshold, while an asymmetric table's `margins`
    #' drawing checked against its counts gives `7.616e-01`. (`c(1, 1e15, 1,
    #' 1)` is not in that list because `radii_agree()` is never asked about
    #' it -- not because it errors. Measured, `fourfoldplot()` returns
    #' normally there with a "NaNs produced" warning and emits ZERO polygon
    #' grobs under `ind.max` and `all.max`, so `wedge_names()` refuses it on
    #' the polygon count first. Under the default `margins` the same table
    #' does draw 13 polygons -- radii `0.00017782794, 0.99999998,
    #' 0.99999998, 0.00017782794` -- but no `margins` call reaches a
    #' processor.)
    #'
    #' A zero count makes `radius / sqrt(count)` `0/0`, so those cells are
    #' held to `radius == 0` instead -- measured, a zero cell still emits a
    #' full 501-vertex polygon at the origin, so the grob is there and
    #' addressable.
    #'
    #' **The check is vacuous when fewer than two cells are non-zero**: one
    #' non-zero cell makes the relative deviation identically 0 whatever the
    #' radius is. Measured, `0, 0, 0, 160` under `ind.max` draws radii
    #' `0, 0, 0, 1` and would pass an unguarded check against any table with
    #' the same three zeros. Two non-zero cells are required before the ratio
    #' is treated as evidence, so such a chart announces its counts and
    #' highlights nothing.
    #'
    #' @param gt Grob tree to search
    #' @param names The four wedge grob names, in drawing order
    #' @param counts The four recorded counts, in `c(tab)` order
    #' @return TRUE when the drawing carries the recorded counts
    radii_agree = function(gt, names, counts) {
      radii <- vapply(names, function(n) {
        g <- grid::getGrob(gt, n)
        max(sqrt(as.numeric(g$x)^2 + as.numeric(g$y)^2))
      }, numeric(1))
      if (!all(is.finite(radii))) {
        return(FALSE)
      }

      drawn <- counts > 0
      if (any(radii[!drawn] != 0)) {
        return(FALSE)
      }
      if (sum(drawn) < 2L) {
        return(FALSE)
      }

      ratio <- radii[drawn] / sqrt(counts[drawn])
      centre <- mean(ratio)
      is.finite(centre) && centre > 0 &&
        max(abs(ratio - centre)) / centre <= 1e-8
    },

    #' @description Address the quadrant the chart drew each count into.
    #'
    #' Each quadrant is its own polygon grob, so each needs its own selector
    #' -- the pie's situation, not the barplot's. Two orderings compose here,
    #' and they run in opposite directions:
    #'
    #' * **The drawing is column-major.** Table cell `[r, c]` is polygon
    #'   `(c - 1) * 2 + r`. Measured on the exported SVG of
    #'   `fourfoldplot(tb, std = "ind.max")` with `c(tab) = 10, 40, 90, 160`,
    #'   the polygon centroids in screen coordinates (the root `<g>` carries
    #'   `translate(0, 360) scale(1, -1)`, so screen `y` is `360 - y`) are
    #'   `polygon-1 (221, 158)` upper LEFT, `polygon-2 (190, 224)` lower LEFT,
    #'   `polygon-3 (345, 114)` upper RIGHT, `polygon-4 (376, 268)` lower
    #'   RIGHT, and the count labels sit at `10 (90, 55)`, `40 (90, 305)`,
    #'   `90 (414, 55)`, `160 (414, 305)`. So table row 1 is the TOP row on
    #'   the page, which is the row `extract_data()` emits first.
    #' * **The `heat` trace reverses the numbers and not the selectors.** In
    #'   the bundled `maidr-4.8.0/maidr.js` the constructor is
    #'   `this.y=[...t.y].reverse(),this.heatmapValues=[...t.points].reverse()`,
    #'   while `mapToSvgElements()`'s array-of-arrays branch walks `e[i]`
    #'   index for index. Its bare-string branch immediately below DOES
    #'   reverse (`let a=t-1-e`), which is what makes the asymmetry easy to
    #'   miss. So `highlightValues[0]` lines up with `points`' LAST row.
    #'
    #' Grid row 1 is therefore the BOTTOM wedges:
    #' `[[polygon-2, polygon-4], [polygon-1, polygon-3]]`. **The wrong answer
    #' is to emit it index-aligned with `points`**, top row first -- it reads
    #' correctly and highlights the vertically mirrored quadrant on every
    #' cell of every fourfold plot: `row 0, col 0` then announces
    #' `Placebo / 40` while lighting the wedge drawn for `Drug / 10`.
    #' `test-base-r-fourfoldplot.R` pins the bottom-first order against that.
    #' `image()`/`heatmap()` is the precedent -- measured on
    #' `image(matrix(1:6, 2))`, `points[[1]]` is the top row while
    #' `selectors[[1]]` is `rect:nth-child(1)`, the lowest rect on the page --
    #' and `NEWS.md` records fixing the same mirror there.
    #'
    #' Returns `list()` when the drawing and the recorded call disagree. The
    #' numbers are still announced -- they are what the call was handed -- and
    #' nothing highlights, rather than a highlight landing on another panel's
    #' quadrant.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @param gt Grob tree to search
    #' @param extracted_data Unused; the counts are re-read from the call
    #' @return A 2x2 nested list of selectors, or an empty list
    generate_selectors = function(layer_info, gt = NULL, extracted_data = NULL) {
      table <- self$recorded_table(layer_info)
      if (is.null(gt) || is.null(table)) {
        return(list())
      }

      plot_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      wedges <- self$wedge_names(gt, plot_index)
      if (is.null(wedges)) {
        return(list())
      }
      if (!self$radii_agree(gt, wedges, as.numeric(table))) {
        return(list())
      }

      lapply(seq_len(2L), function(r) {
        # Grid row 1 is the bottom wedges, so it is table row 2.
        table_row <- 3L - r
        lapply(seq_len(2L), function(cc) {
          polygon_cell_selector(wedges[[(cc - 1L) * 2L + table_row]])
        })
      })
    }
  )
)
