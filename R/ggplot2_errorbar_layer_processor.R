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
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, axes, type and orientation
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      layer_data <- self$get_layer_built_data(built, panel_id)
      is_horizontal <- self$is_horizontal_layer(plot, layer_data)
      data <- self$extract_interval_data(
        built, layer_data, is_horizontal, panel_id
      )

      list(
        data = data,
        selectors = self$generate_selectors(
          plot, gt, grob_id, panel_ctx, length(data)
        ),
        axes = self$extract_axes_labels(plot, built, panel_id),
        type = "error_bar",
        orientation = if (isTRUE(is_horizontal)) "horz" else "vert"
      )
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
    #' @param sample_count How many points this layer emitted
    #' @return A list holding one CSS selector, or an empty list
    generate_selectors = function(plot,
                                  gt = NULL,
                                  grob_id = NULL,
                                  panel_ctx = NULL,
                                  sample_count = NULL) {
      expected <- suppressWarnings(as.integer(sample_count))
      if (is.null(gt) || length(expected) != 1L || is.na(expected) ||
        expected < 1L) {
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

      selector <- self$interval_selector(grob$name, shape$per_sample)
      if (is.null(selector)) {
        return(list())
      }
      list(selector)
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
    #' @param built Built plot data
    #' @param layer_data This layer's computed rows
    #' @param is_horizontal Whether the interval spans the x axis
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A list of MAIDR interval points
    extract_interval_data = function(built,
                                     layer_data,
                                     is_horizontal,
                                     panel_id = NULL) {
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

      points <- vector("list", nrow(layer_data))
      for (i in seq_len(nrow(layer_data))) {
        point <- list(x = categories[[i]], y = as.numeric(values[i]))

        if (!is.null(lower) && is.finite(lower[i])) {
          point$yMin <- as.numeric(lower[i])
        }
        if (!is.null(upper) && is.finite(upper[i])) {
          point$yMax <- as.numeric(upper[i])
        }

        points[[i]] <- point
      }

      points
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
