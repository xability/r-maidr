#' The aesthetics that split an uncertainty layer into series
#'
#' Probed in order, and each entry holds the spelling variants of ONE
#' aesthetic, which is the contract `resolve_series_group_mapping()`
#' documents. `colour` first because it is what a dodged interval chart is
#' almost always split by; `group` last, because an author who writes
#' `aes(group = g)` and nothing else has still said what the series are.
#'
#' @keywords internal
INTERVAL_GROUP_AES <- list(
  c("colour", "color"),
  "fill",
  "linetype",
  "shape",
  "group"
)

#' ggplot2 Error Bar Layer Processor
#'
#' Processes ggplot2's uncertainty geoms -- `geom_errorbar()`,
#' `geom_errorbarh()`, `geom_linerange()`, `geom_pointrange()` and
#' `geom_crossbar()` -- into MAIDR's `error_bar` layer.
#'
#' Uncertainty is usually the finding rather than the decoration: whether two
#' group means differ is answered by whether their intervals overlap. Until
#' this processor existed every one of these geoms fell through to
#' `Ggplot2UnknownLayerProcessor`, so the interval was dropped and that
#' comparison was unavailable to a MAIDR reader.
#'
#' ## Reading the right pair of bounds
#'
#' The trap this class exists to avoid is that ggplot2's built data carries
#' **both** pairs for most of these geoms, and only one of them is the
#' interval. A vertical `geom_errorbar()` computes:
#'
#' ```
#'   x  y  ymin ymax  xmin  xmax  flipped_aes
#'   1 4.2  3.8  4.6  0.55  1.45  FALSE
#' ```
#'
#' `ymin`/`ymax` are the interval; `xmin`/`xmax` are the *cap width* -- how
#' wide the little crossbars are drawn, which is a styling parameter and not
#' data at all. Reading the wrong pair yields a chart describing the cap
#' geometry, which is both wrong and plausible-looking.
#'
#' Which pair is the interval is decided by the layer's orientation, and
#' ggplot2 records that in two different ways depending on the geom:
#'
#' \itemize{
#'   \item `geom_errorbar(orientation = "y")` and friends set a `flipped_aes`
#'     column to `TRUE` in the built data.
#'   \item `geom_errorbarh()` has no `flipped_aes` column at all -- it is
#'     horizontal by construction.
#' }
#'
#' Both are handled, because a layer that read only `flipped_aes` would treat
#' every `geom_errorbarh()` as vertical and emit the cap heights as the
#' interval.
#'
#' @keywords internal
Ggplot2ErrorbarLayerProcessor <- R6::R6Class(
  "Ggplot2ErrorbarLayerProcessor",
  inherit = Ggplot2PointLayerProcessor,
  public = list(
    #' @description Process the error bar layer.
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, axes, type and orientation
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer_data <- self$get_layer_built_data(built, panel_id)
      is_horizontal <- self$is_horizontal_layer(plot, layer_data)
      groups <- self$resolve_interval_groups(plot, layer_data, built, panel_id)
      data <- self$extract_interval_data(
        built, layer_data, is_horizontal, panel_id, groups
      )
      samples <- if (is.null(groups)) {
        length(data)
      } else {
        sum(vapply(data, length, integer(1)))
      }

      list(
        data = data,
        selectors = self$generate_selectors(
          plot, gt, grob_id, panel_ctx, samples, groups$order
        ),
        axes = self$attach_group_axis(plot, built, data, groups, panel_id),
        type = "error_bar",
        orientation = if (isTRUE(is_horizontal)) "horz" else "vert"
      )
    },

    #' @description Name the series axis after the legend the chart shows.
    #'
    #' Guarded on the split rather than on the payload's shape, because
    #' `data_has_series_groups()` reads `data[[1]][[1]]$z` and an ungrouped
    #' layer's `data[[1]]` is a point, whose first element is an atomic
    #' category name. The grouped shape is the only one that has a z axis to
    #' name, so asking the split is both safer and the actual question.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @param data The extracted layer data
    #' @param groups The layer's series split, or NULL
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return The axes list, with z added when the layer is grouped
    attach_group_axis = function(plot, built, data, groups, panel_id = NULL) {
      axes <- self$extract_axes_labels(plot, built, panel_id)
      if (is.null(groups)) {
        return(axes)
      }
      attach_series_group_axis(
        axes, plot, built, data, self$get_layer_index(), INTERVAL_GROUP_AES
      )
    },

    #' @description Split the layer's rows into the series the chart draws.
    #'
    #' A dodged interval chart puts one whip per group at every category, and
    #' without the split every category is announced twice with nothing saying
    #' which reading belongs to which group -- so the comparison the figure
    #' exists to support, whether two groups' intervals overlap, is the one
    #' thing unavailable (#183). MAIDR's grammar gained the grouped shape,
    #' `ErrorBarPoint[][]` with a `z` per point, in xability/maidr#942.
    #'
    #' The group each row belongs to cannot be read out of the built data:
    #' `ggplot_build()` replaces the grouping column with an integer `group`
    #' id, and on a discrete x that id is the *interaction* of x and the
    #' grouping aesthetic -- 6 ids for 3 categories and 2 groups, measured --
    #' so it names a cell rather than a series. The aesthetic's own values are
    #' replaced too, by the palette colour they mapped to. The user's frame is
    #' what still holds the names, and it is only usable while it still has a
    #' row per built row: ggplot2 drops rows it cannot draw, and a padded
    #' lookup would name every series `NA`. The same guard
    #' `Ggplot2StackedBarProcessor` applies for the same reason.
    #'
    #' A layer with its own `data` is read from that frame rather than the
    #' plot's, matching ggplot2's own precedence.
    #'
    #' @param plot The ggplot2 object
    #' @param layer_data This layer's computed rows
    #' @param built Built plot data
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A list of `positions` (each row's series, as an index into
    #'   `levels`), `levels` (the series, in the order ggplot2 draws them) and
    #'   `order` (the row indices in series order), or NULL when the layer
    #'   draws a single undivided series
    resolve_interval_groups = function(plot, layer_data, built, panel_id = NULL) {
      if (is.null(layer_data) || nrow(layer_data) < 1L) {
        return(NULL)
      }

      mapping <- resolve_series_group_mapping(
        plot, self$get_layer_index(), INTERVAL_GROUP_AES
      )
      if (is.null(mapping$aes)) {
        return(NULL)
      }

      # The frame lines up with the layer's WHOLE built data, so a faceted
      # layer -- whose rows here are one panel's slice of it -- has to take
      # the same slice of the frame rather than declining the split.
      full <- self$layer_built_rows(built)
      rows <- self$panel_row_indices(full, nrow(layer_data), panel_id)
      if (is.null(rows)) {
        return(NULL)
      }

      frame <- self$interval_group_frame(plot, nrow(full))
      if (is.null(frame) || !mapping$column %in% names(frame)) {
        return(NULL)
      }

      values <- frame[[mapping$column]][rows]
      if (!self$group_values_agree(layer_data, mapping$aes, values)) {
        return(NULL)
      }
      levels <- discrete_level_order(values)
      if (length(levels) < 2L) {
        # One group is not a grouping. The flat payload is the shape MAIDR
        # documents for a single series, and emitting a one-element series of
        # series would announce a group name no reader needs.
        return(NULL)
      }

      # Positions rather than names: a level that is `NA` -- a missing value,
      # which ggplot2 draws as its own series -- cannot be a list name, and
      # `split()` would collapse it onto a level literally spelled "NA".
      positions <- as.integer(
        factor(as.character(values), levels = levels, exclude = NULL)
      )
      order <- unname(unlist(split(seq_len(nrow(layer_data)), positions)))
      list(positions = positions, levels = levels, order = order)
    },

    #' @description Check the frame's values against what the layer drew.
    #'
    #' Row counts agreeing is not the same as rows corresponding. A stat that
    #' happens to emit as many rows as the frame has would pass the count
    #' test while pairing a reading with somebody else's group name -- the
    #' worst failure available here, since every value stays correct and only
    #' the label is a lie.
    #'
    #' What can be checked is that the pairing is *consistent*: ggplot2 keeps
    #' the grouping aesthetic in the built data as the value it mapped to (a
    #' palette colour, a linetype), and a correct pairing gives every row
    #' sharing that drawn value the same name. A shuffled one almost never
    #' does. Falls back to the built `group` id when the aesthetic itself is
    #' not in the built data, which is what an explicit `aes(group = ...)`
    #' leaves behind.
    #'
    #' @param layer_data This layer's computed rows
    #' @param aes_names The winning aesthetic's spelling variants
    #' @param values The frame's grouping values, one per row
    #' @return TRUE when every drawn value carries a single name
    group_values_agree = function(layer_data, aes_names, values) {
      column <- c(aes_names, "group")
      column <- column[column %in% names(layer_data)]
      if (length(column) == 0L) {
        return(FALSE)
      }

      drawn <- level_keys(as.character(layer_data[[column[[1]]]]))
      named <- level_keys(as.character(values))
      if (length(drawn) != length(named)) {
        return(FALSE)
      }
      all(vapply(
        split(named, drawn),
        function(names) length(unique(names)) == 1L,
        logical(1)
      ))
    },

    #' @description This layer's built rows, every panel of them.
    #'
    #' @param built Built plot data
    #' @return A data frame, or NULL when the layer index does not resolve
    layer_built_rows = function(built) {
      index <- self$get_layer_index()
      if (is.null(index) || is.null(built$data) ||
        index < 1L || index > length(built$data)) {
        return(NULL)
      }
      built$data[[index]]
    },

    #' @description Which of the layer's built rows this panel's rows are.
    #'
    #' Mirrors `get_layer_built_data()`, including its fallback: a panel id
    #' that selects nothing leaves the whole layer in place, so the indices
    #' have to as well. Answers NULL when the two do not line up, which is
    #' the signal to decline the split rather than pair rows at random.
    #'
    #' @param full The layer's built rows, every panel of them
    #' @param rows How many rows this panel contributed
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return Integer indices into `full`, or NULL
    panel_row_indices = function(full, rows, panel_id = NULL) {
      if (is.null(full) || nrow(full) < 1L) {
        return(NULL)
      }

      if (!is.null(panel_id) && "PANEL" %in% names(full)) {
        hit <- which(as.character(full$PANEL) == as.character(panel_id))
        if (length(hit) == rows) {
          return(hit)
        }
      }

      if (nrow(full) == rows) seq_len(nrow(full)) else NULL
    },

    #' @description The frame still carrying the grouping column's own values.
    #'
    #' @param plot The ggplot2 object
    #' @param rows How many rows the layer computed
    #' @return A data frame with one row per built row, or NULL
    interval_group_frame = function(plot, rows) {
      layer <- self$get_own_layer(plot)
      candidates <- list(
        if (!is.null(layer)) layer$data else NULL,
        plot$data
      )
      for (frame in candidates) {
        if (is.data.frame(frame) && nrow(frame) == rows) {
          return(frame)
        }
      }
      NULL
    },

    #' @description Decide whether the interval runs along x rather than y.
    #'
    #' Reads `flipped_aes` when the built data carries it, and falls back to
    #' the geom class for `geom_errorbarh()`, which is horizontal by
    #' construction and therefore has no such column to read.
    #'
    #' @param plot The ggplot2 object
    #' @param layer_data This layer's computed rows
    #' @return TRUE when the interval spans the x axis
    is_horizontal_layer = function(plot, layer_data) {
      if (!is.null(layer_data) && "flipped_aes" %in% names(layer_data)) {
        flipped <- layer_data$flipped_aes
        if (length(flipped) > 0 && !is.na(flipped[1])) {
          return(isTRUE(as.logical(flipped[1])))
        }
      }

      layer <- self$get_own_layer(plot)
      if (is.null(layer)) {
        return(FALSE)
      }
      identical(class(layer$geom)[1], "GeomErrorbarh")
    },

    #' @description Whether this layer draws its whole interval as one shape.
    #'
    #' True for a ribbon, which fills a single polygon across every x. Every
    #' other geom this processor serves draws one shape per sample -- a
    #' `segments` grob per `geom_linerange()` row, a polygon per
    #' `geom_crossbar()` box -- which is what makes a per-sample selector
    #' possible at all.
    #'
    #' `class(...)[1]`, matching the adapter's own ribbon test: `GeomArea`
    #' inherits `GeomRibbon` and is not routed here, but an `inherits()` check
    #' would still be the wrong shape of question to ask.
    #'
    #' @param plot The ggplot2 object
    #' @return TRUE when the layer's interval is one undivided shape
    draws_one_shape_for_every_sample = function(plot) {
      index <- self$get_layer_index()
      layers <- plot$layers
      if (is.null(layers) || is.null(index) ||
        index < 1L || index > length(layers)) {
        return(FALSE)
      }
      identical(class(layers[[index]]$geom)[1], "GeomRibbon")
    },

    #' @description Address the drawn interval, one SVG element per sample.
    #'
    #' `ErrorBarTrace.mapToSvgElements` resolves the selectors and requires
    #' the flattened result to be exactly as long as the emitted data; any
    #' other length is discarded and the layer highlights nothing (#145). So
    #' the job here is one element per sample, in the order the data was
    #' emitted -- not one per bound, and not the container.
    #'
    #' The five geoms do not draw alike, and the differences are not
    #' cosmetic. Verified against real `gridSVG::grid.export()` output on
    #' ggplot2 3.4.4:
    #'
    #' \itemize{
    #'   \item `geom_linerange()` -- a `segments` grob named after the geom;
    #'     one `<polyline>` per sample.
    #'   \item `geom_pointrange()` -- a gTree holding that same `segments`
    #'     grob and a `points` grob. The whisker is the one that spans the
    #'     interval, so it is the one addressed.
    #'   \item `geom_crossbar()` -- a gTree holding a `polygon` grob (the box)
    #'     and a `segments` grob (the middle line). The box is the sample.
    #'   \item `geom_errorbar()` / `geom_errorbarh()` -- **an unnamed
    #'     `polyline`**, `GRID.polyline.N`, carrying no geom prefix at all,
    #'     and drawing *three* elements per sample: a cap, the whisker, the
    #'     other cap.
    #' }
    #'
    #' Both of those last two facts are why this could not reuse the
    #' inherited `generate_selectors()`: it matches `geom_point.points` by
    #' name, which reaches none of these, and a name-prefix search reaches
    #' `geom_errorbar()` least of all.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (unused; the drawn grob is
    #'   resolved from the panel, which is what the unnamed polyline needs)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' A grouped layer needs one selector per sample instead of one stride
    #' over all of them, because MAIDR flattens its series before pairing them
    #' against the resolved elements: the payload runs series by series while
    #' the chart draws row by row, and one stride can only ever produce the
    #' drawn order. The per-sample form addresses each mark by the **id**
    #' gridSVG gave it, not by position, so resolving one cannot disturb the
    #' rest -- a positional list would, since resolving a selector inserts a
    #' hidden clone beside the match and shifts every later `nth-child`
    #' (xability/maidr#1004).
    #'
    #' @param sample_count How many points this layer emitted
    #' @param order The row indices in series order, or NULL when the layer
    #'   draws a single undivided series
    #' @return A list of CSS selectors, or an empty list
    generate_selectors = function(plot,
                                  gt = NULL,
                                  grob_id = NULL,
                                  panel_ctx = NULL,
                                  sample_count = NULL,
                                  order = NULL) {
      expected <- suppressWarnings(as.integer(sample_count))
      if (is.null(gt) || length(expected) != 1L || is.na(expected) ||
        expected < 1L) {
        return(list())
      }

      # A ribbon-drawn interval has nothing per-sample to address: the band is
      # one filled polygon covering every x, so there is no `nth-child` stride
      # that reaches sample `i`. Repeating one selector would highlight the
      # whole band at every point and look like it worked -- the same reason
      # `Ggplot2SmoothLayerProcessor` emits none for `geom_smooth()`'s band.
      #
      # Declined here rather than left to the checks below. Those already end
      # in an empty list for a ribbon, but only because the grob lookup finds
      # no errorbar-shaped grob -- an accident of what it searches for, not a
      # statement about the geometry. A later change to the lookup or to
      # `interval_grob_shape()` could start returning a shape for the band and
      # silently mis-highlight it, which is exactly what this says not to do.
      if (self$draws_one_shape_for_every_sample(plot)) {
        return(list())
      }

      grob <- self$find_interval_grob(plot, gt, panel_ctx)
      if (is.null(grob) || is.null(grob$name)) {
        return(list())
      }

      shape <- self$interval_grob_shape(grob)
      if (is.null(shape) || !identical(shape$samples, expected)) {
        return(list())
      }

      if (!is.null(order)) {
        return(self$interval_sample_selectors(
          grob$name, shape$per_sample, order
        ))
      }

      selector <- self$interval_selector(grob$name, shape$per_sample)
      if (is.null(selector)) {
        return(list())
      }
      list(selector)
    },

    #' @description Address one drawn mark per sample, in series order.
    #'
    #' gridSVG gives every exported element its own id, built from the grob's
    #' name: `<grob>.1.<i>` where a sample is drawn as one element, and
    #' `<grob>.1.<i>a`, `<i>b`, `<i>c` where `geom_errorbar()` draws its cap,
    #' whisker and other cap. Measured on ggplot2 3.4.4 across all four
    #' geoms this processor serves. The whisker is the middle one, which is
    #' the same element the stride form's `nth-child(3n+2)` picks -- so a
    #' grouped chart and an ungrouped one outline the same mark.
    #'
    #' Restricted to the two shapes `interval_selector()` handles, for the
    #' same reason: an unverified element count would name a mark by an id
    #' pattern nothing has been checked against.
    #'
    #' @param grob_name Name of the grob whose children are the samples
    #' @param per_sample How many elements the grob draws per sample
    #' @param order The row indices in series order
    #' @return A list of CSS selectors, one per sample, or an empty list
    interval_sample_selectors = function(grob_name, per_sample, order) {
      per_sample <- as.integer(per_sample)
      if (!identical(per_sample, 1L) && !identical(per_sample, 3L)) {
        return(list())
      }

      suffix <- if (identical(per_sample, 3L)) "b" else ""
      lapply(order, function(i) {
        escaped <- gsub(
          "\\.", "\\\\.", paste0(grob_name, ".1.", i, suffix)
        )
        paste0("#", escaped)
      })
    },

    #' @description Find the grob whose children are the samples.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return The grob one of whose child elements is drawn per sample, or
    #'   NULL when it cannot be resolved
    find_interval_grob = function(plot, gt, panel_ctx = NULL) {
      tree <- self$find_layer_grob_tree(plot, gt, panel_ctx)
      if (is.null(tree)) {
        return(self$find_unnamed_interval_grob(plot, gt, panel_ctx))
      }
      if (!inherits(tree, "gTree")) {
        return(tree)
      }

      # A pointrange draws its whisker and its estimate as siblings, and a
      # crossbar its box and its middle line. Prefer whichever child spans
      # the whole interval: the box for a crossbar, the whisker otherwise.
      # Either way it is one element per sample, which the middle line and
      # the estimate also are -- so this decides which element lights up,
      # not whether anything does.
      for (want in c("polygon", "segments", "polyline")) {
        for (child in tree$children) {
          if (identical(class(child)[1], want)) {
            return(child)
          }
        }
      }
      NULL
    },

    #' @description Resolve the drawn grob of a layer ggplot2 left unnamed.
    #'
    #' `geom_errorbar()` and `geom_errorbarh()` draw a bare
    #' `GRID.polyline.N`, so there is no name to match on and
    #' `find_layer_grob_tree()` returns NULL for them. Position is the
    #' remaining handle: ggplot2 lays a panel out as the grill, a leading
    #' `zeroGrob`, **one child per layer in layer order**, a trailing
    #' `zeroGrob` and the border. A layer that draws nothing still takes its
    #' slot as a `zeroGrob`, so the correspondence survives an empty layer
    #' beside this one.
    #'
    #' The leading blank is found by class rather than by an absent name: a
    #' `zeroGrob` is named, and its name is the four characters `"NULL"`.
    #'
    #' It is deliberately narrow. The result has to be a `polyline` for a
    #' geom that is known to draw one, because a positional hit on the wrong
    #' layer would highlight another layer's marks -- worse than the missing
    #' highlight this fixes, since a reader can hear nothing but cannot hear
    #' wrongness.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return The layer's polyline grob, or NULL
    find_unnamed_interval_grob = function(plot, gt, panel_ctx = NULL) {
      layer <- self$get_own_layer(plot)
      if (is.null(layer) ||
        !class(layer$geom)[1] %in% c("GeomErrorbar", "GeomErrorbarh")) {
        return(NULL)
      }

      index <- self$get_layer_index()
      panel <- find_gtable_panel_grob(gt, panel_ctx)
      if (is.null(index) || is.null(panel) || !inherits(panel, "gTree")) {
        return(NULL)
      }

      children <- panel$children
      blanks <- which(vapply(
        children, function(g) inherits(g, "zeroGrob"), logical(1)
      ))
      if (length(blanks) == 0L) {
        return(NULL)
      }

      at <- blanks[1] + as.integer(index)
      if (at < 1L || at > length(children)) {
        return(NULL)
      }
      child <- children[[at]]
      if (!identical(class(child)[1], "polyline") || is.null(child$name)) {
        return(NULL)
      }
      child
    },

    #' @description Count the samples a grob draws, and the elements each takes.
    #'
    #' @param grob The grob resolved for this layer
    #' @return A list of `samples` and `per_sample`, or NULL when the grob is
    #'   not one of the shapes this has been verified against
    interval_grob_shape = function(grob) {
      kind <- class(grob)[1]

      if (identical(kind, "segments")) {
        n <- length(grob$x0)
        if (n < 1L) {
          return(NULL)
        }
        return(list(samples = n, per_sample = 1L))
      }

      if (!kind %in% c("polygon", "polyline")) {
        return(NULL)
      }

      groups <- self$grob_point_groups(grob)
      if (is.null(groups) || length(groups) < 1L) {
        return(NULL)
      }
      runs <- vapply(groups, function(idx) self$drawn_run_count(grob, idx), integer(1))
      if (length(unique(runs)) != 1L) {
        # Samples drawn with different numbers of elements have no single
        # nth-child stride, and guessing one would highlight the wrong mark.
        return(NULL)
      }
      list(samples = length(groups), per_sample = runs[[1]])
    },

    #' @description Split a grob's points into one index vector per sample.
    #'
    #' @param grob A `polygon` or `polyline` grob
    #' @return A list of index vectors in drawing order, or NULL
    grob_point_groups = function(grob) {
      n <- length(grob$x)
      if (n < 1L) {
        return(NULL)
      }

      if (!is.null(grob$id)) {
        keys <- factor(grob$id, levels = unique(grob$id))
        return(unname(split(seq_len(n), keys)))
      }
      if (!is.null(grob$id.lengths)) {
        keys <- rep(seq_along(grob$id.lengths), grob$id.lengths)
        return(unname(split(seq_len(n), keys)))
      }
      list(seq_len(n))
    },

    #' @description Count the elements one sample of a grob is drawn as.
    #'
    #' grid breaks a polyline at a missing point, and `geom_errorbar()` uses
    #' that: its eight points per sample are `cap, NA, whisker, NA, cap`, so
    #' the export carries three elements for the one bar. A run needs two
    #' points to be a line at all, and a shorter one draws nothing.
    #'
    #' @param grob A `polygon` or `polyline` grob
    #' @param index The point indices belonging to one sample
    #' @return How many elements that sample is drawn as
    drawn_run_count = function(grob, index) {
      xs <- suppressWarnings(as.numeric(grob$x[index]))
      ys <- suppressWarnings(as.numeric(grob$y[index]))
      drawn <- !is.na(xs) & !is.na(ys)
      if (!any(drawn)) {
        return(0L)
      }
      runs <- rle(drawn)
      as.integer(sum(runs$values & runs$lengths >= 2L))
    },

    #' @description Build the CSS selector for one element per sample.
    #'
    #' gridSVG wraps each grob in a `<g>` named after it with a `.1` suffix
    #' and writes its elements inside in drawing order, so the samples are
    #' addressable as a stride through that group's children.
    #'
    #' Only the two strides that have been checked against an export are
    #' emitted: one element per sample, and the three a `geom_errorbar()`
    #' draws, of which the middle one is the whisker spanning the interval --
    #' the cap either side of it says nothing a reader is navigating to. Any
    #' other stride returns NULL and the layer goes back to highlighting
    #' nothing, which is the honest answer for a shape nobody has looked at.
    #'
    #' @param grob_name The drawn grob's name
    #' @param per_sample How many elements each sample is drawn as
    #' @return A CSS selector, or NULL
    interval_selector = function(grob_name, per_sample) {
      escaped <- gsub("\\.", "\\\\.", paste0(grob_name, ".1"))
      group <- paste0("g#", escaped)

      if (identical(as.integer(per_sample), 1L)) {
        return(paste0(group, " > *"))
      }
      if (identical(as.integer(per_sample), 3L)) {
        return(paste0(group, " > *:nth-child(3n+2)"))
      }
      NULL
    },

    #' @description Build the MAIDR points for this layer.
    #'
    #' The emitted shape names the category `x` and the magnitude `y` in both
    #' orientations, with the bounds in `yMin`/`yMax`, and lets `orientation`
    #' say which is on screen where. That is the shape MAIDR's `ErrorBarTrace`
    #' consumes: it reads the magnitude as `y`/`yMin`/`yMax` with no
    #' orientation branch, so emitting screen-aligned keys would leave a
    #' horizontal chart with no interval at all.
    #'
    #' A row missing its bounds still emits its estimate. A one-sided interval
    #' is a real chart, and dropping the point for want of its other half
    #' would lose the estimate too.
    #'
    #' A grouped layer emits one series per group instead, each point
    #' carrying its group's name as `z` -- the shape every other grouped
    #' layer in this package already emits, and the one MAIDR's `ErrorBarTrace`
    #' reads as a series of series.
    #'
    #' @param built Built plot data
    #' @param layer_data This layer's computed rows
    #' @param is_horizontal Whether the interval spans the x axis
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param groups The layer's series split, or NULL for a single series
    #' @return A list of MAIDR interval points, or a list of such lists when
    #'   the layer is grouped
    extract_interval_data = function(built,
                                     layer_data,
                                     is_horizontal,
                                     panel_id = NULL,
                                     groups = NULL) {
      if (is.null(layer_data)) {
        return(list())
      }

      # The interval runs along one axis and the categories along the other.
      # For a horizontal layer the roles swap, and reading the y pair there
      # would emit the cap heights -- a styling parameter -- as the data.
      value_col <- if (isTRUE(is_horizontal)) "x" else "y"
      category_col <- if (isTRUE(is_horizontal)) "y" else "x"
      min_col <- if (isTRUE(is_horizontal)) "xmin" else "ymin"
      max_col <- if (isTRUE(is_horizontal)) "xmax" else "ymax"

      if (!category_col %in% names(layer_data)) {
        return(list())
      }

      categories <- self$resolve_category_labels(
        built, layer_data, category_col, panel_id
      )
      values <- self$resolve_estimates(layer_data, value_col, min_col, max_col)
      if (is.null(values)) {
        return(list())
      }
      lower <- if (min_col %in% names(layer_data)) layer_data[[min_col]] else NULL
      upper <- if (max_col %in% names(layer_data)) layer_data[[max_col]] else NULL

      build_point <- function(i, z = NULL) {
        point <- list(x = categories[[i]], y = as.numeric(values[i]))

        if (!is.null(lower) && is.finite(lower[i])) {
          point$yMin <- as.numeric(lower[i])
        }
        if (!is.null(upper) && is.finite(upper[i])) {
          point$yMax <- as.numeric(upper[i])
        }
        if (!is.null(z)) {
          point$z <- z
        }

        point
      }

      if (is.null(groups)) {
        return(lapply(seq_len(nrow(layer_data)), build_point))
      }

      # One series per level, in the order ggplot2 draws them, and the rows
      # within a series in the order the layer computed them. That is the
      # order `generate_selectors()` names the marks in, and the two have to
      # be the one order: MAIDR pairs the flattened points against the
      # flattened selectors position by position.
      by_level <- split(seq_len(nrow(layer_data)), groups$positions)
      lapply(seq_along(groups$levels), function(position) {
        rows <- by_level[[as.character(position)]]
        if (is.null(rows)) {
          return(list())
        }
        lapply(rows, build_point, z = level_label(groups$levels[[position]]))
      })
    },

    #' @description Resolve the estimate each interval is centred on.
    #'
    #' The estimate aesthetic is **optional** on these geoms, and leaving it
    #' out is idiomatic rather than exotic:
    #' `geom_errorbar(aes(x, ymin, ymax))` layered over a `geom_col()` is the
    #' standard way to draw a bar chart with error bars, and it builds with no
    #' `y` column at all. `geom_linerange()` is the same. Requiring the column
    #' dropped every such layer silently -- no interval, no estimate, no error.
    #'
    #' When it is absent the chart genuinely draws no estimate, only a span, so
    #' the centre of that span is used. That is a property of the drawn bar
    #' rather than a claim about an unobserved estimate, and it is what keeps
    #' the bounds -- which are the real data here -- reachable at all. It is
    #' NOT the mean for an asymmetric interval, and nothing here pretends it
    #' is: a layer that carries `y` always uses the value the chart drew.
    #'
    #' @param layer_data This layer's computed rows
    #' @param value_col The estimate column for this orientation
    #' @param min_col The lower bound column for this orientation
    #' @param max_col The upper bound column for this orientation
    #' @return A numeric vector of estimates, or NULL when neither the estimate
    #'   nor a pair of bounds is present
    resolve_estimates = function(layer_data, value_col, min_col, max_col) {
      if (value_col %in% names(layer_data)) {
        return(as.numeric(layer_data[[value_col]]))
      }

      if (!all(c(min_col, max_col) %in% names(layer_data))) {
        return(NULL)
      }

      (as.numeric(layer_data[[min_col]]) + as.numeric(layer_data[[max_col]])) / 2
    },

    #' @description Recover the names behind a discrete category axis.
    #'
    #' ggplot2 maps a discrete axis onto integer positions before it computes
    #' the layer, so the built data carries `1, 2, 3` where the chart draws
    #' `control, high dose, low dose`. Announcing the positions would name
    #' something the reader cannot find anywhere on the chart -- and the
    #' positions are assigned in the scale's order, not the data's, so they do
    #' not even read as row numbers.
    #'
    #' The labels come from the panel's scale rather than from the data frame,
    #' which is what makes the position an index into them.
    #'
    #' @param built Built plot data
    #' @param layer_data This layer's computed rows
    #' @param category_col Which built column carries the category
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A list of labels -- strings for a discrete axis, numbers for a
    #'   continuous one
    resolve_category_labels = function(built,
                                       layer_data,
                                       category_col,
                                       panel_id = NULL) {
      raw <- layer_data[[category_col]]

      if (is.factor(raw)) {
        return(as.list(as.character(raw)))
      }

      labels <- self$category_axis_labels(built, category_col, panel_id)
      if (is.null(labels)) {
        return(lapply(raw, as.numeric))
      }

      lapply(raw, function(position) {
        index <- suppressWarnings(as.integer(round(as.numeric(position))))
        if (!is.na(index) && index >= 1 && index <= length(labels)) {
          labels[[index]]
        } else {
          as.numeric(position)
        }
      })
    },

    #' @description Read the break labels of the category axis, when discrete.
    #'
    #' @param built Built plot data
    #' @param category_col Which built column carries the category
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A character vector of labels, or NULL on a continuous axis
    category_axis_labels = function(built, category_col, panel_id = NULL) {
      panel_params <- built$layout$panel_params
      if (is.null(panel_params) || length(panel_params) == 0) {
        return(NULL)
      }

      # An unfaceted plot passes no panel id at all, so this has to survive
      # NULL and a non-numeric id, not just an out-of-range one.
      index <- suppressWarnings(as.integer(panel_id))
      params <- if (length(index) == 1 && !is.na(index) &&
        index >= 1 && index <= length(panel_params)) {
        panel_params[[index]]
      } else {
        panel_params[[1]]
      }

      scale <- params[[category_col]]
      if (is.null(scale) || is.null(scale$get_labels)) {
        return(NULL)
      }

      # A continuous axis has break labels too ("0", "25", ...), and those are
      # NOT an index into anything -- treating them as one would rename every
      # point. Only a discrete scale maps positions onto labels this way.
      if (!isTRUE(scale$is_discrete())) {
        return(NULL)
      }

      labels <- suppressWarnings(scale$get_labels())
      if (is.null(labels) || length(labels) == 0) {
        return(NULL)
      }
      as.character(labels)
    }
  )
)
