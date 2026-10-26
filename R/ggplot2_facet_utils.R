#' Facet Processing Utilities
#'
#' Utility functions for processing faceted ggplot2 plots.
#' These functions handle panel extraction, processing, and grid organization
#' for faceted plots in a unified way.
#'
#' @noRd
NULL

#' Process a faceted plot and return organized subplot data
#' @param plot The faceted ggplot2 object
#' @param layout Layout information
#' @param built Built plot data
#' @param gtable Gtable object
#' @param format_config Optional format configuration from maidr label functions
#' @return List with organized subplot data in 2D grid format
process_faceted_plot_data <- function(plot, layout, built, gtable, format_config = NULL) {
  panel_layout <- built$layout$layout

  subplots <- list()
  for (i in seq_len(nrow(panel_layout))) {
    panel_info <- panel_layout[i, ]

    panel_data <- built$data[[1]][built$data[[1]]$PANEL == panel_info$PANEL, ]

    facet_groups <- get_facet_groups(panel_info, built)

    # The gtable panel drawn at this panel's place in the grid
    gtable_panel_name <- map_visual_to_dom_panel(panel_info, gtable)

    subplot_data <- process_facet_panel(
      plot,
      panel_info,
      panel_data,
      facet_groups,
      gtable_panel_name,
      built,
      layout,
      gtable,
      format_config
    )
    subplots[[i]] <- subplot_data
  }

  # Organize into 2D grid structure
  organize_facet_grid(subplots, panel_layout)
}

#' Get facet group information for a panel
#' @param panel_info Panel information from layout
#' @param built Built plot data
#' @return List of facet group information
get_facet_groups <- function(panel_info, built) {
  facet_groups <- list()

  if (!is.null(built$layout$facet)) {
    # facet_wrap stores variables in params$facets; facet_grid splits
    # them across params$rows AND params$cols - both must be included
    facet_vars <- names(built$layout$facet$params$facets)
    if (length(facet_vars) == 0) {
      facet_vars <- c(
        names(built$layout$facet$params$rows),
        names(built$layout$facet$params$cols)
      )
    }

    for (var in facet_vars) {
      if (var %in% names(panel_info)) {
        facet_groups[[var]] <- as.character(panel_info[[var]])
      }
    }
  }

  facet_groups
}

#' Rows of a layer's own data that belong to one facet panel
#'
#' The obvious `values == group` is wrong the moment the facet column holds
#' an `NA`: `==` answers `NA` for that row, and `[` turns an `NA` index into
#' a fabricated all-`NA` row. One missing facet value therefore injects junk
#' rows into EVERY panel's subset, not only the panel the `NA` belongs to.
#'
#' `NA` is a panel, not an absence. ggplot2 lays out a real panel for it and
#' draws "NA" on its strip, so the matching rows have to be selected for that
#' panel rather than dropped everywhere. `%in%` handles the ordinary levels
#' (it scores an `NA` value as `FALSE` instead of `NA`), and `is.na()` picks
#' out the `NA` panel's own rows. A facet column that literally contains the
#' string "NA" stays distinct from a missing value: `as.character()` leaves
#' the former as `"NA"` and the latter as `NA_character_`.
#'
#' @param values The facet column of the layer's data
#' @param group The panel's own facet group, possibly `NA`
#' @return A logical vector, one element per row, never `NA`
#' @keywords internal
facet_group_rows <- function(values, group) {
  values <- as.character(values)
  group <- as.character(group)

  # `get_facet_groups()` builds each entry from a one-row slice of the layout,
  # so the only reachable shape today is a length-1 group. The length test is
  # defensive: a zero-length group would make `%in%` answer FALSE for every
  # row, and a longer one would quietly widen the panel to a set of levels,
  # neither of which is a panel identity. Both degrade to "the missing panel"
  # instead, which is the only other thing a panel can be.
  if (length(group) != 1L || is.na(group)) {
    return(is.na(values))
  }

  values %in% group
}

