#' Patchwork Processing Utilities
#'
#' Utility functions for processing patchwork multipanel compositions.
#' These functions handle panel discovery, leaf extraction, and processing
#' for patchwork plots in a unified way.
#'
#' @keywords internal
NULL

#' Process a patchwork plot and return organized subplot data
#' @param plot The patchwork plot object, with leaves already augmented
#' @param layout Layout information
#' @param gtable Gtable object
#' @param original_plot The un-augmented composition. Supplied so each leaf is
#'   processed for the layers the user wrote rather than for the extra geoms a
#'   processor injected to render its selectors.
#' @return List with organized subplot data in 2D grid format
process_patchwork_plot_data <- function(plot, layout, gtable, original_plot = NULL) {
  # Discover panels via gtable layout
  panel_df <- find_patchwork_panels(gtable)
  if (nrow(panel_df) == 0) {
    return(list())
  }

  max_row <- max(panel_df$row)
  max_col <- max(panel_df$col)

  # Prepare grid structure
  grid <- vector("list", max_row)
  for (r in seq_len(max_row)) {
    grid[[r]] <- vector("list", max_col)
  }

  # Extract leaf plots in addition order (patches first, then the plot
  # carried by the patchwork object itself)
  leaves <- extract_patchwork_leaves(plot)
  orig_leaves <- if (is.null(original_plot)) {
    leaves
  } else {
    extract_patchwork_leaves(original_plot)
  }

  # Pair leaves with panels by DISCOVERY order: find_patchwork_panels()
  # walks panels in patchwork's plot-addition order, which matches the
  # leaf order even for nested layouts where visual row-major order does
  # not.
  #
  # A leaf is not always one panel: a faceted leaf draws one panel per facet
  # cell while still counting as a single leaf, and a leaf patchwork has
  # wrapped draws none that panel discovery can see. Pairing leaf k with
  # panel k drifts from the first such leaf onward, and every later leaf is
  # then described over someone else's panel or dropped for running past the
  # end. Consume each leaf's own panels instead. Every count is 1 unless a
  # leaf is faceted or wrapped, so an ordinary composition pairs exactly as
  # before.
  panel_cursor <- 1L
  for (leaf_idx in seq_along(leaves)) {
    n_panels <- count_leaf_panels(leaves[[leaf_idx]])
    if (n_panels == 0L) {
      next
    }

    i <- panel_cursor
    panel_cursor <- panel_cursor + n_panels
    if (i > nrow(panel_df)) {
      break
    }

    panel_index <- panel_df$panel_index[i]
    row <- panel_df$row[i]
    col <- panel_df$col[i]
    panel_name <- panel_df$name[i]

    subplot_data <- process_patchwork_panel(
      leaves[[leaf_idx]],
      panel_name,
      panel_index,
      row,
      col,
      layout,
      gtable,
      n_original_layers = if (leaf_idx <= length(orig_leaves)) {
        length(orig_leaves[[leaf_idx]]$layers)
      } else {
        NULL
      }
    )
    grid[[row]][[col]] <- subplot_data
  }

  # Fill any grid cells left empty by non-rectangular nesting with valid
  # empty subplots: bare NULLs serialize as `{}`, which the frontend
  # cannot parse.
  for (r in seq_len(max_row)) {
    for (c_idx in seq_len(max_col)) {
      if (is.null(grid[[r]][[c_idx]])) {
        grid[[r]][[c_idx]] <- list(
          id = paste0("maidr-subplot-", generate_unique_id(), "-", r, "-", c_idx),
          layers = list()
        )
      }
    }
  }

  # Canonical financial-chart pattern: candlestick over a volume-only bar
  # panel (via patchwork) collapses to a single subplot with up to three
  # layers (candlestick, bar, line) so the JS frontend announces it as one
  # plot containing N layers, matching py-maidr.
  grid <- merge_candlestick_volume_panels(grid)

  grid
}

#' Has patchwork wrapped this leaf?
#'
#' `inset_element()`, `free()` and `wrap_elements()` each prepend their own
#' class and place the plot in a gtable cell whose name is not a plain
#' "panel-N", so panel discovery never sees it. Test for the wrapper rather
#' than naming them, so one added later behaves the same.
#'
#' @param leaf_plot A leaf of a patchwork composition
#' @return Logical
#' @keywords internal
is_wrapped_leaf <- function(leaf_plot) {
  if (!inherits(leaf_plot, "ggplot")) {
    return(FALSE)
  }
  length(setdiff(class(leaf_plot), class(ggplot2::ggplot()))) > 0
}

