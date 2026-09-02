#' Rug Layer Processor
#'
#' @description
#' Reads `geom_rug()` as the observations it marks.
#'
#' A rug draws one short tick per row against the edge of the panel. What it
#' states is the **raw data** -- which is exactly what the density curve or
#' histogram it usually accompanies does not. Until #222 the layer reached
#' `Ggplot2UnknownLayerProcessor`: a rug-only chart emitted one empty layer
#' and a rug beside a scatter added an empty one a reader could land on and
#' find nothing in.
#'
#' Read as **points**, which is the reading py-maidr settled on for
#' `seaborn.rugplot` (xability/py-maidr#250). `length` is one number for the
#' whole layer, so a tick's *length* is decoration and only its position is
#' data -- the same argument the event-plot reading makes about its ticks. The
#' coordinate across the tick is emitted as a constant rather than as the
#' tick's own base, because that base is a fraction of the panel and would
#' read as data at whatever scale the other axis happens to use.
#'
#' ## One layer per axis
#'
#' `geom_rug()` defaults to `sides = "bl"`, so on a chart with both aesthetics
#' mapped it marks **both** -- and the built data carries both columns. So this
#' emits up to two layers: the x observations and the y observations.
#'
#' Not one per drawn grob. `sides = "trbl"` draws the same x observations at
#' top *and* bottom, and emitting that twice would have a reader navigate the
#' same numbers under two names. Measured on four rows:
#'
#' ```
#' sides="b"      GRID.segments.1  : x (n=4)
#' sides="l"      GRID.segments.41 : y (n=4)
#' sides="bl"     GRID.segments.78 : x (n=4)   GRID.segments.79 : y (n=4)
#' sides="trbl"   .116: x   .117: x   .118: y   .119: y
#' ```
#'
#' A side is drawn only where the matching aesthetic exists -- `sides = "bl"`
#' with only `aes(x = v)` gives one grob -- so the layers follow the built
#' data's columns rather than a parse of the `sides` string.
#'
#' @keywords internal
Ggplot2RugLayerProcessor <- R6::R6Class(
  "Ggplot2RugLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the rug layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return A single layer, or a `multi_layer` result carrying two
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
      rows <- self$layer_rows(built, panel_id)
      if (is.null(rows) || nrow(rows) == 0) {
        return(NULL)
      }

      marked <- self$marked_axes(rows, plot$layers[[self$get_layer_index()]])
      if (length(marked) == 0) {
        return(NULL)
      }

      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      layers <- lapply(marked, function(axis) {
        self$axis_layer(plot, layout, rows, axis, gt, panel_ctx, built, panel_id)
      })

      if (length(layers) == 1) {
        return(layers[[1]])
      }
      list(multi_layer = TRUE, layers = layers)
    },

    #' @description This layer's rows of the built data
    #'
    #'   Not `LayerProcessor$get_layer_built_data()`, and the difference is
    #'   the point rather than an oversight. That method falls back to **all**
    #'   panels' rows when the panel-scoped subset comes back empty, and a rug
    #'   is a chart where an empty subset is real: a `facet_grid()` cell that
    #'   no row falls in draws no ticks. Measured on a grid with two populated
    #'   cells of two ticks each --
    #'
    #'   ```
    #'   panel 1 -> layer_rows: 2   get_layer_built_data: 2
    #'   panel 2 -> layer_rows: 0   get_layer_built_data: 4
    #'   panel 3 -> layer_rows: 0   get_layer_built_data: 4
    #'   panel 4 -> layer_rows: 2   get_layer_built_data: 2
    #'   ```
    #'
    #'   -- so the inherited helper would have the two empty panels each
    #'   announce all four observations, drawn in the other two. An empty
    #'   subset is returned as it is, and `process()` reads it as the "no
    #'   layer" it is.
    #'
    #'   Written down because the two look interchangeable and are not:
    #'   swapping this for the inherited helper is a one-line simplification
    #'   that reintroduces the bug silently.
    #'   `test-ggplot2-rug.R` pins the panel that draws nothing.
    #' @param built Built plot data
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A data frame, or NULL
    layer_rows = function(built, panel_id = NULL) {
      index <- self$get_layer_index()
      if (is.null(index) || index < 1L || index > length(built$data)) {
        return(NULL)
      }
      rows <- built$data[[index]]
      if (!is.null(panel_id) && "PANEL" %in% names(rows)) {
        rows <- rows[as.character(rows$PANEL) == as.character(panel_id), ,
          drop = FALSE
        ]
      }
      rows
    },

    #' @description Which axes this rug actually marks
    #'
    #'   Both halves are needed, and measuring showed why. The built data's
    #'   columns are not enough on their own: `geom_rug(sides = "b")` on
    #'   `aes(v, w)` carries a `y` column and draws no left rug, and reading
    #'   the columns alone emitted a y layer for observations the chart never
    #'   marked -- a whole layer invented out of an aesthetic that was mapped
    #'   for the *scatter* underneath.
    #'
    #'   `sides` is not enough either, in the other direction: it defaults to
    #'   `"bl"` on every rug, and one drawn over `aes(x = v)` alone has no `y`
    #'   to mark. So a side counts only where both agree, which is exactly
    #'   what the drawing does -- measured, `sides = "bl"` gives two grobs
    #'   with both aesthetics mapped and one with only `x`.
    #' @param rows This layer's rows of the built data
    #' @param layer This layer, for its `sides`
    #' @return A character vector, a subset of `c("x", "y")`, in that order
    marked_axes = function(rows, layer) {
      sides <- tryCatch(layer$geom_params$sides, error = function(e) NULL)
      # ggplot2's own default, restated rather than assumed absent: a layer
      # built by hand may carry no `sides` at all.
      sides <- if (is.null(sides)) "bl" else as.character(sides)
      drawn <- strsplit(sides, "")[[1]]

      edges <- list(x = c("t", "b"), y = c("l", "r"))
      Filter(function(axis) {
        # No `axis %in% names(rows)` beside it: a missing column indexes to
        # NULL, and `any(!is.na(NULL))` is already FALSE, so the two clauses
        # decide the same thing and no test could tell them apart.
        any(edges[[axis]] %in% drawn) && any(!is.na(rows[[axis]]))
      }, c("x", "y"))
    },

    #' @description One axis' observations as a point layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param rows This layer's rows of the built data
    #' @param axis `"x"` or `"y"`
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @param built Built plot data, for the axis bounds
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return A layer list
    axis_layer = function(plot, layout, rows, axis, gt, panel_ctx,
                          built = NULL, panel_id = NULL) {
      values <- rows[[axis]]
      keep <- !is.na(values)
      values <- values[keep]

      data <- lapply(values, function(value) {
        if (identical(axis, "x")) {
          list(x = as.numeric(value), y = 0)
        } else {
          list(x = 0, y = as.numeric(value))
        }
      })

      list(
        type = "point",
        data = data,
        axes = self$axis_labels(layout, axis, built, panel_id),
        selectors = self$generate_selectors(plot, gt, axis, sum(keep), panel_ctx)
      )
    },

    #' @description Name the axes, calling the strip the ticks sit in what it is
    #'
    #'   The axis carrying the observations keeps the chart's own label. The
    #'   one across the ticks is renamed even where the caller labelled it: a
    #'   rug under a density curve has a real "density" label on that axis,
    #'   and every entry this layer emits sits at 0 rather than at any
    #'   density.
    #'   Both carry bounds as well, and that is what makes the layer reachable
    #'   in grid mode -- the only mode where a point layer renders braille at
    #'   all. Measured against maidr's `ScatterTrace`: with the labels alone
    #'   the braille state comes back empty, and a rug is then the one chart
    #'   with no braille surface reachable by any keystroke. With them, four
    #'   observations at 1, 2, 3 and 9 over a 0-10 axis give
    #'   `values [[2, 1, 0, 1]]` -- the observation count per cell, which is
    #'   the clustering a rug is drawn to show and the one thing its audio
    #'   cannot carry, every tick sitting at the same place on the axis pitch
    #'   is mapped from (xability/maidr#1132).
    #'
    #'   The observation axis takes the chart's own bounds, through the same
    #'   `axis_grid_info()` the point processor reads, and is declined on the
    #'   same grounds. The axis across the ticks is supplied whole as 0 to 1
    #'   in one step: a rug is one row deep by construction, and a finer step
    #'   buys a second row of zeroes -- measured, `tickStep` 0.5 gives
    #'   `[[2, 1, 0, 1], [0, 0, 0, 0]]`.
    #'
    #'   Additive only: grid mode is entered deliberately, and the ordinary
    #'   reading is untouched.
    #' @param layout Layout information
    #' @param axis `"x"` or `"y"`
    #' @param built Built plot data, for the observation axis' bounds
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @return An axes list
    axis_labels = function(layout, axis, built = NULL, panel_id = NULL) {
      own <- extract_axis_label(layout$axes[[axis]], default = axis)
      bounds <- if (is.null(built)) NULL else axis_grid_info(built, axis, panel_id)

      along <- if (is.null(bounds)) {
        build_axis_config(label = own)
      } else {
        build_axis_config(
          label = own, min = bounds$min, max = bounds$max,
          tickStep = bounds$tickStep
        )
      }
      # The strip is given bounds only when the observation axis has them:
      # a grid needs both, and half of one is a surface the frontend cannot
      # build anyway.
      across <- if (is.null(bounds)) {
        build_axis_config(label = RUG_AXIS_LABEL)
      } else {
        build_axis_config(label = RUG_AXIS_LABEL, min = 0, max = 1, tickStep = 1)
      }

      if (identical(axis, "x")) {
        build_axes(x = along, y = across)
      } else {
        build_axes(x = across, y = along)
      }
    },

    #' @description Address each tick by the element it was drawn as
    #'
    #'   `geom_rug()` draws one `segmentsGrob` per side, and gridSVG exports
    #'   that as one element per segment carrying an id of the form
    #'   `<grob>.1.<n>` -- the shape #194 measured for `geom_segment()`, whose
    #'   `GRID.segments.38.1.1` through `.4` follow built-data order.
    #'
    #'   The grob cannot be found by name: ggplot2 gives a rug layer no geom
    #'   prefix, so it arrives as grid's automatic `GRID.segments.N`, whose
    #'   number is a global counter and not stable between sessions. It is
    #'   located by class and by position instead, and read off the gtable
    #'   being exported rather than reconstructed.
    #'
    #'   Where a rug draws one axis **twice** -- `sides = "tb"`, or `"trbl"` --
    #'   the first grob for that axis is addressed. The two are copies of one
    #'   observation, so highlighting one of them is partial; highlighting
    #'   neither is worse, and #145 settled that a selector list which does not
    #'   match the point count is withdrawn wholesale rather than applied in
    #'   part. An empty list is returned when the grob cannot be resolved, for
    #'   that same reason: a guess at its name is worse than no highlighting.
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param axis `"x"` or `"y"`
    #' @param count How many ticks this layer emits
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return A list of CSS selectors, one per tick
    generate_selectors = function(plot, gt, axis, count, panel_ctx = NULL) {
      if (count < 1) {
        return(list())
      }
      name <- self$find_segments_name(plot, gt, axis, panel_ctx)
      if (is.null(name)) {
        return(list())
      }
      lapply(seq_len(count), function(index) {
        paste0("*[id='", name, ".1.", index, "']")
      })
    },

    #' @description The grob holding this layer's ticks for one axis
    #'
    #'   `geom_rug()` wraps its grobs in a `gTree` of its own -- measured, a
    #'   `sides = "bl"` rug gives `GRID.gTree.3` holding `GRID.segments.1` and
    #'   `GRID.segments.2`, and two rug layers give two such trees in layer
    #'   order. So one layer's grobs arrive as a block already, and there is
    #'   nothing to slice.
    #'
    #'   That wrapping is also what tells a rug from its neighbours.
    #'   `geom_segment()` draws a **bare** `segments` grob directly under the
    #'   panel:
    #'
    #'   ```
    #'   rug + segment    GRID.segments.117            <- the segment layer
    #'                    GRID.gTree.120
    #'                      GRID.segments.118          <- the rug, x
    #'                      GRID.segments.119          <- the rug, y
    #'   ```
    #'
    #'   So a candidate is a directly-held `gTree` with grid's automatic name
    #'   whose children are every one a `segments` grob, and the nth of those
    #'   belongs to the nth rug layer. Matching on the name is necessary as
    #'   well as the class: a layer ggplot2 *does* name arrives with its geom's
    #'   prefix, and one of those is not a rug whatever it holds.
    #'
    #'   Which axis a grob stands on it answers itself: a tick standing on x
    #'   is held constant in `y`, so `y0` is a single recycled value while
    #'   `x0` carries one entry per observation. The same property py-maidr's
    #'   `read_rug` uses, and it needs no reference to `sides`.
    #'
    #'   Where a rug draws one axis **twice** -- `sides = "tb"`, or `"trbl"` --
    #'   the first grob for that axis wins. The two are copies of one
    #'   observation, so highlighting one of them is partial; highlighting
    #'   neither is worse, and #145 settled that a selector list which does not
    #'   match the point count is withdrawn wholesale rather than in part.
    #' @param plot The ggplot2 object
    #' @param gt Gtable object
    #' @param axis `"x"` or `"y"`
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return The grob name, or NULL when it cannot be resolved
    find_segments_name = function(plot, gt, axis, panel_ctx = NULL) {
      position <- self$position_among_rugs(plot)
      if (is.null(position)) {
        return(NULL)
      }

      trees <- self$rug_trees(gt, panel_ctx)
      if (position > length(trees)) {
        return(NULL)
      }

      for (child in trees[[position]]$children) {
        if (identical(self$axis_of(child), axis)) {
          return(child$name)
        }
      }
      NULL
    },

    #' @description This layer's place among the plot's rug layers
    #'
    #'   Counted among its own kind, so a second `geom_rug()` reaches its own
    #'   grobs rather than the first one's -- the rule
    #'   `Ggplot2GanttLayerProcessor$find_segments_name()` applies, for the
    #'   same reason.
    #' @param plot The ggplot2 object
    #' @return The 1-based position, or NULL when the layer cannot be found
    position_among_rugs = function(plot) {
      target <- self$get_layer_index()
      if (is.null(plot) || is.null(plot$layers) || is.null(target) ||
        target < 1L || target > length(plot$layers)) {
        return(NULL)
      }
      position <- 0L
      for (i in seq_along(plot$layers)) {
        if (identical(class(plot$layers[[i]]$geom)[1], "GeomRug")) {
          position <- position + 1L
          if (i == target) {
            return(position)
          }
        }
      }
      NULL
    },

    #' @description The panel's rug wrappers, in drawing order
    #' @param gt Gtable object
    #' @param panel_ctx Panel context for patchwork leaves and facets
    #' @return A list of gTrees
    rug_trees = function(gt, panel_ctx = NULL) {
      roots <- if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (is.null(panel_grob)) list() else list(panel_grob)
      } else if ("grobs" %in% names(gt)) {
        gt$grobs
      } else {
        list(gt)
      }

      trees <- list()
      collect <- function(node) {
        if (self$wraps_a_rug(node)) {
          trees[[length(trees) + 1L]] <<- node
          return(invisible(NULL))
        }
        if (inherits(node, "gTree")) {
          for (child in node$children) collect(child)
        }
        if (inherits(node, "gList")) {
          for (i in seq_along(node)) collect(node[[i]])
        }
        invisible(NULL)
      }
      for (root in roots) collect(root)
      trees
    },

    #' @description Whether a grob is one rug layer's wrapper
    #' @param node A grob
    #'   The name test is a guard rather than a live branch, and is kept as
    #'   one deliberately. Measured across every geom that draws segments --
    #'   boxplot, violin, errorbar, crossbar, pointrange, linerange, step, a
    #'   reference line -- **none** produces a gTree whose children are all
    #'   segments, so today the class test alone decides and dropping the name
    #'   test changes no reading. `test-ggplot2-rug.R` pins that measurement,
    #'   so the ggplot2 release that ends it turns a test red rather than
    #'   leaving this silently load-bearing.
    #' @param node A grob
    #' @return TRUE when it is a `GRID.gTree` of nothing but segments
    wraps_a_rug = function(node) {
      if (!inherits(node, "gTree")) {
        return(FALSE)
      }
      name <- node$name
      if (is.null(name) || !is.character(name) || length(name) != 1L) {
        return(FALSE)
      }
      if (!startsWith(name, "GRID.gTree")) {
        return(FALSE)
      }
      children <- node$children
      length(children) > 0 &&
        all(vapply(children, function(c) inherits(c, "segments"), logical(1)))
    },

    #' @description Which axis one segments grob's ticks stand on
    #' @param grob A `segments` grob
    #' @return `"x"`, `"y"`, or NA when it says neither
    axis_of = function(grob) {
      across_y <- length(grob$y0) == 1L
      across_x <- length(grob$x0) == 1L
      if (across_y && !across_x) {
        return("x")
      }
      if (across_x && !across_y) {
        return("y")
      }
      # A one-observation rug is constant on both, and says neither. Nothing
      # is guessed: the layer keeps its readings and loses only the
      # highlighting, which is the trade #145 already settled.
      NA_character_
    }
  )
)

#' What the axis across a rug's ticks is called
#'
#' Every entry a rug layer emits sits at the same place on that axis, so
#' whatever the panel calls it measures nothing here. Named rather than left
#' blank, and named the same thing py-maidr names it, so the two bindings
#' announce one chart the same way.
#'
#' @keywords internal
RUG_AXIS_LABEL <- "Rug"