#' Process a single facet panel
#' @param plot The original plot
#' @param panel_info Panel information
#' @param panel_data Panel-specific data
#' @param facet_groups Facet group information
#' @param gtable_panel_name Gtable panel name
#' @param built Built plot data
#' @param layout Layout information
#' @param gtable Gtable object
#' @param format_config Optional format configuration from maidr label functions
#' @return Processed panel data
process_facet_panel <- function(
    plot,
    panel_info,
    panel_data,
    facet_groups,
    gtable_panel_name,
    built,
    layout,
    gtable,
    format_config = NULL) {
  layer_results <- list()

  for (layer_idx in seq_along(plot$layers)) {
    layer <- plot$layers[[layer_idx]]

    registry <- get_global_registry()
    system_name <- "ggplot2"
    factory <- registry$get_processor_factory(system_name)
    adapter <- registry$get_adapter(system_name)

    layer_type <- adapter$detect_layer_type(layer, plot)
    # The detected type, as the single-plot path passes it. Processors read
    # `layer_info$type` to tell their variants apart -- the stacked bar
    # reader announces proportions only for `stacked_normalized_bar` -- and
    # the geom class this used to carry matched none of them, so a faceted
    # `position = "fill"` chart announced counts.
    layer_info <- list(index = layer_idx, type = layer_type)

    # A layer tagged "skip" is drawn but carries no observations -- a
    # reference line, a text annotation, a candlestick's wick folded into its
    # body. `create_processor()` has no "skip" arm, so without this it falls
    # to the switch default and builds an *unknown* processor, whose result
    # then wins the "first layer that produced a result" scan below.
    #
    # Measured on a faceted scatter with the reference line added first::
    #
    #     geom_hline() + geom_point() + facet_wrap(~f)   layers [skip skip]
    #     geom_point() + geom_hline() + facet_wrap(~f)   layers [point point]
    #
    # Same chart, same data, typed by which layer happened to be written
    # first. The patchwork paths already guard this (`ggplot2_patchwork_utils.R`),
    # as does `create_layer_processors()`; the facet path did not (#176).
    if (identical(layer_type, "skip")) {
      next
    }

    processor <- factory$create_processor(layer_type, layer_info)

    if (!is.null(processor)) {
      panel_name <- if (!is.null(gtable_panel_name)) {
        gtable_panel_name
      } else {
        paste0("panel-", panel_info$ROW, "-", panel_info$COL)
      }
      panel_ctx <- list(
        panel_name = panel_name,
        row = panel_info$ROW,
        col = panel_info$COL,
        panel_id = panel_info$PANEL,
        layer_index = layer_idx,
        facet_groups = facet_groups
      )
      result <- processor$process(
        plot,
        layout,
        built,
        gtable,
        grob_id = NULL,
        panel_id = panel_info$PANEL,
        panel_ctx = panel_ctx
      )

      layer_results[[layer_idx]] <- result
    }
  }

  combined_data <- combine_facet_layer_data(layer_results)
  combined_selectors <- combine_facet_layer_selectors(layer_results)

  subplot_id <- paste0("maidr-subplot-", generate_unique_id(), "-", panel_info$PANEL)

  layers <- list()
  if (length(combined_data) > 0) {
    layer_id <- paste0("maidr-layer-", generate_unique_id(), "-", panel_info$PANEL)

    # Determine layer type from the first layer that actually produced a
    # result (typing everything from plot$layers[[1]] mislabels
    # multi-layer faceted plots whose first layer was skipped)
    layer_type <- NULL
    for (result in layer_results) {
      if (!is.null(result) && !is.null(result$type)) {
        layer_type <- result$type
        break
      }
    }
    if (is.null(layer_type)) {
      registry <- get_global_registry()
      system_name <- "ggplot2"
      adapter <- registry$get_adapter(system_name)
      first_processed <- which(!vapply(layer_results, is.null, logical(1)))
      source_layer <- if (length(first_processed) > 0) {
        plot$layers[[first_processed[1]]]
      } else {
        plot$layers[[1]]
      }
      layer_type <- adapter$detect_layer_type(source_layer, plot)
    }

    facet_title <- ""
    if (length(facet_groups) > 0) {
      facet_title <- paste(facet_groups, collapse = " & ")
    }

    # Prefer the axes the layer processors already resolved. They start from
    # the BUILT plot's labels, which is where ggplot2 records defaults derived
    # from aesthetics and stats -- an unbuilt `plot$labels` holds only explicit
    # `labs()` overrides, so reading it drops "count" for geom_bar() and the
    # mapped column name for everything else. They also carry the legend title
    # as z for grouped layers, which a rebuilt {x, y} pair cannot express.
    #
    # The leading layer wins for a key it defines -- x and y are the panel's
    # shared scales, so every layer agrees on them. A key it does NOT define
    # is filled from a later layer, because the panel collapses all of them
    # into one payload entry. z is the case that matters: an ungrouped first
    # layer carries no legend title while a later grouped layer still writes
    # z VALUES into the shared data, and a z value with no label is announced
    # as the generic word "Group".
    axes <- NULL
    for (result in layer_results) {
      if (is.null(result) || length(result$axes) == 0) {
        next
      }
      if (is.null(axes)) {
        axes <- result$axes
        next
      }
      for (key in setdiff(names(result$axes), names(axes))) {
        axes[[key]] <- result$axes[[key]]
      }
    }
    if (is.null(axes)) {
      axes <- build_axes(
        x = if (!is.null(plot$labels$x)) plot$labels$x else "Categories",
        y = if (!is.null(plot$labels$y)) plot$labels$y else ""
      )
    }

    # The names are the exception to the leading layer winning: a layer is
    # named for its own mapping when another plots something else, and once
    # they are read as one entry, neither name describes it -- the axis
    # title does (#349).
    for (axis in intersect(c("x", "y"), names(axes))) {
      names_given <- unique(unlist(lapply(layer_results, function(result) {
        if (is.null(result) || is.null(result$axes[[axis]])) {
          return(NULL)
        }
        extract_axis_label(result$axes[[axis]], default = "")
      })))
      title <- extract_axis_label(layout$axes[[axis]], default = "")
      if (length(names_given) > 1 && nzchar(title)) {
        axes[[axis]]$label <- title
      }
    }

    # Add format config per axis (attaching the whole {x, y} list as the
    # x-axis format would drop the y format and malform the x one)
    if (!is.null(format_config)) {
      axes <- attach_axis_format(axes, "x", format_config$x)
      axes <- attach_axis_format(axes, "y", format_config$y)
    }

    validate_axes(axes, context = "facet subplot")

    layer <- list(
      id = layer_id,
      type = layer_type,
      title = facet_title,
      axes = axes,
      data = combined_data,
      selectors = combined_selectors
    )

    # Carry the processor's remaining fields the way the patchwork path does
    # (orientation, violinOptions, domMapping, the `.panel_*` hints the SVG
    # coordinate injection reads). Dropping them silently un-configured every
    # faceted panel: a dodged `stat = "count"` layer asks for the forward
    # per-column highlight walk and got the default reverse one, so every
    # panel highlighted its neighbour's bars.
    #
    # A panel collapses all of its layers into one entry, so the leading
    # layer wins a key it defines -- the same precedence the axes above use.
    for (result in layer_results) {
      if (is.null(result)) {
        next
      }
      for (field_name in names(result)) {
        if (field_name %in% c(
          "id", "type", "selectors", "data", "title", "axes",
          "labels", "multi_layer", "layers"
        )) {
          next
        }
        if (is.null(layer[[field_name]])) {
          layer[[field_name]] <- result[[field_name]]
        }
      }
    }

    layers[[1]] <- layer
  }

  list(
    id = subplot_id,
    layers = layers
  )
}