#' How many gtable panels one patchwork leaf occupies
#'
#' One for an ordinary leaf; one per facet cell for a faceted one; none for a
#' leaf patchwork has wrapped. Used to walk `find_patchwork_panels()` in step
#' with the leaf list -- a leaf that contributes no panel must not consume
#' one, or every leaf after it is described over somebody else's panel.
#'
#' @param leaf_plot A leaf of a patchwork composition
#' @return Integer count, 0 for a wrapped leaf
#' @keywords internal
count_leaf_panels <- function(leaf_plot) {
  if (!inherits(leaf_plot, "ggplot")) {
    return(1L)
  }
  if (is_wrapped_leaf(leaf_plot)) {
    return(0L)
  }
  if (is.null(leaf_plot$facet) || inherits(leaf_plot$facet, "FacetNull")) {
    return(1L)
  }
  n <- tryCatch(
    nrow(ggplot2::ggplot_build(leaf_plot)$layout$layout),
    error = function(e) NA_integer_
  )
  if (length(n) != 1L || is.na(n) || n < 1L) 1L else as.integer(n)
}

#' Collect every panel cell of a gtable, descending into nested gtables
#'
#' Nested layouts like `(p1 | p2) / p3` place the inner row's panels inside a
#' CHILD gtable ("patchwork-table-N"), so scanning only the top-level layout
#' drops them. Panels are collected in DISCOVERY order, which follows
#' patchwork's plot-addition order and therefore matches
#' [extract_patchwork_leaves()].
#'
#' Each entry also carries the grid viewport path needed to navigate to that
#' panel after the gtable has been drawn. gtable names a cell's viewport
#' `<name>.<t>-<r>-<b>-<l>` and wraps a nested gtable's children in a
#' "layout" viewport, so the path down to a nested panel is
#' `c("<child>.t-r-b-l", "layout", "<panel>.t-r-b-l")`. Panel names are NOT
#' unique across a nested composition (both halves of a 2x2 contain a
#' "panel-1"), which is why callers address panels by position in this list
#' rather than by name.
#'
#' @param gt Gtable object
#' @param t_path Accumulated top positions of the enclosing cells
#' @param l_path Accumulated left positions of the enclosing cells
#' @param vp_prefix Accumulated viewport names of the enclosing cells
#' @return List of panel entries (name, grob, t, l, t_key, l_key, vp_path)
#' @keywords internal
collect_gtable_panels <- function(gt, t_path = integer(0), l_path = integer(0),
                                  vp_prefix = character(0)) {
  out <- list()
  if (is.null(gt)) {
    return(out)
  }
  layout <- gt$layout
  if (is.null(layout) || nrow(layout) == 0) {
    return(out)
  }

  for (i in seq_len(nrow(layout))) {
    nm <- layout$name[i]
    cell_vp <- sprintf(
      "%s.%d-%d-%d-%d",
      nm, layout$t[i], layout$r[i], layout$b[i], layout$l[i]
    )
    # Also matches the bare "panel" of a plain ggplotGrob(); must not match
    # "panel-area" or the "panel-nested-patchwork-N" placeholder.
    if (grepl("^panel(-\\d+(-\\d+)?)?$", nm)) {
      out[[length(out) + 1]] <- list(
        name = nm,
        grob = gt$grobs[[i]],
        t = layout$t[i],
        l = layout$l[i],
        t_key = paste(sprintf("%05d", c(t_path, layout$t[i])), collapse = "."),
        l_key = paste(sprintf("%05d", c(l_path, layout$l[i])), collapse = "."),
        vp_path = c(vp_prefix, cell_vp)
      )
    } else if (inherits(gt$grobs[[i]], "gtable")) {
      out <- c(
        out,
        collect_gtable_panels(
          gt$grobs[[i]],
          c(t_path, layout$t[i]),
          c(l_path, layout$l[i]),
          c(vp_prefix, cell_vp, "layout")
        )
      )
    }
  }
  out
}

