#' Base R Contour Layer Processor
#'
#' @description
#' Reads a base R `contour()` call as the contour it draws.
#'
#' `contour()` had no processor. `base_r_adapter` mapped the call to the type
#' `"contour"` and the factory fell through to the generic processor, so the
#' layer shipped typed `"unknown"` -- and the core's trace factory ends its
#' dispatch with `throw new Error("Invalid trace type: …")`, so the figure
#' bound interactively and then failed to construct. #214 stopped that by
#' typing the call `"unknown"` at the adapter, which degrades to a static
#' image; this replaces the picture with the reading (#218).
#'
#' The curves come from `grDevices::contourLines()`, which is the same
#' computation `contour()` does and takes the same defaults, so nothing here
#' is a guess about what was drawn:
#'
#' \preformatted{
#' contour.default(x = seq(0, 1, length.out = nrow(z)),
#'                 y = seq(0, 1, length.out = ncol(z)),
#'                 z, nlevels = 10, levels = pretty(zlim, nlevels),
#'                 zlim = range(z, finite = TRUE))
#' }
#'
#' The payload matches `ggplot2_contour_layer_processor.R` exactly -- a list
#' of curves, each a list of `{x, y, level}` -- so the two adapters describe
#' one chart the same way.
#'
#' @keywords internal
BaseRContourLayerProcessor <- R6::R6Class(
  "BaseRContourLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Build the layer
    #' @param plot,layout,built,gt,grob_id,panel_id,panel_ctx Pipeline arguments
    #' @param layer_info The recorded call
    #' @return List with data, selectors, type, title and axes
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      curves <- self$extract_data(layer_info)

      list(
        data = curves,
        selectors = self$generate_selectors(layer_info, gt, length(curves)),
        type = "contour",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info)
      )
    },

    #' @description Read the drawn curves off the recorded call
    #' @param layer_info The recorded call
    #' @return A list of curves, each a list of `{x, y, level}` points
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      grid <- self$contour_grid(layer_info$plot_call$args)
      if (is.null(grid)) {
        return(list())
      }

      curves <- tryCatch(
        grDevices::contourLines(
          x = grid$x, y = grid$y, z = grid$z, levels = grid$levels
        ),
        error = function(e) list()
      )

      drawn <- list()
      for (curve in curves) {
        # A curve of one vertex is a place the field touched a level rather
        # than a curve along it, and there is nothing to move along. The
        # ggplot2 processor drops these for the same reason.
        if (length(curve$x) < 2L) {
          next
        }
        drawn[[length(drawn) + 1L]] <- lapply(seq_along(curve$x), function(i) {
          list(
            x = as.numeric(curve$x[i]),
            y = as.numeric(curve$y[i]),
            level = as.numeric(curve$level)
          )
        })
      }

      drawn
    },

    #' @description The grid and levels the call drew, or NULL when it drew none
    #'
    #'   Resolved the way `contour.default` resolves it, rather than by a rule
    #'   of our own. Its arguments are `(x, y, z, ...)`; a named argument
    #'   claims its slot and the unnamed ones fill what is left, in order.
    #'   Then, and only then:
    #'
    #'   \preformatted{
    #'   if (missing(z) && !missing(x) && !is.list(x)) { z <- x; x <- NULL }
    #'   }
    #'
    #'   which is what makes `contour(m)` a contour *of* `m` rather than a
    #'   chart with `m` on the x axis.
    #'
    #'   Reproducing that matters because the wrapper records a partially
    #'   named call: measured, `contour(c(10, 20, 30), c(100, 200, 300), z)`
    #'   arrives as one unnamed argument plus `y =` and `z =`. A rule that
    #'   looked for the matrix and took the unnamed arguments *before* it
    #'   found `z` already named, never looked at the unnamed one, and
    #'   announced the caller's grid on the 0-1 default -- every coordinate
    #'   wrong, and nothing raised.
    #' @param args The recorded call's arguments
    #' @return A list of `x`, `y`, `z` and `levels`, or NULL
    contour_grid = function(args) {
      if (length(args) == 0) {
        return(NULL)
      }

      arg_names <- names(args)
      unnamed <- if (is.null(arg_names)) {
        seq_along(args)
      } else {
        which(!nzchar(arg_names))
      }

      slots <- list(x = args[["x"]], y = args[["y"]], z = args[["z"]])
      unclaimed <- names(slots)[vapply(slots, is.null, logical(1))]
      for (i in seq_along(unnamed)) {
        if (i > length(unclaimed)) {
          break
        }
        slots[[unclaimed[i]]] <- args[[unnamed[i]]]
      }

      x <- slots$x
      y <- slots$y
      z <- slots$z

      if (is.null(z) && !is.null(x) && !is.list(x)) {
        z <- x
        x <- NULL
      }

      if (!is.matrix(z) || !is.numeric(z)) {
        return(NULL)
      }
      if (nrow(z) < 2L || ncol(z) < 2L) {
        # `contourLines` needs at least two rows and columns to have anything
        # between which to interpolate, and `contour()` itself errors here.
        return(NULL)
      }

      finite <- z[is.finite(z)]
      if (length(finite) == 0) {
        return(NULL)
      }

      # `contour()`'s own defaults, so the levels are the ones it drew rather
      # than a plausible set of our own.
      if (is.null(x)) x <- seq(0, 1, length.out = nrow(z))
      if (is.null(y)) y <- seq(0, 1, length.out = ncol(z))

      levels <- args[["levels"]]
      if (is.null(levels)) {
        nlevels <- args[["nlevels"]]
        if (is.null(nlevels)) nlevels <- 10
        zlim <- args[["zlim"]]
        if (is.null(zlim)) zlim <- range(finite)
        levels <- pretty(zlim, nlevels)
      }

      if (length(x) != nrow(z) || length(y) != ncol(z)) {
        return(NULL)
      }

      list(x = as.numeric(x), y = as.numeric(y), z = z,
           levels = as.numeric(levels))
    },

    #' @description Name the two axes
    #'
    #'   Only x and y. The level is not an axis here: it travels on every
    #'   point of the curve it belongs to, which is where the frontend's
    #'   contour trace reads it from -- the same choice
    #'   `ggplot2_contour_layer_processor` makes, so the two adapters
    #'   describe one chart alike.
    #'
    #'   No default label. `contour()` prints the deparsed argument when the
    #'   caller names nothing, and those names are gone by the time the
    #'   wrapper has recorded evaluated values -- so a guessed noun would be
    #'   worse than none, and the axis is left to the renderer's generic.
    #' @param layer_info The recorded call
    #' @return An axes payload
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(build_axes())
      }

      args <- layer_info$plot_call$args
      build_axes(
        x = build_axis_config(label = recorded_axis_label(args, "xlab")),
        y = build_axis_config(label = recorded_axis_label(args, "ylab"))
      )
    },

    #' @description The chart's own title, where the call gave one
    #' @param layer_info The recorded call
    #' @return The title, or an empty string
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }
      main <- layer_info$plot_call$args$main
      if (is.null(main)) "" else main
    },

    #' @description Address each curve by the element that drew it
    #'
    #'   gridGraphics writes one `lines` grob per curve, named
    #'   `graphics-plot-<group>-contour-<i>-<i>`, in the order
    #'   `contourLines()` returns them -- checked vertex count by vertex
    #'   count, not assumed. A `lines` grob renders as a `<polyline>`.
    #'
    #'   Withheld entirely when the count does not match what was announced.
    #'   The frontend drops a layer whose selector list disagrees with its
    #'   series count, and a partial list would hand a curve its neighbour's
    #'   element -- the defect #145 and #204 are both about.
    #' @param layer_info The recorded call
    #' @param gt The grob tree
    #' @param expected How many curves were announced
    #' @return A list of CSS selectors, one per curve
    generate_selectors = function(layer_info, gt = NULL, expected = 0) {
      if (is.null(gt) || expected == 0) {
        return(list())
      }

      group_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      names <- self$find_contour_grobs(gt, group_index)
      if (length(names) != expected) {
        return(list())
      }

      # Sorted by the curve's own number: a lexicographic sort would put
      # `-contour-10-10` before `-contour-2-2` and map every curve from the
      # tenth onward to the wrong polyline.
      numbers <- suppressWarnings(
        as.integer(sub("^.*-contour-([0-9]+)-[0-9]+$", "\\1", names))
      )
      if (anyNA(numbers)) {
        return(list())
      }
      names <- names[order(numbers)]

      lapply(names, function(name) {
        escaped <- gsub("\\.", "\\\\.", paste0(name, ".1"))
        paste0("#", escaped, " polyline")
      })
    },

    #' @description Every contour grob this layer drew
    #' @param grob The grob tree
    #' @param group_index Which plot on the device
    #' @return A character vector of grob names
    find_contour_grobs = function(grob, group_index) {
      found <- character(0)

      name <- grob$name
      if (!is.null(name)) {
        pattern <- paste0("^graphics-plot-", group_index, "-contour-[0-9]+-[0-9]+$")
        if (grepl(pattern, name)) {
          found <- c(found, name)
        }
      }

      if (!is.null(grob$children)) {
        for (child in grob$children) {
          found <- c(found, self$find_contour_grobs(child, group_index))
        }
      }

      found
    }
  )
)