#' Organize subplots into 2D grid structure
#' @param subplots List of processed subplot data
#' @param panel_layout Panel layout information
#' @return 2D grid structure
organize_facet_grid <- function(subplots, panel_layout) {
  # Determine grid dimensions from built layout
  max_row <- max(panel_layout$ROW)
  max_col <- max(panel_layout$COL)

  grid <- list()
  for (row in seq_len(max_row)) {
    grid[[row]] <- list()
    for (col in seq_len(max_col)) {
      grid[[row]][[col]] <- NULL
    }
  }

  # Fill in the grid using built layout positions
  for (i in seq_along(subplots)) {
    panel_info <- panel_layout[i, ]
    subplot <- subplots[[i]]
    grid[[panel_info$ROW]][[panel_info$COL]] <- subplot
  }

  grid
}

#' Combine data from multiple layers in facet processing
#' @param layer_results List of layer processing results
#' @return Combined data
combine_facet_layer_data <- function(layer_results) {
  combined_data <- list()

  for (result in layer_results) {
    if (is.null(result) || is.null(result$data)) {
      next
    }
    # A processor that drew nothing in this panel returns `list()`. Wrapping
    # that in `list()` used to turn "no data" into ONE empty series, which
    # the caller reads as a layer worth emitting: the panel came out as
    # `"data":[[]]` with an empty selector list, and a reader entering it was
    # told "this is a box plot" and then heard "cat is undefined, lower
    # outlier(s) v is undefined" while the sonification threw on a
    # non-finite AudioParam. An empty facet level (`drop = FALSE` over a
    # factor with an unused level) reaches this on every processor.
    #
    # Contribute nothing instead. With no layer left, the panel is emitted
    # with `layers = list()`, which the frontend already handles -- the Base
    # R `layout()` path emits zero-layer cells today and loads clean.
    if (length(result$data) == 0) {
      next
    }
    if (is.list(result$data)) {
      combined_data <- c(combined_data, result$data)
    } else {
      combined_data <- c(combined_data, list(result$data))
    }
  }

  combined_data
}

