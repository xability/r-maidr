#' Stacked Bar Layer Processor
#'
#' Processes stacked bar plot layers with complete logic included
#'
#' @keywords internal
Ggplot2StackedBarProcessor <- R6::R6Class(
  "Ggplot2StackedBarProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL) {
      data <- self$extract_data(plot, built, panel_id = panel_id, panel_ctx = panel_ctx)

      selectors <- self$generate_selectors(plot, gt, panel_ctx = panel_ctx)

      # Build axes including the fill legend title. A stacked bar layer only
      # exists because fill is mapped, so the title is always meaningful.
      axes <- self$extract_layer_axes(plot, layout)
      fill_label <- resolve_legend_label(
        plot,
        built = built,
        aes_names = "fill",
        layer_index = self$get_layer_index()
      )
      if (!is.null(fill_label)) {
        axes$z <- list(label = fill_label)
      }

      list(
        data = data,
        selectors = selectors,
        title = if (!is.null(layout$title)) layout$title else "",
        axes = axes
      )
    },
    needs_reordering = function() {
      TRUE
    },
    reorder_layer_data = function(data, plot) {
      columns <- self$extract_plot_columns(plot)
      fill_col <- columns$fill_col
      category_col <- columns$category_col
      if (is.null(fill_col) || is.null(category_col)) {
        return(data)
      }
      if (!(fill_col %in% names(data)) || !(category_col %in% names(data))) {
        return(data)
      }

      data <- data[order(data[[category_col]], data[[fill_col]]), , drop = FALSE]
      data
    },
    extract_plot_columns = function(plot) {
      plot_mapping <- plot$mapping

      extract_col_name <- function(quo) {
        if (is.null(quo)) {
          return(NULL)
        }
        expr <- rlang::quo_get_expr(quo)
        if (is.call(expr) && expr[[1]] == "factor") {
          as.character(expr[[2]])
        } else {
          rlang::as_label(expr)
        }
      }

      list(
        fill_col = extract_col_name(plot_mapping$fill),
        category_col = extract_col_name(plot_mapping$x)
      )
    },
    extract_data = function(plot, built = NULL, panel_id = NULL, panel_ctx = NULL) {
      original_data <- plot$data

      # Facet path: restrict the original data to this panel's facet
      # group(s) so per-panel values are extracted. facet_group_rows() is
      # NA-safe on purpose - see its comment; a bare `==` fabricated an
      # all-NA row in every panel for each missing facet value.
      if (!is.null(panel_ctx) && length(panel_ctx$facet_groups) > 0) {
        for (facet_var in names(panel_ctx$facet_groups)) {
          if (facet_var %in% names(original_data)) {
            original_data <- original_data[
              facet_group_rows(
                original_data[[facet_var]],
                panel_ctx$facet_groups[[facet_var]]
              ),
              ,
              drop = FALSE
            ]
          }
        }
      }

      plot_mapping <- plot$mapping
      layer_index <- self$get_layer_index()
      layer_mapping <- plot$layers[[layer_index]]$mapping

      x_col <- NULL
      if (!is.null(layer_mapping) && !is.null(layer_mapping$x)) {
        x_col <- rlang::as_label(layer_mapping$x)
      } else if (!is.null(plot_mapping$x)) {
        x_col <- rlang::as_label(plot_mapping$x)
      }

      fill_col <- NULL
      if (!is.null(layer_mapping) && !is.null(layer_mapping$fill)) {
        fill_col <- rlang::as_label(layer_mapping$fill)
      } else if (!is.null(plot_mapping$fill)) {
        fill_col <- rlang::as_label(plot_mapping$fill)
      }

      # Check if y mapping exists (stat="identity") or is stat-computed (stat="count")
      y_quo <- NULL
      if (!is.null(layer_mapping) && !is.null(layer_mapping$y)) {
        y_quo <- layer_mapping$y
      } else if (!is.null(plot_mapping$y)) {
        y_quo <- plot_mapping$y
      }
      has_y_mapping <- !is.null(y_quo)
      y_col <- if (has_y_mapping) rlang::as_label(y_quo) else NULL

      # `position = "fill"` rescales every category to a common height, so the
      # value the chart draws is a share and NOT the number sitting in the
      # user's data frame. That matters twice below: the stat = "identity"
      # branch reads `y` straight out of `original_data`, and the built-data
      # branch prefers `stat_count()`'s untouched `count` column. Both would
      # hand back tallies for a chart made entirely of proportions, so a
      # normalized layer has to take the geometry route and subtract.
      is_normalized <- identical(self$layer_info$type, "stacked_normalized_bar")

      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }
      built_data_layer <- built$data[[layer_index]]

      if (!is.null(panel_id) && "PANEL" %in% names(built_data_layer)) {
        built_data_layer <- built_data_layer[
          built_data_layer$PANEL == panel_id, ,
          drop = FALSE
        ]
      }

      # A row ggplot2 could not position - a missing value in a required
      # aesthetic - stays in the built data with `x`, `ymin` and `ymax` set to
      # NA rather than being deleted. It drew no rect, so it is not part of
      # this layer, and leaving it in poisons `min(x)` below: every subsequent
      # `x == min(x)` comparison answers NA and the stacking order comes back
      # empty.
      if ("x" %in% names(built_data_layer)) {
        built_data_layer <- built_data_layer[
          !is.na(built_data_layer$x), ,
          drop = FALSE
        ]
      }

      if (nrow(built_data_layer) == 0) {
        return(list())
      }

      # Determine the stacking order (bottom-to-top) from one column's
      # geometry. Read it off the FULLEST column, not the first one: a
      # `geom_col()` frame need not be a complete grid, and a fill level the
      # first column happens to lack was dropped from `stacking_order`
      # entirely, so an entire series went unemitted - never announced, never
      # highlighted (issue #94). Ties resolve to the smallest x, which is the
      # first column, so a complete grid orders exactly as it always did.
      rows_per_column <- table(built_data_layer$x)
      fullest_x <- names(rows_per_column)[which.max(rows_per_column)]
      first_bar_data <- built_data_layer[
        as.character(built_data_layer$x) == fullest_x, ,
        drop = FALSE
      ]
      first_bar_data <- first_bar_data[order(first_bar_data$ymin), ]

      # The stat = "identity" branch reads the values out of the user's own
      # data frame and can only pair them with the drawn rects row by row, so
      # it is only usable while the two frames still have the same number of
      # rows. `setNames()` does not object to a mismatch - it PADS the names
      # with NA - so a frame ggplot2 partly discarded (one missing `y` is
      # enough) used to yield a colour lookup full of NA names and die later
      # in `order(NULL)`. When they no longer line up, read the built data
      # instead: it is what was actually drawn.
      rows_aligned <- nrow(original_data) == nrow(built_data_layer)

      if (!is_normalized && rows_aligned &&
          has_y_mapping && !is.null(y_col) && y_col %in% names(original_data) &&
          !is.null(fill_col) && fill_col %in% names(original_data) &&
          !is.null(x_col) && x_col %in% names(original_data)) {
        color_to_fill <- setNames(
          as.character(original_data[[fill_col]]),
          built_data_layer$fill
        )
        stacking_order <- unique(color_to_fill[first_bar_data$fill])

        # Read values from original data (original approach)
        fill_groups <- split(original_data, original_data[[fill_col]])

        # split() drops NA, so a fill level this lookup cannot resolve has no
        # rows to read and must not reach `order(NULL)`.
        stacking_order <- stacking_order[
          !is.na(stacking_order) & stacking_order %in% names(fill_groups)
        ]

        # Only reachable when no single column holds every fill level, so the
        # geometry above cannot place the stragglers. Appending them still
        # beats dropping them: a series that is absent from the payload can
        # never be announced at all.
        stacking_order <- c(
          stacking_order,
          setdiff(names(fill_groups), stacking_order)
        )

        # Every series gets one entry per x category, in the layer's x order.
        x_levels <- as.character(sort(unique(original_data[[x_col]])))

        # Two rows in the same (x, fill) cell stack into two rects and a grid
        # has nowhere to put the second value, so that degenerate frame keeps
        # the row-by-row reading rather than losing a row to the grid.
        #
        # A real `NA` in either aesthetic takes the same exit, for the reason
        # spelled out in the dodged processor: `sort()` leaves it out of
        # `x_levels`, so the grid would drop that row without ever reporting
        # it missing, and `paste()` hides it from the duplicate test by
        # stringifying it to "NA". Keeping the row-by-row path leaves that
        # case reading exactly as it did before this change.
        cell_keys <- paste(
          as.character(original_data[[x_col]]),
          as.character(original_data[[fill_col]]),
          sep = "\r"
        )
        griddable <- anyDuplicated(cell_keys) == 0L &&
          !anyNA(original_data[[x_col]]) && !anyNA(original_data[[fill_col]])

        lapply(stacking_order, function(fill_value) {
          group_data <- fill_groups[[as.character(fill_value)]]
          group_data <- group_data[order(group_data[[x_col]]), ]

          if (!griddable) {
            return(lapply(seq_len(nrow(group_data)), function(i) {
              list(
                x = as.character(group_data[[x_col]][i]),
                y = group_data[[y_col]][i],
                z = as.character(fill_value)
              )
            }))
          }

          # `NA` here serializes to JSON `null`, which the frontend reads as 0
          # into `barValues` - hitting the `=== 0` sentinel so the cell claims
          # no rect - while its formatter announces the raw `null` as
          # "missing". See the long note in the dodged processor: the absent
          # cell has to occupy a slot for the highlight to stay on the right
          # bar, but it must not be announced as the value zero.
          values <- setNames(
            group_data[[y_col]],
            as.character(group_data[[x_col]])
          )

          lapply(x_levels, function(x_name) {
            list(
              x = x_name,
              y = if (x_name %in% names(values)) values[[x_name]] else NA_real_,
              z = as.character(fill_value)
            )
          })
        })
      } else {
        # stat="count" or other stat-computed: use built data
        # Get x-axis scale labels for readable category names
        x_labels <- NULL
        panel_params <- built$layout$panel_params[[1]]
        if (!is.null(panel_params$x) && !is.null(panel_params$x$get_labels)) {
          x_labels <- panel_params$x$get_labels()
        } else if (!is.null(panel_params$x.labels)) {
          x_labels <- panel_params$x.labels
        }
        all_x_positions <- sort(unique(built_data_layer$x))

        # Build color-to-label mapping using the fill scale
        fill_color_to_label <- NULL
        for (sc in built$plot$scales$scales) {
          if ("fill" %in% sc$aesthetics && !is.null(sc$map) &&
              is.function(sc$map) && !is.null(sc$range$range)) {
            fill_labels <- sc$get_labels()
            mapped_colors <- sc$map(sc$range$range)
            if (length(fill_labels) == length(mapped_colors)) {
              fill_color_to_label <- setNames(fill_labels, mapped_colors)
            }
            break
          }
        }

        # Determine global stacking order from built data.
        # ggplot2 renders SVG rects top-first within each column (descending
        # ymin). maidr.js default groupDirection is "reverse": for each column
        # it iterates data rows from last to first, mapping to DOM rects in
        # order. So data[last] maps to DOM rect[0] (top segment) and data[0]
        # maps to the last DOM rect (bottom segment).
        # Therefore: data[0] = bottom fill level, data[last] = top fill level.
        # Verified against the rendered SVG: gridSVG wraps the plot in a
        # `translate(0, height) scale(1, -1)` group, so a rect's `y`
        # attribute grows with its data value. Within one column the rect
        # with the largest `y` (the top segment) is emitted first, and it is
        # the last data series that receives it.
        fill_max_y <- tapply(built_data_layer$ymax, built_data_layer$fill, max)
        ordered_colors <- names(sort(fill_max_y, decreasing = FALSE))

        # Build full grid: every fill group has an entry for EVERY x-category.
        # maidr.js requires rectangular data (same # of columns per row).
        # Missing segments get y = 0; maidr.js skips zero-value DOM matching.
        lapply(ordered_colors, function(hex_color) {
          group_rows <- built_data_layer[built_data_layer$fill == hex_color, ]

          fill_label <- if (!is.null(fill_color_to_label) &&
                           hex_color %in% names(fill_color_to_label)) {
            fill_color_to_label[[hex_color]]
          } else {
            hex_color
          }

          # Create a lookup of x_pos -> value for this fill color.
          #
          # `count` is the raw tally `stat_count()` computed, and it is the
          # right value for a stacked bar but the wrong one for a filled bar.
          # `position = "fill"` rescales each category to a common height, so
          # what the chart actually draws is every segment's *share* — while
          # `count` keeps the untouched tally alongside it. Reading `count`
          # there would announce counts for a chart made entirely of
          # proportions, and the running total maidr.js derives would come out
          # as the category total instead of the 1 the bar is drawn to.
          # `geom_col()` has no `count` column at all and already falls
          # through to the same subtraction once it reaches here.
          vals <- setNames(
            if (!is_normalized && "count" %in% names(group_rows)) {
              group_rows$count
            } else {
              group_rows$ymax - group_rows$ymin
            },
            group_rows$x
          )

          lapply(all_x_positions, function(x_pos) {
            x_name <- if (!is.null(x_labels) && x_pos >= 1 &&
                         x_pos <= length(x_labels)) {
              x_labels[x_pos]
            } else {
              as.character(x_pos)
            }
            y_val <- if (as.character(x_pos) %in% names(vals)) {
              vals[[as.character(x_pos)]]
            } else {
              0
            }
            list(
              x = as.character(x_name),
              y = y_val,
              z = as.character(fill_label)
            )
          })
        })
      }
    },
    # ONE flat CSS selector matching every rect in the layer is the contract
    # maidr.js expects for segmented bars. It is deliberate, not an oversight:
    # do not "fix" it by emitting one selector per series.
    #
    # In the bundled frontend (inst/htmlwidgets/lib/maidr-*/maidr.js) the
    # stacked, dodged and normalized trace types are all built by the same
    # class:
    #
    #   case DODGED: case NORMALIZED: case STACKED: return new <Segmented>(layer)
    #
    # Its constructor runs `this.highlightValues = this.mapToSvgElements(
    # layer.selectors)`, and `selectAllElements` is just
    # `Array.from(document.querySelectorAll(sel))` - one flat node list in SVG
    # document order. The class then RE-GROUPS that list itself instead of
    # zipping it against the flattened payload (de-minified, rect branch):
    #
    #   for (let col = 0, k = 0; col < barValues[0].length; col++)
    #     if (domMapping?.groupDirection === "forward")
    #       for (let s = 0; s < barValues.length; s++)      out[s][col] = nodes[k++];
    #     else
    #       for (let s = barValues.length - 1; s >= 0; s--) out[s][col] = nodes[k++];
    #
    # So the DOM walk is X-MAJOR (one whole column at a time) while `data`
    # stays SERIES-MAJOR, and because this layer emits no `domMapping` the
    # per-column direction defaults to "reverse": the first rect of a column
    # is handed to the LAST data series, the last rect to the first series.
    #
    # That is why flattening `data` and lining it up against document order
    # looks wrong - the frontend never does that. Concretely, for x = a,b,c
    # and fills u = 10,20,30 / v = 55,65,75, the emitted flattening is
    # 55,65,75,10,20,30 while the rects come out 10,55,20,65,30,75; the
    # regrouping above reunites data[0] = v with the v rects.
    #
    # Pinned by tests/testthat/test-segmented-bar-selector-contract.R.
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL) {
      if (is.null(gt)) {
        return(list())
      }

      find_rect_grobs <- function(grob) {
        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          return(grob$name)
        }

        if ("children" %in% names(grob)) {
          for (child in grob$children) {
            result <- find_rect_grobs(child)
            if (!is.null(result)) {
              return(result)
            }
          }
        }
        NULL
      }

      rect_grob <- NULL

      if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        # Facet / patchwork path: scope the search to this panel's grob
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (!is.null(panel_grob)) {
          rect_grob <- find_rect_grobs(panel_grob)
        }
      } else if ("grobs" %in% names(gt)) {
        for (grob in gt$grobs) {
          rect_grob <- find_rect_grobs(grob)
          if (!is.null(rect_grob)) break
        }
      }

      # No rect grob means this layer drew no segments here: an empty facet
      # level, a zero-row layer, a coord that renders no rects. The layer
      # INDEX is not the grob id - every `geom_rect.rect.N` id carries
      # grid's session-wide grob counter - so the guess is right only by
      # coincidence, and when it does land it lands on ANOTHER panel's
      # segments, which highlights the wrong marks while the payload still
      # looks healthy. The caller can tell an empty selector list apart
      # from a wrong one, a user cannot.
      if (is.null(rect_grob)) {
        return(list())
      }

      layer_id <- gsub("geom_rect\\.rect\\.", "", rect_grob)
      grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
      escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)

      list(paste0("#", escaped_grob_id, " rect"))
    }
  )
)