#' Resolve the panel grob a layer belongs to
#'
#' Without a panel context this keeps the single-plot behaviour: the cell
#' literally named "panel". With one, the panel is addressed by
#' `panel_ctx$panel_index` into [collect_gtable_panels()], whose order matches
#' [find_patchwork_panels()]. Name matching is only a fallback because
#' patchwork reuses panel names across nesting levels.
#'
#' @param gt Gtable object
#' @param panel_ctx Panel context (panel_index, panel_name, ...), or NULL
#' @return The panel gTree, or NULL when it cannot be resolved
#' @keywords internal
find_gtable_panel_grob <- function(gt, panel_ctx = NULL) {
  if (is.null(gt)) {
    return(NULL)
  }

  as_gtree <- function(grob) {
    if (!is.null(grob) && inherits(grob, "gTree")) grob else NULL
  }

  if (is.null(panel_ctx)) {
    idx <- which(gt$layout$name == "panel")
    if (length(idx) == 0) {
      return(NULL)
    }
    return(as_gtree(gt$grobs[[idx[1]]]))
  }

  panels <- Filter(
    function(p) grepl("^panel-\\d+(-\\d+)?$", p$name),
    collect_gtable_panels(gt)
  )
  if (length(panels) == 0) {
    return(NULL)
  }

  idx <- panel_ctx$panel_index
  if (
    length(idx) == 1L && is.numeric(idx) && !is.na(idx) &&
      idx >= 1 && idx <= length(panels)
  ) {
    return(as_gtree(panels[[idx]]$grob))
  }

  if (!is.null(panel_ctx$panel_name)) {
    for (p in panels) {
      if (identical(p$name, panel_ctx$panel_name)) {
        return(as_gtree(p$grob))
      }
    }
  }

  # Neither key resolved. Guessing at the first panel would hand this
  # layer another panel's grobs, and highlighting that points somewhere
  # else is worse than no highlighting: the caller can tell an empty
  # selector list apart from a wrong one, a user cannot.
  NULL
}

#' Discover panels via gtable layout rows named '^panel-<num>' or '^panel-<row>-<col>'
#' Returns a data.frame with panel_index, name, t, l, row, col
#' @param gtable Gtable object
#' @return Data frame with panel information
find_patchwork_panels <- function(gtable) {
  if (is.null(gtable)) {
    return(data.frame())
  }

  # For grid placement, each panel carries a hierarchical position key (the
  # chain of t/l values down the nesting path) encoded as a fixed-width
  # string so lexicographic ranking reproduces the visual top-to-bottom /
  # left-to-right order.
  panels <- Filter(
    function(p) grepl("^panel-\\d+(-\\d+)?$", p$name),
    collect_gtable_panels(gtable)
  )
  if (length(panels) == 0) {
    return(data.frame())
  }

  t_keys <- vapply(panels, function(p) p$t_key, character(1))
  l_keys <- vapply(panels, function(p) p$l_key, character(1))

  rows <- match(t_keys, sort(unique(t_keys)))
  # Columns are ranked within each row band
  cols <- integer(length(panels))
  for (r in unique(rows)) {
    in_row <- which(rows == r)
    cols[in_row] <- match(l_keys[in_row], sort(unique(l_keys[in_row])))
  }

  data.frame(
    panel_index = seq_along(panels),
    name = vapply(panels, function(p) p$name, character(1)),
    t = vapply(panels, function(p) p$t, numeric(1)),
    l = vapply(panels, function(p) p$l, numeric(1)),
    row = as.integer(rows),
    col = as.integer(cols)
  )
}

#' Recursively extract leaf ggplots in patchwork addition order
#'
#' The order matches panel discovery order in [find_patchwork_panels()]
#' (patches first, then the plot carried by the patchwork object itself),
#' which is how leaves are paired with panels.
#'
#' @param node Patchwork node or ggplot object
#' @return List of leaf ggplot objects
extract_patchwork_leaves <- function(node) {
  if (inherits(node, "patchwork")) {
    out <- list()

    plots <- try(node$patches$plots, silent = TRUE)
    if (!inherits(plots, "try-error") && !is.null(plots)) {
      for (p in plots) {
        out <- c(out, extract_patchwork_leaves(p))
      }
    }

    # A patchwork object IS its most recently added plot (patchwork
    # stores the earlier plots in $patches and keeps the last one as the
    # object itself). Without collecting it, nested layouts like
    # (p1 | p2) / p3 lose p2 and p3.
    self_plot <- tryCatch(
      {
        stripped <- node
        class(stripped) <- setdiff(class(stripped), "patchwork")
        stripped$patches <- NULL
        stripped
      },
      error = function(e) NULL
    )
    if (
      !is.null(self_plot) &&
        inherits(self_plot, "ggplot") &&
        length(self_plot$layers) > 0
    ) {
      out <- c(out, list(self_plot))
    }

    return(out)
  }
  if (inherits(node, "ggplot")) {
    return(list(node))
  }
  list()
}

