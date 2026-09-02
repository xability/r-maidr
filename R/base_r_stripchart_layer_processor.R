#' Base R Strip Chart Layer Processor
#'
#' Reads `stripchart()` as the one-dimensional scatter it draws: every
#' observation as its own mark, laid along a value axis at its group's
#' position.
#'
#' **One layer per group.** That is the shape of the reading and it is forced
#' by the drawing rather than chosen for tidiness: measured on two groups,
#' gridGraphics exports
#'
#'     graphics-plot-1-points-1
#'     graphics-plot-1-points-2
#'
#' -- one `points` grob per group -- and `find_graphics_plot_grob()` answers
#' with the first match, so a single layer would announce every observation
#' and highlight only the first group's. It is also the reading the same chart
#' already gets in py-maidr, whose `stripplot` and `swarmplot` split into one
#' named layer per category.
#'
#' **The groups are not re-derived.** `stripchart` forms them in two places
#' and both are read rather than reimplemented:
#'
#'     stripchart.default   groups <- if (is.list(x)) x
#'                                    else if (is.numeric(x)) list(x)
#'     stripchart.formula   split(mf[[response]], mf[-response])
#'                          after stats::model.frame
#'
#' so a list keeps its own names, a bare vector is one unnamed group, and a
#' formula is split by `split()` itself.
#'
#' **A formula with no `data =` is read too**, which is worth stating because
#' the opposite is the obvious guess. A formula carries the environment it was
#' written in, and the recorded call holds the formula, so that environment is
#' still reachable when the chart is read; `model.frame()` resolves the
#' variables from it exactly as `stripchart.formula` did when it drew them.
#' Measured on `stripchart(len ~ supp)` with the variables local to a
#' function, global, and in a closure whose call had returned -- all three
#' read back the drawn groups and values. This is also what
#' `BaseRBoxplotLayerProcessor` already does with its `data = args[["data"]]`.
#'
#' What that inherits is the hazard of a late lookup: rebinding `len` between
#' the drawing and the rendering makes the payload announce the new values.
#' Measured, and filed as #254 -- it belongs to every recorded formula in this
#' package rather than to this processor, and refusing the ordinary spelling
#' to dodge it would trade a chart that reads exactly for a picture.
#'
#' **The position stays a number.** `ScatterPoint.x` is typed `number` in the
#' grammar and `ScatterTrace` does arithmetic on it, so the group's name
#' travels beside its position in `yLabel` -- or `xLabel` on a vertical chart
#' -- exactly as the ggplot2 point processor does since #178.
#'
#' **`method = "jitter"` is not a reading problem here**, and that is worth
#' saying because it is one for `geom_jitter()` (#174). A stripchart jitters
#' along the *group* axis only; the value axis is untouched, so every number
#' announced is the observation itself. What is displaced is the position
#' whose name is already carried as a label.
#'
#' @keywords internal
BaseRStripchartLayerProcessor <- R6::R6Class(
  "BaseRStripchartLayerProcessor",
  inherit = BaseRPointLayerProcessor,
  public = list(
    #' @description Emit one point layer per drawn group
    #' @param plot Unused; present for the processor interface.
    #' @param layout Unused; present for the processor interface.
    #' @param built Unused; present for the processor interface.
    #' @param gt The grob tree, for the selectors.
    #' @param grob_id Unused; present for the processor interface.
    #' @param panel_id Unused; present for the processor interface.
    #' @param panel_ctx Unused; present for the processor interface.
    #' @param layer_info Layer information with the recorded call.
    #' @return A multi-layer result, or NULL when nothing was read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      info <- if (!is.null(layer_info)) layer_info else self$layer_info
      groups <- self$extract_groups(info)
      if (!length(groups)) {
        return(NULL)
      }

      horizontal <- self$draws_horizontally(info)
      positions <- self$group_positions(info, length(groups))
      axes <- self$extract_axis_titles(info)
      title <- self$extract_main_title(info)

      layers <- lapply(seq_along(groups), function(index) {
        list(
          data = self$group_points(
            groups[[index]], names(groups)[index], positions[index], horizontal
          ),
          selectors = self$group_selectors(info, index),
          axes = axes,
          title = title,
          fill = names(groups)[index],
          type = "point"
        )
      })

      list(multi_layer = TRUE, layers = layers)
    },

    #' @description The groups `stripchart()` itself would form
    #'
    #' Read from the recorded call rather than re-derived, per the two
    #' spellings in the class docs. Returns an empty list for anything this
    #' cannot resolve exactly, which leaves the chart on the static fallback.
    #'
    #' @param layer_info Layer information with the recorded call.
    #' @return A named list of numeric vectors, one per group
    extract_groups = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(list())
      }
      args <- layer_info$plot_call$args
      handed <- resolve_xy_args(args)$x
      if (is.null(handed)) {
        return(list())
      }

      # The recorder resolves a formula bound to a name; the name itself
      # is what was handed.
      formula <- layer_info$plot_call$formula
      if (!inherits(formula, "formula")) {
        formula <- handed
      }
      groups <- if (is_formula_argument(formula)) {
        self$split_by_formula(
          formula, args[["data"]], layer_info$plot_call$formula_frame
        )
      } else if (is.list(handed)) {
        handed
      } else if (is.numeric(handed)) {
        list(handed)
      } else {
        NULL
      }
      if (!is.list(groups) || !length(groups)) {
        return(list())
      }
      if (!all(vapply(groups, is.numeric, logical(1)))) {
        return(list())
      }

      names(groups) <- self$group_names(args, groups)
      groups
    },

    #' @description Which visual axis the observations run along
    #'
    #' `stripchart()` draws horizontally unless told otherwise, which is the
    #' opposite of `boxplot()`'s default and worth reading from the call
    #' rather than assuming.
    #'
    #' @param layer_info Layer information with the recorded call.
    #' @return TRUE when the values run left to right
    draws_horizontally = function(layer_info) {
      !recorded_flag(layer_info$plot_call$args, "vertical")
    },

    #' @description Name the value axis and the group axis
    #'
    #' Overrides the inherited scatter helper, which reads the recorded `x`
    #' as a pair of coordinates and so gets a stripchart wrong in both
    #' directions at once. Measured on
    #' `stripchart(c(3.1, 4.2, 5.0, 2.2, 6.9))`, that helper hands the bare
    #' vector to `xy.coords()`, which reads it as y and indexes x over `1:5`:
    #'
    #'     announced   x  1 .. 5        y  2 .. 7
    #'     drawn       x  2.2 .. 6.9    y  one group, at 1
    #'
    #' -- the value range offered on the group axis, and a bare index on the
    #' value axis. A stripchart is one categorical axis against one measured
    #' axis, the same shape `boxplot()` and `barplot()` draw, so it is named
    #' the same way and by the same helper; `vertical = TRUE` swaps which
    #' visual axis holds which, exactly as `horizontal = TRUE` does there.
    #'
    #' No range is emitted for either axis. The group axis has none to give
    #' -- its positions are names -- and the value axis is left to the
    #' renderer's own generic, which is where every other grouped base R
    #' chart leaves it.
    #'
    #' @param layer_info Layer information with the recorded call.
    #' @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(build_axes())
      }
      base_r_categorical_axes(
        layer_info$plot_call$args,
        horizontal = self$draws_horizontally(layer_info)
      )
    },

    #' @description Split a formula's response by its grouping columns
    #'
    #' `stripchart.formula` does exactly this, through `stats::model.frame`
    #' and `split`, so both are called rather than imitated. `data` is passed
    #' through exactly as recorded -- a data frame, a plain list, or NULL --
    #' because `model.frame()` accepts all three, and NULL is its own default
    #' for "resolve from the formula's environment", which is what the
    #' drawing did. Coercing it first bought nothing: measured,
    #' `as.data.frame(NULL)` and NULL produce the same split. This is the
    #' spelling `BaseRBoxplotLayerProcessor` already uses.
    #'
    #' A one-sided formula needs no guard of its own. `stripchart(~ len)`
    #' does not draw at all -- `stripchart.formula` stops with "formula
    #' missing or incorrect" -- so it cannot be recorded, and reached
    #' directly it gives `response == 0`, whose `frame[[0]]` the `tryCatch`
    #' below already turns into the decline.
    #'
    #' @param formula The recorded formula.
    #' @param data The recorded `data` argument, or NULL.
    #' @param frame The model frame kept when the call was recorded, or NULL
    #'   for a call recorded before that existed.
    #' @return A named list of numeric vectors, or NULL
    split_by_formula = function(formula, data, frame = NULL) {
      tryCatch(
        {
          # The frame the chart was drawn from, when the recording kept one.
          # Resolving the formula here instead would read whatever its
          # variables are bound to *now*, which need not be what was drawn
          # (#254); falling back to it keeps a call recorded before this
          # existed readable.
          if (is.null(frame)) {
            frame <- stats::model.frame(formula, data = data)
          }
          response <- attr(attr(frame, "terms"), "response")
          split(frame[[response]], frame[-response])
        },
        error = function(e) NULL
      )
    },

    #' @description The names `stripchart()` writes down the group axis
    #'
    #' `group.names` first, then the list's own names, then the positions --
    #' the order `stripchart.default` resolves them in. A `group.names` of
    #' the wrong length is ignored here because it is ignored there.
    #'
    #' @param args The recorded argument list.
    #' @param groups The groups already formed.
    #' @return One name per group
    group_names = function(args, groups) {
      supplied <- if (is.list(args)) args[["group.names"]] else NULL
      if (!is.null(supplied) && length(supplied) == length(groups)) {
        return(as.character(supplied))
      }
      declared <- names(groups)
      if (!is.null(declared) && all(nzchar(declared))) {
        return(as.character(declared))
      }
      as.character(seq_along(groups))
    },

    #' @description Where along the group axis each group was drawn
    #'
    #' `at` when the caller gave one of the right length, and `1:n`
    #' otherwise, which is what `stripchart.default` falls back to.
    #'
    #' @param layer_info Layer information with the recorded call.
    #' @param count How many groups there are.
    #' @return One numeric position per group
    group_positions = function(layer_info, count) {
      at <- layer_info$plot_call$args[["at"]]
      if (is.numeric(at) && length(at) == count) {
        return(at)
      }
      seq_len(count)
    },

    #' @description One group's observations, as points
    #'
    #' The value goes on the value axis and the position on the group axis,
    #' and the group's name travels beside the position as a label rather
    #' than in place of it -- `ScatterPoint.x` is typed `number` and
    #' `ScatterTrace` does arithmetic on it (#178).
    #'
    #' @param values The group's observations.
    #' @param label The group's name.
    #' @param position Where the group sits on its axis.
    #' @param horizontal TRUE when the values run left to right.
    #' @return A list of points
    group_points = function(values, label, position, horizontal) {
      values <- values[!is.na(values)]
      lapply(values, function(value) {
        if (horizontal) {
          list(x = value, y = as.numeric(position), yLabel = label)
        } else {
          list(x = as.numeric(position), y = value, xLabel = label)
        }
      })
    },

    #' @description The marks one group was drawn into
    #'
    #' Built rather than searched for. `find_graphics_plot_grob()` answers
    #' with the first `points` grob of the plot, and a stripchart draws one
    #' per group, so a search would give every layer the first group's marks.
    #' The names are `graphics-plot-{plot}-points-{group}`, measured against a
    #' real `gridSVG` export, and every emitted selector was then resolved in
    #' Chromium against a rendering of a three-group chart: 5, 4 and 2
    #' elements, one per observation.
    #'
    #' @param layer_info Layer information with the recorded call.
    #' @param index Which group this is, from 1.
    #' @return A one-element list of selectors
    group_selectors = function(layer_info, index) {
      group_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }
      name <- paste0("graphics-plot-", group_index, "-points-", index)
      list(paste0("g#", name, "\\.1 > use"))
    }
  )
)
