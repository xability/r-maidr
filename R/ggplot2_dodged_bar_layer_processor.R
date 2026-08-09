#' Dodged Bar Layer Processor
#'
#' Processes dodged bar plot layers with complete logic included
#'
#' @keywords internal
Ggplot2DodgedBarLayerProcessor <- R6::R6Class(
  "Ggplot2DodgedBarLayerProcessor",
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
      data <- self$extract_data(plot, built, panel_ctx = panel_ctx)

      # `extract_data()` is the only place that knows which stat produced the
      # bars, and the two stats need opposite per-column DOM walks (see the
      # note above `generate_selectors()`), so it reports the walk it needs
      # back through an attribute rather than making `process()` re-evaluate
      # the aesthetics to work it out a second time.
      dom_mapping <- attr(data, "dom_mapping", exact = TRUE)
      attr(data, "dom_mapping") <- NULL

      selectors <- self$generate_selectors(plot, gt, panel_ctx = panel_ctx)

      # Build axes including the fill legend title. A dodged bar layer only
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

      result <- list(
        data = data,
        selectors = selectors,
        title = if (!is.null(layout$title)) layout$title else "",
        axes = axes
      )
      if (!is.null(dom_mapping)) {
        result$domMapping <- dom_mapping
      }
      result
    },
    needs_reordering = function() {
      TRUE
    },
    #' @description Resolve this layer's x/y/fill aesthetics to VALUES.
    #'   `rlang::as_label()` produces a display string, which doubles as a
    #'   column name only for bare-column mappings. Evaluating the quosure
    #'   against the data also covers expression aesthetics such as
    #'   `aes(fill = factor(cyl))`, which are idiomatic ggplot2 and which
    #'   the column-name treatment turned into `data[["factor(cyl)"]]`,
    #'   i.e. NULL.
    #' @param plot A ggplot2 object
    #' @param data Data frame the aesthetics are evaluated against
    #' @return List with `x`, `y` and `fill` vectors (any may be NULL)
    resolve_aes_values = function(plot, data) {
      layer_index <- self$get_layer_index()
      layer_mapping <- if (length(plot$layers) >= layer_index) {
        plot$layers[[layer_index]]$mapping
      } else {
        NULL
      }
      plot_mapping <- plot$mapping

      # `[[` avoids the partial matching `$x` would do against xmin/xmax
      quo_for <- function(name) {
        quo <- if (is.null(layer_mapping)) NULL else layer_mapping[[name]]
        if (is.null(quo) && !is.null(plot_mapping)) quo <- plot_mapping[[name]]
        quo
      }

      evaluate <- function(quo) {
        if (is.null(quo)) {
          return(NULL)
        }
        values <- tryCatch(
          rlang::eval_tidy(quo, data = data),
          error = function(e) NULL
        )
        if (is.null(values)) {
          return(NULL)
        }
        # A constant aesthetic (aes(fill = "red")) recycles to every row
        if (length(values) == 1L && nrow(data) > 1L) {
          values <- rep(values, nrow(data))
        }
        if (length(values) != nrow(data)) {
          return(NULL)
        }
        values
      }

      list(
        x = evaluate(quo_for("x")),
        y = evaluate(quo_for("y")),
        fill = evaluate(quo_for("fill"))
      )
    },
    #' @description Order the distinct values of an aesthetic the way ggplot2
    #'   lays them out, so the emitted columns line up with the drawn ones.
    #'   A factor follows its own level order, minus the levels nothing was
    #'   drawn for; anything else sorts in its own type's order. Sorting the
    #'   values AS TEXT, which is what this used to do, reordered the columns
    #'   twice over: against a factor whose levels are not alphabetical, and
    #'   against a number, where it puts 10 before 2.
    #' @param values A vector of aesthetic values
    #' @return Character vector of the observed levels, in drawn order
    discrete_level_order = function(values) {
      if (is.factor(values)) {
        observed <- unique(as.character(values))
        return(levels(values)[levels(values) %in% observed])
      }
      as.character(sort(unique(values)))
    },
    reorder_layer_data = function(data, plot) {
      aes_values <- self$resolve_aes_values(plot, data)
      x_values <- aes_values$x
      fill_values <- aes_values$fill

      if (is.null(x_values) || is.null(fill_values)) {
        return(data)
      }

      x_ordered <- factor(x_values, levels = sort(unique(x_values)))
      fill_ordered <- factor(fill_values, levels = rev(sort(unique(fill_values))))

      data[order(x_ordered, fill_ordered), , drop = FALSE]
    },
    extract_data = function(plot, built = NULL, panel_ctx = NULL) {
      if (!inherits(plot, "ggplot")) {
        stop("Input must be a ggplot object.")
      }

      source_data <- plot$data

      # Facet path: restrict to this panel's facet group(s). facet_group_rows()
      # is NA-safe on purpose - see its comment. A bare `==` answers NA for
      # every row whose facet value is missing, and `[` turns an NA index into
      # a fabricated all-NA row, so the panel ggplot2 draws for the missing
      # value came back holding nothing this processor could use and the layer
      # was dropped entirely (#102).
      if (!is.null(panel_ctx) && length(panel_ctx$facet_groups) > 0) {
        for (facet_var in names(panel_ctx$facet_groups)) {
          if (facet_var %in% names(source_data)) {
            source_data <- source_data[
              facet_group_rows(
                source_data[[facet_var]],
                panel_ctx$facet_groups[[facet_var]]
              ),
              ,
              drop = FALSE
            ]
          }
        }
      }

      aes_values <- self$resolve_aes_values(plot, source_data)
      x_values <- aes_values$x
      y_values <- aes_values$y
      fill_values <- aes_values$fill

      if (is.null(x_values) || is.null(fill_values)) {
        stop("Could not determine required aesthetic mappings")
      }

      # stat = "count" (no y aesthetic): one bar per (x, fill) combination
      # with the row count as its value
      if (is.null(y_values)) {
        x_levels <- self$discrete_level_order(x_values)
        fill_levels <- self$discrete_level_order(fill_values)
        count_table <- table(
          factor(as.character(x_values), levels = x_levels),
          factor(as.character(fill_values), levels = fill_levels)
        )

        # Emit the FULL cartesian product, scoring absent (x, fill) cells 0,
        # so every series has one entry per x category (issue #80).
        #
        # Dropping the absent cells kept the payload as short as the rect
        # list, but it made the series RAGGED - five, four and three entries
        # for `mpg` class x drv - and raggedness is what the frontend cannot
        # survive. Its `mapToSvgElements` walks
        # `barValues[0].length * barValues.length` slots column by column, so
        # a 5x3 payload consumed 15 slots against 12 rects: the node cursor
        # ran off the end and every bar after the first gap highlighted its
        # neighbour. Ragged series also destroy positional correspondence -
        # index 3 meant `pickup` in one series and `minivan` in the next -
        # which is the one thing a grouped bar chart exists to provide.
        #
        # The frontend is built for this: when it holds fewer rects than
        # slots it treats a barValue of exactly 0 as "no rect here", consumes
        # no node for it and hands the cell an empty highlight element. So a
        # zero cell announces its value and highlights nothing, which is the
        # honest rendering of a bar that is not on screen.
        #
        # Announcing "0" is also the truthful reading of THIS stat. A dodged
        # `stat = "count"` layer is a cross-tabulation, and a cell it never
        # drew is a cell whose count is genuinely zero, not one whose value is
        # unknown - "no four-wheel-drive two-seaters" is a fact about the data
        # that a sighted reader takes from the gap in the column. So the zero
        # here is a DATUM, and it stays one.
        #
        # The stat = "identity" branch below also emits a full grid, because
        # the frontend needs the same rectangular shape either way, but it
        # fills its absent cells with `NA` rather than 0: there a missing row
        # means the caller supplied no value, and a zero would invent data.
        # See the note there for how the frontend tells the two apart.
        series <- lapply(fill_levels, function(fill_name) {
          lapply(x_levels, function(x_name) {
            list(
              x = x_name,
              y = as.numeric(count_table[x_name, fill_name]),
              z = fill_name
            )
          })
        })

        # `stat_count()` re-derives its own rows, so `reorder_layer_data()`
        # cannot steer the draw order the way it does for stat = "identity":
        # ggplot2 lays the rects out x-major with the fill levels ASCENDING
        # inside each column, which is the order the series above are emitted
        # in. That is the frontend's "forward" walk, not its default reverse
        # one, so this branch has to say so.
        attr(series, "dom_mapping") <- list(groupDirection = "forward")
        return(series)
      }

      # stat = "identity" (geom_col): one bar per row the caller supplied.
      #
      # A `geom_col()` frame is routinely NOT a complete grid - pre-aggregated
      # tidy data is the reason the geom exists - and emitting only the rows
      # that are there made the series RAGGED, which is the one shape the
      # frontend cannot describe (issue #94). Its `mapToSvgElements` walks
      # `barValues[0].length` columns times `barValues.length` series against a
      # single flat node list, so a 3/2 payload cross-mapped the announcement
      # to a bar in a different category AND a different fill group.
      #
      # So emit the full cartesian product, exactly as the `stat = "count"`
      # branch above does. The cells the caller left out carry `NA`, which
      # `set_maidr_data_attr()` serializes to JSON `null`, and that is a real
      # value in this protocol rather than a stand-in for one:
      #
      #   * The frontend reads `Number(point.y)` into `barValues`, and
      #     `Number(null)` is 0 - so the absent cell hits the `=== 0` sentinel
      #     in the rect branch, consumes no node and is handed an empty
      #     highlight, which keeps every other cell on its own bar.
      #   * It reads the RAW point for the announcement, where its formatter
      #     has a dedicated missing branch (`wrapFormat`: `o == null || NaN`
      #     -> `missingText`, default "missing"). The reader hears
      #     "n is missing", not the value 0.
      #
      # That is the distinction #87 asked for: `0` stays the honest reading of
      # an absent `stat = "count"` cell, which genuinely counted nothing, while
      # a row the caller never supplied reads as missing instead of inventing a
      # zero. Verified end to end in Chromium against the bundled build.
      x_levels <- self$discrete_level_order(x_values)
      fill_levels <- self$discrete_level_order(fill_values)
      cell_keys <- paste(
        as.character(x_values),
        as.character(fill_values),
        sep = "\r"
      )

      # Two rows sharing an (x, fill) cell draw two rects on top of each other,
      # and a grid has nowhere to put the second value. That is a degenerate
      # chart rather than an incomplete one, so leave it on the row-by-row path
      # rather than silently dropping a row to force it into a grid.
      #
      # A real `NA` in either aesthetic takes the same exit. `sort()` drops it
      # from the level order, so the grid has no column or series to hold that
      # row and would omit it entirely - `paste()` stringifies it to "NA", so
      # the duplicate test above never notices. ggplot2 itself draws the row
      # as its own grey "NA" category, so neither the row-by-row reading nor
      # the grid matches the picture; this only keeps that case exactly as it
      # was, rather than trading its wrong answer for a quieter one.
      griddable <- anyDuplicated(cell_keys) == 0L &&
        !anyNA(x_values) && !anyNA(fill_values)

      if (griddable) {
        values_by_cell <- setNames(as.numeric(y_values), cell_keys)

        return(lapply(fill_levels, function(fill_name) {
          lapply(x_levels, function(x_name) {
            key <- paste(x_name, fill_name, sep = "\r")
            list(
              x = x_name,
              y = if (key %in% names(values_by_cell)) {
                values_by_cell[[key]]
              } else {
                NA_real_
              },
              z = fill_name
            )
          })
        }))
      }

      # Split row INDICES rather than the data frame itself: indexing the
      # evaluated aesthetic vectors sidesteps the tibble trap where
      # `df[i, col]` returns a 1x1 tibble that serializes as a nested array
      # instead of a number.
      rows_by_fill <- split(seq_along(fill_values), fill_values)

      lapply(names(rows_by_fill), function(fill_name) {
        rows <- rows_by_fill[[fill_name]]
        rows <- rows[order(x_values[rows])]

        lapply(rows, function(i) {
          list(
            x = as.character(x_values[i]),
            y = as.numeric(y_values[i]),
            z = as.character(fill_values[i])
          )
        })
      })
    },
    # ONE flat CSS selector matching every rect in the layer is the contract
    # maidr.js expects for segmented bars. It is deliberate, not an oversight:
    # do not "fix" it by emitting one selector per series.
    #
    # In the bundled frontend (inst/htmlwidgets/lib/maidr-*/maidr.js) the
    # dodged, stacked and normalized trace types are all built by the same
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
    #   const slots  = barValues.reduce((n, row) => n + row.length, 0);
    #   const sparse = nodes.length < slots;
    #   for (let col = 0, k = 0; col < barValues[0].length; col++) {
    #     // series runs 0..n-1 when domMapping.groupDirection is "forward",
    #     // and n-1..0 otherwise
    #     for (const s of series)
    #       (sparse && barValues[s][col] === 0) || k >= nodes.length
    #         ? out[s].push(emptyElement())
    #         : out[s].push(nodes[k++]);
    #   }
    #
    # Three things follow, and this layer depends on all of them.
    #
    # 1. The DOM walk is X-MAJOR (one whole column at a time) while `data`
    #    stays SERIES-MAJOR. Flattening `data` and lining it up against
    #    document order therefore looks wrong; the frontend never does that.
    #
    # 2. `barValues` must be RECTANGULAR. The walk is bounded by
    #    `barValues[0].length` columns times `barValues.length` series, so a
    #    ragged payload sends the node cursor off the end of the list and
    #    shifts every assignment after the first short column. See the
    #    zero-filling in `extract_data()` (issue #80).
    #
    # 3. A cell whose value is exactly 0 consumes no node WHEN the layer has
    #    fewer rects than slots. That is what lets a rectangular payload
    #    describe a chart with structurally missing bars.
    #
    # The per-column direction differs by stat, so the two branches of
    # `extract_data()` disagree about `domMapping`:
    #
    # * stat = "identity" emits none, taking the default REVERSE walk - the
    #   first rect of a column goes to the LAST series.
    #   `reorder_layer_data()` above is what makes that hold: it sorts the
    #   plot data by x ascending and fill DESCENDING, so ggplot2 draws each
    #   column's rects right-to-left. For x = a,b,c and fills u = 10,20,30 /
    #   v = 55,65,75 the emitted flattening is 10,20,30,55,65,75 while the
    #   rects come out 55,10,65,20,75,30; the regrouping reunites
    #   data[0] = u with the u rects.
    #
    # * stat = "count" emits `groupDirection = "forward"`. `stat_count()`
    #   builds its own rows, so the reordering above cannot reach it and
    #   ggplot2 draws each column's fills left-to-right, ASCENDING.
    #
    # Pinned by test-segmented-bar-selector-contract.R (stat = "identity")
    # and by test-dodged-bar-count-grid.R (stat = "count").
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL) {
      if (is.null(gt)) {
        gt <- ggplot2::ggplotGrob(plot)
      }

      # An unresolvable panel and a panel with no rects are the same
      # answer: this layer has no marks to address here. The layer INDEX is
      # not the grob id - every `geom_rect.rect.N` id carries grid's
      # session-wide grob counter - so the guess is right only by
      # coincidence, and when it does land it lands on ANOTHER panel's
      # segments, which highlights the wrong marks while the payload still
      # looks healthy. The caller can tell an empty selector list apart
      # from a wrong one, a user cannot.
      panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
      if (is.null(panel_grob)) {
        return(list())
      }

      find_rect_names <- function(grob) {
        names <- character(0)

        if (!is.null(grob$name) && grepl("geom_rect\\.rect", grob$name)) {
          names <- c(names, grob$name)
        }

        if (inherits(grob, "gList")) {
          for (i in seq_along(grob)) {
            names <- c(names, find_rect_names(grob[[i]]))
          }
        }

        if (inherits(grob, "gTree")) {
          for (i in seq_along(grob$children)) {
            names <- c(names, find_rect_names(grob$children[[i]]))
          }
        }

        names
      }

      rect_names <- find_rect_names(panel_grob)
      if (length(rect_names) == 0) {
        return(list())
      }

      layer_id <- gsub("geom_rect\\.rect\\.", "", rect_names[1])
      grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
      escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)

      list(paste0("#", escaped_grob_id, " rect"))
    }
  )
)