#' Apply processor plot augmentation to a single leaf ggplot
#'
#' Some processors need extra geoms in the rendered SVG to hang selectors on
#' -- violin injects a thin `geom_boxplot()` so the box-summary layer has
#' something to highlight. The single-plot path does this in
#' `Ggplot2PlotOrchestrator$process_layers()`; leaves of a patchwork need the
#' same treatment before the composition is rendered.
#'
#' @param leaf_plot A ggplot object
#' @return The augmented ggplot (the input unchanged when nothing augments)
#' @keywords internal
augment_leaf_plot <- function(leaf_plot) {
  if (!inherits(leaf_plot, "ggplot") || length(leaf_plot$layers) == 0) {
    return(leaf_plot)
  }

  # A leaf that will not be described must not be augmented: the extra geom
  # would change the drawn figure and buy no accessibility at all. A wrapped
  # leaf is never paired with a panel, and a faceted one is declined by the
  # only processor that augments.
  if (is_wrapped_leaf(leaf_plot)) {
    return(leaf_plot)
  }

  # Violin is the only processor that augments, and it declines facets.
  if (!is.null(leaf_plot$facet) && !inherits(leaf_plot$facet, "FacetNull")) {
    return(leaf_plot)
  }

  registry <- get_global_registry()
  factory <- registry$get_processor_factory("ggplot2")
  adapter <- registry$get_adapter("ggplot2")

  augmented <- leaf_plot
  for (i in seq_along(leaf_plot$layers)) {
    layer <- leaf_plot$layers[[i]]
    layer_type <- adapter$detect_layer_type(layer, leaf_plot)
    if (identical(layer_type, "skip")) {
      next
    }
    processor <- factory$create_processor(
      layer_type,
      list(index = i, type = layer_type)
    )
    if (!is.null(processor) && isTRUE(processor$needs_augmentation())) {
      augmented <- processor$augment_plot(augmented)
    }
  }

  augmented
}

#' Augment every leaf of a patchwork composition
#'
#' Mirrors [extract_patchwork_leaves()]'s traversal so the augmented tree has
#' the same leaf order. The result must be used for BOTH
#' `patchwork::patchworkGrob()` and [process_patchwork_plot_data()]: grob names
#' come from a global counter, so selectors computed against one build cannot
#' resolve against another.
#'
#' @param node Patchwork node or ggplot object
#' @return The same structure with each leaf augmented
#' @keywords internal
augment_patchwork_leaves <- function(node) {
  if (inherits(node, "patchwork")) {
    plots <- try(node$patches$plots, silent = TRUE)
    if (!inherits(plots, "try-error") && !is.null(plots)) {
      node$patches$plots <- lapply(plots, augment_patchwork_leaves)
    }

    # A patchwork object IS its most recently added plot, so the self-carried
    # plot has to be augmented in place as well.
    self_plot <- tryCatch(
      {
        stripped <- node
        class(stripped) <- setdiff(class(stripped), "patchwork")
        stripped$patches <- NULL
        stripped
      },
      error = function(e) NULL
    )
    if (
      !is.null(self_plot) &&
        inherits(self_plot, "ggplot") &&
        length(self_plot$layers) > 0
    ) {
      augmented <- augment_leaf_plot(self_plot)
      if (length(augmented$layers) != length(self_plot$layers)) {
        node$layers <- augmented$layers
      }
    }

    return(node)
  }
  if (inherits(node, "ggplot")) {
    return(augment_leaf_plot(node))
  }
  node
}

