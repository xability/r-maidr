#' lattice Bar Layer Processor
#'
#' @description
#' Reads a `barchart()` panel: a `bar` layer when it has no groups, and a
#' `dodged_bar` or `stacked_bar` layer -- one series per group -- when it
#' has, as `stack = FALSE` or `TRUE` draws them.
#'
#' The values are the panel's data values, which the bars end at on the
#' value axis. They are not the bars' lengths: by default lattice draws a
#' bar from the edge of the panel rather than from zero.
#'
#' `factor ~ numeric` draws the bars horizontally, the levels running up
#' the vertical axis, and the layer says so with `orientation = "horz"`,
#' each point holding the value in `x` and the level in `y`.
#'
#' **Selectors.** An ungrouped panel draws one rectangle per row, in the
#' order of the rows, and those were sorted by level before drawing
#' ([lattice_prepare()]), so one selector pairs the bars with the levels in
#' the order a reader walks them. A grouped panel draws its bars in one grob
#' per level -- side by side when dodged, split by sign when stacked, where
#' a zero draws nothing -- so each bar is named by its own id, in a grid of
#' series by level with `null` where no bar was drawn, which the frontend
#' reads in payload order whatever the drawing order was.
#'
#' A panel whose bars overlap -- one level given two values, or a category
#' that is not a factor, which lattice turns into a shingle -- cannot be
#' read as bars, and the chart falls back to an image.
#'
#' @keywords internal
LatticeBarLayerProcessor <- R6::R6Class(
  "LatticeBarLayerProcessor",
  inherit = LatticeLayerProcessor,
  public = list(
    #' @description Read the layer
    #' @param plot The trellis object
    #' @param layout The figure's layout: title and axis labels
    #' @param built Unused for lattice
    #' @param gt The drawn chart
    #' @param grob_id Unused for lattice
    #' @param panel_id Unused for lattice
    #' @param panel_ctx The panel the layer was drawn in
    #' @param layer_info The layer: its type, role and grobs
    #' @return The layer, or NULL when its marks cannot be read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      args <- panel_ctx$args
      horizontal <- isTRUE(args[["horizontal"]])
      category <- if (horizontal) args[["y"]] else args[["x"]]
      if (!is.factor(category) || !is.null(args[["nlevels"]])) {
        return(NULL)
      }
      value <- self$axis_values(
        if (horizontal) args[["x"]] else args[["y"]],
        if (horizontal) "x" else "y",
        plot
      )

      result <- if (identical(layer_info$type, "bar")) {
        self$read_bars(category, value, horizontal, panel_ctx, layer_info)
      } else {
        self$read_grouped_bars(category, value, horizontal, panel_ctx, layer_info)
      }
      if (is.null(result)) {
        return(NULL)
      }

      c(result, list(
        type = layer_info$type,
        title = panel_ctx$title,
        axes = self$layer_axes(layout, panel_ctx, grouped = layer_info$type != "bar"),
        orientation = if (horizontal) "horz" else "vert"
      ))
    },

    #' @description Read an ungrouped panel's bars
    #' @param category The panel's category factor
    #' @param value The panel's values
    #' @param horizontal Whether the levels run up the vertical axis
    #' @param panel_ctx The panel
    #' @param layer_info The layer
    #' @return A list with `data` and `selectors`, or NULL when bars overlap
    #'   or were not drawn in level order
    read_bars = function(category, value, horizontal, panel_ctx, layer_info) {
      keep <- !is.na(category) & !is.na(value)
      code <- as.integer(category)[keep]
      value <- value[keep]
      if (anyDuplicated(code) || is.unsorted(code)) {
        return(NULL)
      }
      labels <- levels(category)[code]

      entry <- layer_info$grobs[[1]]
      list(
        data = lapply(seq_along(value), function(i) {
          if (horizontal) {
            list(x = value[i], y = labels[i])
          } else {
            list(x = labels[i], y = value[i])
          }
        }),
        selectors = lattice_grob_selector(entry$name, "rect")
      )
    },

    #' @description Read a grouped panel's bars as a grid of series by level
    #' @param category The panel's category factor
    #' @param value The panel's values
    #' @param horizontal Whether the levels run up the vertical axis
    #' @param panel_ctx The panel
    #' @param layer_info The layer
    #' @return A list with `data` and `selectors`, or NULL when two bars share
    #'   a cell
    read_grouped_bars = function(category, value, horizontal, panel_ctx, layer_info) {
      args <- panel_ctx$args
      groups <- args[["groups"]]
      if (!is.factor(groups)) {
        groups <- factor(groups)
      }
      subscripts <- args[["subscripts"]]
      group <- groups[if (is.null(subscripts)) seq_along(value) else subscripts]
      # The values as lattice drew them. On a log axis these are the logs,
      # and it is those that `panel.barchart()` splits by sign and stacks: a
      # value below 1 is drawn below the baseline, 1 is drawn nowhere, and 0
      # is drawn at -Inf, which is no rectangle at all.
      as_drawn <- as.numeric(if (horizontal) args[["x"]] else args[["y"]])

      keep <- !is.na(category) & !is.na(value) & !is.na(group)
      code <- as.integer(category)[keep]
      value <- value[keep]
      as_drawn <- as_drawn[keep]
      group <- as.integer(group)[keep]
      if (anyDuplicated(paste(code, group))) {
        return(NULL)
      }

      stacked <- identical(layer_info$type, "stacked_bar")
      axis <- if (horizontal) "y" else "x"
      grob_name <- function(part, level) {
        sprintf(
          "%s.barchart.%s.%d.rect.panel.%d.%d",
          LATTICE_PREFIX, part, level, panel_ctx$column, panel_ctx$row
        )
      }

      # Which grob, and which rectangle within it, each row was drawn as, and
      # whether that rectangle has a finite place: one that has not is not
      # exported, though it keeps its number.
      grob <- rep(NA_character_, length(value))
      position <- rep(NA_integer_, length(value))
      shown <- is.finite(as_drawn)
      for (level in unique(code)) {
        rows <- which(code == level)
        if (!stacked) {
          grob[rows] <- grob_name(axis, level)
          position[rows] <- seq_along(rows)
        } else {
          rows <- rows[sort.list(group[rows])]
          for (sign in c("pos", "neg")) {
            signed <- if (sign == "pos") rows[as_drawn[rows] > 0] else rows[as_drawn[rows] < 0]
            grob[signed] <- grob_name(sign, level)
            position[signed] <- seq_along(signed)
            # A segment starts where the one below it ended, so after an
            # infinite one none of its sign has a place either.
            shown[signed] <- cumsum(!is.finite(as_drawn[signed])) == 0L
          }
        }
      }

      drawn <- vapply(layer_info$grobs, function(e) e$name, character(1))
      if (any(!is.na(grob) & !grob %in% drawn)) {
        return(NULL)
      }

      levels_used <- sort(unique(code))
      groups_used <- sort(unique(group))
      category_labels <- levels(category)
      group_labels <- panel_ctx$group_levels %||% levels(groups)

      cell <- function(g, level) {
        i <- which(code == level & group == g)
        if (length(i) == 0L) {
          return(list(value = NA_real_, selector = NA_character_))
        }
        list(
          value = value[i],
          selector = if (is.na(grob[i]) || !shown[i]) {
            NA_character_
          } else {
            lattice_shape_selector(grob[i], position[i])
          }
        )
      }

      data <- lapply(groups_used, function(g) {
        lapply(levels_used, function(level) {
          v <- cell(g, level)$value
          if (horizontal) {
            list(x = v, y = category_labels[level], z = group_labels[g])
          } else {
            list(x = category_labels[level], y = v, z = group_labels[g])
          }
        })
      })
      selectors <- lapply(groups_used, function(g) {
        lapply(levels_used, function(level) cell(g, level)$selector)
      })

      list(data = data, selectors = selectors)
    }
  )
)