#' Combine selectors from multiple layers in facet processing
#' @param layer_results List of layer processing results
#' @return Combined selectors
combine_facet_layer_selectors <- function(layer_results) {
  combined_selectors <- list()

  for (result in layer_results) {
    if (!is.null(result) && !is.null(result$selectors)) {
      combined_selectors <- c(combined_selectors, result$selectors)
    }
  }

  combined_selectors
}

#' The gtable panel drawn at a facet panel's place in the grid
#'
#' ggplot2 reports where it lays each facet panel out as `ROW` and `COL` in
#' `built$layout$layout`, and names the panels of the gtable it draws
#' `panel-<a>-<b>`. What `a` and `b` count is not the row and the column,
#' and differs between facets and releases. ggplot2 3.4.4 and 3.5 name a
#' `facet_grid()` panel `panel-<row>-<col>`, but write the `facet_wrap()`
#' names in an order that matches no grid: a 2 x 2 wrap is `panel-<row>-<col>`,
#' a 2 x 3 one has `panel-3-1` in the first row, second column. ggplot2 4.0
#' names a wrap's panels `panel-<col>-<row>`. Reading the name as the column-
#' major position of the panel, as this did, gave each 2 x 2 wrap and grid
#' the two off-diagonal panels each other's names, and most panels of a
#' grid that is not square another panel's name, so their selectors named
#' the marks of another panel: the highlight lit the other panel's marks,
#' and maidr.js, which places a subplot where its first mark is drawn, put
#' the subplots out of order.
#'
#' What every release keeps is where a panel is drawn: its row and column in
#' the gtable's layout, `t` and `l`. A panel's rank among the distinct `t`
#' of the panels is its row, and its rank among the distinct `l` its column,
#' whatever the gtable calls it.
#'
#' @param panel_info Panel information from layout
#' @param gtable Gtable object
#' @return Gtable panel name or NULL if not found
#' @keywords internal
map_visual_to_dom_panel <- function(panel_info, gtable) {
  layout <- gtable$layout
  panels <- layout[grepl("^panel-\\d+(-\\d+)?$", layout$name), , drop = FALSE]
  if (nrow(panels) == 0) {
    return(NULL)
  }

  row <- match(panels$t, sort(unique(panels$t)))
  col <- match(panels$l, sort(unique(panels$l)))
  hit <- which(
    row == as.integer(panel_info$ROW) & col == as.integer(panel_info$COL)
  )
  if (length(hit) == 1L) {
    return(panels$name[hit])
  }

  # Fallback: the name read as row and column
  expected_name <- paste0("panel-", panel_info$ROW, "-", panel_info$COL)
  if (expected_name %in% panels$name) {
    return(expected_name)
  }

  # Final fallback: return first available panel
  panels$name[1]
}