#' Extract layout from a single leaf ggplot
#'
#' Mirrors the single-plot path in \code{Ggplot2PlotOrchestrator}: labels are
#' read from the BUILT plot first. ggplot2 v4 resolves derived labels only
#' while building -- the stat-computed "count" of \code{geom_bar()}, and the
#' mapped column names -- so an unbuilt \code{labels} holds nothing but the
#' explicit \code{labs()} overrides.
#'
#' @param leaf_plot The ggplot object
#' @param leaf_built The leaf's built plot, or NULL when it is unavailable
#' @return Layout with title and axes
extract_leaf_plot_layout <- function(leaf_plot, leaf_built = NULL) {
  built_labels <- if (!is.null(leaf_built)) leaf_built$plot$labels else NULL

  # Extract x label: built labels, then user labels, then mapping
  x_label <- built_labels$x
  if (is.null(x_label)) x_label <- leaf_plot$labels$x
  if (is.null(x_label) && !is.null(leaf_plot$mapping$x)) {
    x_label <- rlang::as_label(leaf_plot$mapping$x)
  }
  if (is.null(x_label)) x_label <- ""

  # Extract y label: built labels, then user labels, then mapping
  y_label <- built_labels$y
  if (is.null(y_label)) y_label <- leaf_plot$labels$y
  if (is.null(y_label) && !is.null(leaf_plot$mapping$y)) {
    y_label <- rlang::as_label(leaf_plot$mapping$y)
  }
  if (is.null(y_label)) y_label <- ""

  plot_title <- built_labels$title
  if (is.null(plot_title)) plot_title <- leaf_plot$labels$title

  list(
    title = if (!is.null(plot_title)) plot_title else "",
    axes = build_axes(x = x_label, y = y_label)
  )
}

#' Process a single patchwork panel
#' @param leaf_plot The leaf ggplot object
#' @param panel_name Panel name from gtable
#' @param panel_index Panel index
#' @param row Panel row
#' @param col Panel column
#' @param layout Layout information
#' @param gtable Gtable object
#' @param n_original_layers Number of layers the user actually wrote. Defaults
#'   to every layer of `leaf_plot`; pass the un-augmented count so injected
#'   geoms (violin's boxplot) do not emit a maidr layer of their own.
#' @return Processed panel data
process_patchwork_panel <- function(leaf_plot, panel_name, panel_index, row, col, layout, gtable,
                                    n_original_layers = NULL) {
  subplot_id <- paste0("maidr-subplot-", generate_unique_id(), "-", row, "-", col)

  # Layer ids have to be unique across the whole FIGURE, not just this panel.
  # The frontend's number-format service builds one map for the figure --
  # `for (const subplot of ...) for (const layer of subplot.layers)
  # formatters.set(layer.id, ...)` -- and every trace then looks its formatter
  # up by the bare id it was given. Numbering each leaf's layers from 1 makes
  # a composition emit "maidr-layer-1" once per leaf, so the last leaf's
  # formats overwrite every other leaf's and the wrong ones are announced.
  # The candlestick/volume merge below is worse still: it lifts layers out of
  # two panels into one subplot, where the collision is between siblings.
  # Qualify by the panel's grid cell -- each cell holds exactly one subplot,
  # so (row, col) is what makes an id figure-wide unique.
  layer_id_prefix <- paste0("maidr-layer-", row, "-", col)

  # Build ONCE per panel: rebuilding inside the per-layer loop repeats
  # the full ggplot_build for every layer of the leaf plot. It also has to
  # happen before the layout is read, which needs the built labels.
  leaf_built <- tryCatch(
    ggplot2::ggplot_build(leaf_plot),
    error = function(e) NULL
  )

  # Extract layout from leaf plot (has its own title and axes)
  leaf_layout <- extract_leaf_plot_layout(leaf_plot, leaf_built)

  # Number formatting is per LEAF, not per composition: every leaf is its own
  # ggplot carrying its own scales, so a currency y axis on one leaf and a
  # percent y axis on another must each survive into their own layers. The
  # single-plot and faceted paths extract this once because they only ever
  # describe one set of scales.
  leaf_format <- extract_format_config(leaf_built)

  registry <- get_global_registry()
  factory <- registry$get_processor_factory("ggplot2")
  adapter <- registry$get_adapter("ggplot2")

  # Fallbacks for a layer whose processor returned no title or axes.
  leaf_title <- leaf_layout$title
  leaf_axes <- leaf_layout$axes

  n_layers <- if (is.null(n_original_layers)) {
    length(leaf_plot$layers)
  } else {
    min(n_original_layers, length(leaf_plot$layers))
  }

  layers <- list()
  for (layer_idx in seq_len(n_layers)) {
    layer <- leaf_plot$layers[[layer_idx]]

    # Use unified layer processor creation logic
    layer_info <- list(index = layer_idx, type = class(layer$geom)[1])

    layer_type <- adapter$detect_layer_type(layer, leaf_plot)

    # Layers tagged "skip" (e.g. tidyquant's wick layer, which is folded
    # into the candlestick body layer) must not produce a maidr layer.
    if (identical(layer_type, "skip")) {
      next
    }

    processor <- factory$create_processor(layer_type, layer_info)

    if (!is.null(processor)) {
      # New panel context API
      panel_ctx <- list(
        panel_name = panel_name,
        panel_index = panel_index,
        row = row,
        col = col,
        layer_index = layer_idx
      )

      # One leaf that a processor cannot handle must not abort the whole
      # composition: the other panels are still perfectly describable, and a
      # figure that renders with one silent panel beats no figure at all.
      result <- tryCatch(
        processor$process(
          leaf_plot,
          leaf_layout,
          built = leaf_built,
          gt = gtable,
          scale_mapping = NULL,
          panel_ctx = panel_ctx,
          panel_id = NULL
        ),
        error = function(e) NULL
      )

      if (!is.null(result)) {
        # A processor may return several maidr layers for one ggplot layer
        # (violin -> violin_box + violin_kde), the same expansion
        # Ggplot2PlotOrchestrator$combine_layer_results() performs on the
        # single-plot path. Single-layer ids are left untouched.
        expanded <- isTRUE(result$multi_layer) && !is.null(result$layers)
        subs <- if (expanded) result$layers else list(result)

        for (sub_idx in seq_along(subs)) {
          sub <- subs[[sub_idx]]
          if (is.null(sub)) next

          # Same treatment the other two paths give their axes: attach the
          # scale's number format per axis, then hold the result to the
          # canonical {x,y,z} contract.
          sub_axes <- if (!is.null(sub$axes)) sub$axes else leaf_axes
          if (!is.null(leaf_format)) {
            sub_axes <- attach_axis_format(sub_axes, "x", leaf_format$x)
            sub_axes <- attach_axis_format(sub_axes, "y", leaf_format$y)
          }
          validate_axes(sub_axes, context = "patchwork subplot")

          layer_entry <- list(
            id = if (expanded) {
              paste0(layer_id_prefix, "-", layer_idx, "-", sub_idx)
            } else {
              paste0(layer_id_prefix, "-", layer_idx)
            },
            type = if (!is.null(sub$type)) sub$type else layer_type,
            title = leaf_title,
            axes = sub_axes,
            data = sub$data,
            selectors = sub$selectors
          )

          # Carry the processor's remaining fields (orientation,
          # violinOptions, domMapping, the .panel_* hints the SVG
          # coordinate injection reads). Restricted to expanded results so
          # single-layer patchwork payloads keep their current shape.
          if (expanded) {
            for (field_name in names(sub)) {
              if (!field_name %in% c(
                "id", "type", "selectors", "data", "title", "axes",
                "labels", "multi_layer", "layers"
              )) {
                layer_entry[[field_name]] <- sub[[field_name]]
              }
            }
            if (!is.null(sub$labels) && length(sub$labels) > 0) {
              layer_entry$labels <- sub$labels
            }
          }

          # A step layer is a single-layer result, so the carry above --
          # deliberately scoped to expanded results -- does not reach it. Its
          # hv/vh/mid convention is a layer-level sibling of axes/data, and
          # this entry is rebuilt field by field, so without this the
          # direction is dropped from every patchworked step plot.
          if (!expanded && !is.null(sub$stepDirection)) {
            layer_entry$stepDirection <- sub$stepDirection
          }

          layers[[length(layers) + 1]] <- layer_entry
        }
      }
    }
  }

  panel <- list(
    id = subplot_id,
    layers = layers
  )

  # Multiple line layers in one panel (e.g. several geom_ma overlays on a
  # candlestick) should be merged into a single multi-series line layer so
  # the JS frontend announces them as one "multiline" layer (matching
  # py-maidr's behaviour) rather than N separate layers.
  collapse_lines_to_multiseries(panel)
}

# ==============================================================================
# Panel-merging helpers (candlestick + volume + MA multilines)
# ==============================================================================
#
# These helpers post-process the patchwork subplot grid so that the canonical
# financial-chart pattern produces a single accessible subplot with up to
# three layers (candlestick, bar, line) instead of two separate subplots.
# Volume y-values are also embedded into candlestick data points so the
# description table mirrors py-maidr's CandlestickPoint.volume field.

#' Does a panel contain a layer of the given type?
#' @param panel A processed patchwork panel (with `$layers`)
#' @param type Layer type string ("candlestick", "bar", "line", ...)
#' @return Logical
#' @keywords internal
panel_has_layer_of_type <- function(panel, type) {
  if (is.null(panel) || is.null(panel$layers) || length(panel$layers) == 0) {
    return(FALSE)
  }
  types <- vapply(panel$layers, function(l) {
    if (!is.null(l$type)) l$type else NA_character_
  }, character(1))
  any(types == type, na.rm = TRUE)
}

#' Return the (first) layer in `panel` whose type matches `type`
#' @keywords internal
panel_layer_of_type <- function(panel, type) {
  if (is.null(panel) || is.null(panel$layers)) {
    return(NULL)
  }
  for (l in panel$layers) {
    if (!is.null(l$type) && identical(l$type, type)) {
      return(l)
    }
  }
  NULL
}

#' Is this panel a volume-only bar panel (single bar layer, no other layers)?
#' @keywords internal
is_volume_only_bar_panel <- function(panel) {
  if (is.null(panel) || is.null(panel$layers) || length(panel$layers) != 1L) {
    return(FALSE)
  }
  identical(panel$layers[[1]]$type, "bar")
}

#' Collapse multiple "line" layer entries in a single panel into one
#' multi-series line layer entry. Other layers are left untouched.
#'
#' The first line layer's id, title, and axes are preserved; data and
#' selectors are concatenated across all line layers.
#'
#' @param panel A processed panel list with $id and $layers
#' @return Panel with line layers merged
#' @keywords internal
collapse_lines_to_multiseries <- function(panel) {
  if (is.null(panel) || is.null(panel$layers) || length(panel$layers) < 2) {
    return(panel)
  }

  layers <- panel$layers
  is_line <- vapply(layers, function(l) {
    isTRUE(identical(l$type, "line"))
  }, logical(1))

  if (sum(is_line) < 2L) {
    return(panel)
  }

  line_layers <- layers[is_line]
  merged_line <- merge_line_layers(line_layers)

  # Rebuild layers list: keep non-line layers in their original order,
  # insert the merged line layer at the position of the first line layer.
  out <- list()
  inserted <- FALSE
  for (i in seq_along(layers)) {
    if (is_line[i]) {
      if (!inserted) {
        out[[length(out) + 1L]] <- merged_line
        inserted <- TRUE
      }
      # Skip subsequent line layers (they've been merged in).
      next
    }
    out[[length(out) + 1L]] <- layers[[i]]
  }

  panel$layers <- out
  panel
}

#' Combine a list of single-line layer entries into one multi-series line entry.
#'
#' Each input line layer's `data` is a list-of-series (typically length-1 for
#' a single GeomLine/GeomMA). We concatenate all series across all layers.
#'
#' Selector handling: each input layer now resolves to its OWN polyline grob
#' and emits one selector per curve it drew, so the inputs no longer overlap.
#' The dedupe-and-trim below is kept as a backstop, not as the mechanism: it
#' used to be load-bearing, because the generator discovered *all* polyline
#' grobs in the panel and handed every one of N line layers the same length-N
#' set. What still has to hold after merging is the frontend precondition
#' `selectors.length === data.length` — one selector per merged series —
#' which is why the trim below stays. There is deliberately no pad: a short
#' list fails that precondition and the frontend drops the layer's highlight
#' rather than aiming it at the wrong curve.
#' @keywords internal
merge_line_layers <- function(line_layers) {
  first <- line_layers[[1]]

  combined_data <- list()
  all_selectors <- list()

  for (l in line_layers) {
    # `data` should already be a list of series. Be defensive: if it's a flat
    # list of points (unwrapped single series), wrap it.
    if (!is.null(l$data)) {
      d <- l$data
      if (length(d) > 0 && !is.null(d[[1]]) && !is.list(d[[1]][[1]])) {
        # Looks like flat points -> wrap as single series
        d <- list(d)
      }
      for (series in d) {
        combined_data[[length(combined_data) + 1L]] <- series
      }
    }
    if (!is.null(l$selectors)) {
      sels <- l$selectors
      if (!is.list(sels)) {
        sels <- list(sels)
      }
      for (s in sels) {
        all_selectors[[length(all_selectors) + 1L]] <- s
      }
    }
  }

  # Dedupe, preserving discovery order. Each layer now resolves to its own
  # grob, so this should be a no-op; it is kept because a duplicate would
  # otherwise consume a series' slot in the trim below.
  seen <- character(0)
  unique_selectors <- list()
  for (s in all_selectors) {
    key <- if (is.character(s)) s else paste0(unlist(s), collapse = "\u0001")
    if (!(key %in% seen)) {
      seen <- c(seen, key)
      unique_selectors[[length(unique_selectors) + 1L]] <- s
    }
  }

  # Trim to series count so selectors.length === data.length.
  n_series <- length(combined_data)
  if (length(unique_selectors) > n_series) {
    unique_selectors <- unique_selectors[seq_len(n_series)]
  }

  list(
    id = first$id,
    type = "line",
    title = first$title,
    axes = first$axes,
    data = combined_data,
    selectors = unique_selectors
  )
}

#' Embed volume y-values from a bar layer into the candlestick layer's data.
#'
#' Strategy:
#'   1. If both layers have the same number of points, embed positionally.
#'      This is the canonical case: patchwork stacks two panels driven by
#'      the same date column, so the i-th candle and the i-th bar refer to
#'      the same trading day even if the bar layer's x is formatted
#'      differently from the candle's `value`.
#'   2. Otherwise, fall back to string-matching the candle's `value` field
#'      against the bar layer's `x` field.
#' @keywords internal
embed_volume_into_candle_data <- function(candle_layer, bar_layer) {
  if (is.null(candle_layer$data) || length(candle_layer$data) == 0) {
    return(candle_layer)
  }
  if (is.null(bar_layer$data) || length(bar_layer$data) == 0) {
    return(candle_layer)
  }

  n_c <- length(candle_layer$data)
  n_b <- length(bar_layer$data)

  if (n_c == n_b) {
    for (i in seq_len(n_c)) {
      bar_pt <- bar_layer$data[[i]]
      if (!is.null(bar_pt$y)) {
        pt <- candle_layer$data[[i]]
        pt$volume <- bar_pt$y
        candle_layer$data[[i]] <- pt
      }
    }
    return(candle_layer)
  }

  # Fallback: string-match by candle$value vs bar$x
  bar_lookup <- new.env(hash = TRUE, parent = emptyenv())
  for (pt in bar_layer$data) {
    if (!is.null(pt$x) && !is.null(pt$y)) {
      assign(as.character(pt$x), pt$y, envir = bar_lookup)
    }
  }

  for (i in seq_along(candle_layer$data)) {
    pt <- candle_layer$data[[i]]
    if (!is.null(pt$value)) {
      key <- as.character(pt$value)
      if (exists(key, envir = bar_lookup, inherits = FALSE)) {
        pt$volume <- get(key, envir = bar_lookup, inherits = FALSE)
        candle_layer$data[[i]] <- pt
      }
    }
  }

  candle_layer
}

#' Post-process a 2D subplot grid: if the layout is candlestick over
#' volume-only bar (2 rows x 1 col, sharing an x-axis), collapse to a single
#' 1x1 subplot whose layers are candlestick (+ embedded volume), bar, and
#' optional line (multi-series MAs).
#' @keywords internal
merge_candlestick_volume_panels <- function(grid) {
  if (!is.list(grid) || length(grid) != 2L) {
    return(grid)
  }
  if (!is.list(grid[[1]]) || !is.list(grid[[2]])) {
    return(grid)
  }
  if (length(grid[[1]]) != 1L || length(grid[[2]]) != 1L) {
    return(grid)
  }

  top <- grid[[1]][[1]]
  bottom <- grid[[2]][[1]]

  if (is.null(top) || is.null(bottom)) {
    return(grid)
  }
  if (!panel_has_layer_of_type(top, "candlestick")) {
    return(grid)
  }
  if (!is_volume_only_bar_panel(bottom)) {
    return(grid)
  }

  candle <- panel_layer_of_type(top, "candlestick")
  bar    <- bottom$layers[[1]]
  line   <- panel_layer_of_type(top, "line")  # may be NULL

  # Embed volume y-values into candlestick data points
  candle <- embed_volume_into_candle_data(candle, bar)

  merged_layers <- list(candle, bar)
  if (!is.null(line)) {
    merged_layers[[length(merged_layers) + 1L]] <- line
  }

  merged_panel <- list(
    id = top$id,
    layers = merged_layers
  )

  # Return a 1x1 grid
  list(list(merged_panel))
}
