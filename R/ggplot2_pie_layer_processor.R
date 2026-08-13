#' Pie Layer Processor
#'
#' Processes the ggplot2 idiom for a pie chart: a \code{geom_col()} /
#' \code{geom_bar()} layer drawn in polar coordinates with theta mapped to y,
#' so the stack's segments become wedges. The payload is 1-D and flat -- one
#' point per wedge, \code{x} the slice label and \code{y} its magnitude. The
#' percentage MAIDR announces is derived from those values by the frontend, so
#' this layer deliberately does not emit one.
#'
#' Multi-ring "bullseye" polar bars are out of scope. \code{geom_col()} with a
#' non-constant x under \code{coord_polar("y")} draws one concentric ring per
#' x category, and a flat list of wedges cannot carry that second dimension --
#' wedges from different rings would collapse onto the same label. Those
#' layers never reach this processor: \code{Ggplot2Adapter$is_pie_coord()}
#' declines them, and they stay bar / stacked / dodged as before.
#'
#' @keywords internal
Ggplot2PieLayerProcessor <- R6::R6Class(
  "Ggplot2PieLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Process the pie layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @param scale_mapping Scale mapping for faceted plots (optional)
    #' @param grob_id Grob ID for faceted plots (optional)
    #' @param panel_id Panel ID for faceted plots (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List with data, selectors, title, axes and type
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

      list(
        data = self$extract_data(plot, built, panel_id = panel_id),
        selectors = self$generate_selectors(plot, gt, panel_ctx = panel_ctx),
        title = if (!is.null(layout$title)) layout$title else "",
        axes = self$extract_pie_axes(plot, layout, built, panel_id),
        type = "pie"
      )
    },

    #' @description Extract one point per wedge
    #'
    #' The magnitude is the segment's own extent, not the stacked \code{y}:
    #' \code{ymax - ymin} is what the wedge actually subtends, and it is the
    #' one expression that works for both \code{geom_col()} (stat identity)
    #' and \code{geom_bar()} (stat count).
    #'
    #' The extent is unsigned, though, and a negative datum is stacked
    #' \emph{below} the baseline: ggplot2 builds \code{v = -40} as
    #' \code{ymin = -40, ymax = 0}, so the extent is 40 and the sign is gone.
    #' Reporting that would announce a slice the author entered as -40 as
    #' \code{40}, and compute its share against a total that swallowed it --
    #' confidently wrong, and indistinguishable from real data.
    #'
    #' So the sign is restored from which side of the baseline the segment
    #' sits on. The renderer treats a negative slice as a gap, announcing it
    #' as missing rather than letting it corrupt every other slice's
    #' percentage; laundering it here would leave that defence nothing to
    #' catch. Whether a producer should reject such a value outright is a
    #' separate question -- see xability/maidr#771 -- but no answer to it is
    #' served by destroying the sign first.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @param panel_id Optional facet panel to restrict extraction to
    #' @return List of \code{list(x, y)} points, one per wedge
    extract_data = function(plot, built = NULL, panel_id = NULL) {
      if (is.null(built)) {
        built <- ggplot2::ggplot_build(plot)
      }

      built_data <- self$panel_built_data(built, panel_id)
      if (nrow(built_data) == 0) {
        return(list())
      }

      labels <- self$resolve_slice_labels(plot, built, built_data)
      # A segment lying below the baseline came from a negative datum; one
      # touching or above it did not. `ymax <= 0` is the test rather than
      # `ymin < 0`, so a segment straddling zero -- which stacking does not
      # produce, but a hand-built layer could -- is read as positive rather
      # than having its sign guessed.
      extents <- built_data$ymax - built_data$ymin
      below <- !is.na(built_data$ymax) & built_data$ymax <= 0 &
        !is.na(built_data$ymin) & built_data$ymin < 0
      values <- ifelse(below, -extents, extents)

      lapply(seq_len(nrow(built_data)), function(i) {
        list(x = labels[[i]], y = values[[i]])
      })
    },

    #' @description Rows of this layer's built data, optionally one panel's
    #' @param built Built plot data
    #' @param panel_id Optional facet panel to restrict the rows to
    #' @return data.frame of built rows for this layer
    panel_built_data = function(built, panel_id = NULL) {
      built_data <- built$data[[self$get_layer_index()]]
      if (!is.null(panel_id) && "PANEL" %in% names(built_data)) {
        built_data <- built_data[built_data$PANEL == panel_id, , drop = FALSE]
      }
      built_data
    },

    #' @description Resolve the aesthetic whose categories name the wedges
    #'
    #' Fill is probed before x because the idiomatic pie maps x to the literal
    #' \code{""} and carries the categories on fill. A layer whose built rows
    #' do not each sit in their own group is not split by any aesthetic (every
    #' row shares group -1 or 1), so no aesthetic names its wedges.
    #'
    #' @param plot The ggplot2 object
    #' @param built_data This layer's built rows
    #' @return list with \code{aes} (aesthetic name, or NULL) and
    #'   \code{column} (the mapped column name)
    resolve_slice_mapping = function(plot, built_data) {
      group_ids <- built_data$group
      if (is.null(group_ids) || anyDuplicated(group_ids) > 0) {
        return(list(aes = NULL, column = "group"))
      }

      # One aesthetic per call: `resolve_series_group_mapping()` probes the
      # LAYER's mapping for every aesthetic it is handed before it looks at
      # the plot's, so passing fill and x together would let a layer-level x
      # beat a plot-level fill. Fill has to be exhausted at both levels first
      # -- a pie's x is the constant that collapses the ring, and naming the
      # wedges after it leaves every one of them called the same thing.
      fill <- resolve_series_group_mapping(
        plot,
        self$get_layer_index(),
        aes_groups = list("fill")
      )
      if (!is.null(fill$aes)) {
        return(fill)
      }

      resolve_series_group_mapping(
        plot,
        self$get_layer_index(),
        aes_groups = list("x")
      )
    },

    #' @description Name each wedge after the category it draws
    #'
    #' \code{ggplot_build()} has already replaced the grouping column with
    #' integer group ids, assigned in the sorted order of that column's
    #' values -- the same order the scale reports its labels in. Indexing the
    #' labels BY the id, rather than by position among the ids present, is
    #' what stops a facet panel that is missing a category from shifting every
    #' remaining wedge's label by one. Wedges the scale cannot name fall back
    #' to their position.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @param built_data This layer's built rows
    #' @return Character vector, one label per wedge
    resolve_slice_labels = function(plot, built, built_data) {
      labels <- as.character(seq_len(nrow(built_data)))

      slice <- self$resolve_slice_mapping(plot, built_data)
      if (is.null(slice$aes)) {
        return(labels)
      }

      categories <- self$slice_categories(plot, built, slice)
      if (is.null(categories)) {
        return(labels)
      }

      ids <- suppressWarnings(as.integer(built_data$group))
      hit <- !is.na(ids) & ids >= 1 & ids <= length(categories)
      labels[hit] <- categories[ids[hit]]
      labels
    },

    #' @description Categories of the aesthetic that splits the wedges
    #'
    #' The scale is asked first, because a mapping written as an expression --
    #' \code{aes(fill = factor(cyl))} -- has no column to read. A discrete
    #' POSITION scale keeps its labels in \code{panel_params} instead, and
    #' \code{coord_polar()} publishes none of those under x, so the mapped
    #' column is the fallback. Both list the categories in the same sorted
    #' order the group ids were assigned in.
    #'
    #' @param plot The ggplot2 object
    #' @param built Built plot data
    #' @param slice Slice mapping from \code{resolve_slice_mapping()}
    #' @return Character vector of categories, or NULL when neither source has any
    slice_categories = function(plot, built, slice) {
      labels <- self$scale_labels(built, slice$aes)
      if (!is.null(labels)) {
        return(labels)
      }

      original <- plot$data
      if (is.data.frame(original) && slice$column %in% names(original)) {
        return(as.character(sort(unique(original[[slice$column]]))))
      }

      NULL
    },

    #' @description Break labels of the scale backing an aesthetic
    #' @param built Built plot data
    #' @param aes_name Aesthetic whose scale to read
    #' @return Character vector of labels, or NULL when the scale has none
    scale_labels = function(built, aes_name) {
      scales <- built$plot$scales$scales
      if (is.null(scales)) {
        return(NULL)
      }

      for (sc in scales) {
        if (!(aes_name %in% sc$aesthetics) || !is.function(sc$get_labels)) {
          next
        }
        labels <- tryCatch(as.character(sc$get_labels()), error = function(e) NULL)
        if (length(labels) > 0) {
          return(labels)
        }
      }

      NULL
    },

    #' @description Build the canonical axes for a pie layer
    #'
    #' \code{x} names what the wedge labels mean and \code{y} what their
    #' magnitudes measure. Since the labels come off the slice aesthetic, its
    #' legend title is the x label -- resolved the same way the stacked bar
    #' layer resolves its z label. The y label is taken from the layout, which
    #' reads the BUILT plot's labels and so already carries a stat-derived
    #' name such as "count".
    #'
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data
    #' @param panel_id Optional facet panel to restrict extraction to
    #' @return Canonical axes list with x and y
    extract_pie_axes = function(plot, layout, built, panel_id = NULL) {
      fallback <- self$extract_layer_axes(plot, layout)

      slice <- self$resolve_slice_mapping(plot, self$panel_built_data(built, panel_id))
      x_label <- if (!is.null(slice$aes)) {
        resolve_legend_label(
          plot,
          built = built,
          aes_names = slice$aes,
          layer_index = self$get_layer_index()
        )
      } else {
        NULL
      }
      if (is.null(x_label)) {
        x_label <- extract_axis_label(fallback$x, default = "")
      }

      build_axes(x = x_label, y = extract_axis_label(fallback$y, default = ""))
    },

    #' @description Generate the wedge selector for this layer
    #'
    #' In polar coordinates the whole layer is ONE \code{polygonGrob} named
    #' \code{geom_rect.polygon.<N>} whose sub-polygons are grouped by
    #' \code{id} -- not the \code{geom_rect.rect.<N>} a cartesian bar layer
    #' draws. gridSVG exports it as \code{<g id="geom_rect.polygon.<N>.1">}
    #' with one \code{<polygon>} child per wedge, emitted in built-row order,
    #' so a single descendant selector resolves to the N elements in slice
    #' order.
    #'
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @param panel_ctx Panel context for panel-scoped selectors (optional)
    #' @return List holding one selector, or an empty list
    generate_selectors = function(plot, gt = NULL, panel_ctx = NULL) {
      if (is.null(gt)) {
        return(list())
      }

      roots <- list()
      if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        # Facet / patchwork path: scope the search to this panel's grob
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (!is.null(panel_grob)) {
          roots <- list(panel_grob)
        }
      } else if ("grobs" %in% names(gt)) {
        roots <- gt$grobs
      }

      polygon_grob <- self$resolve_layer_polygon_grob(plot, roots)

      # No polygon grob means this layer drew no wedges here: an empty facet
      # level, a zero-row layer, a coord that renders no polygons. The layer
      # INDEX is not the grob id - every `geom_rect.polygon.N` id carries
      # grid's session-wide grob counter - so a guessed name is right only by
      # coincidence, and when it does land it lands on ANOTHER panel's
      # wedges, which highlights the wrong marks while the payload still
      # looks healthy. The caller can tell an empty selector list apart from
      # a wrong one, a user cannot.
      if (is.null(polygon_grob)) {
        return(list())
      }

      svg_id <- paste0(polygon_grob, ".1")
      escaped_svg_id <- gsub("\\.", "\\\\.", svg_id)

      list(paste0("#", escaped_svg_id, " polygon"))
    },

    #' @description Find the grob whose \code{<polygon>} descendants are the wedges
    #'
    #' ggplot2 does not draw a polar bar layer the same way across versions,
    #' and the difference is not cosmetic. Verified against real
    #' \code{gridSVG::grid.export()} output:
    #'
    #' \itemize{
    #'   \item One \code{geom_rect.polygon.<N>} grob holding every wedge,
    #'     grouped by id. This is what the lookup was written for.
    #'   \item A \code{geom_rect.gTree.<N>} holding **one
    #'     \code{geom_polygon.polygon.<N>} grob per wedge}. On ggplot2 3.4.4
    #'     this is what a pie draws, and nothing named
    #'     \code{geom_rect.polygon} exists anywhere in the tree -- so the
    #'     lookup found nothing, \code{generate_selectors()} returned an empty
    #'     list, and **a pie highlighted nothing at all** (#151).
    #' }
    #'
    #' Either way the answer is a container whose \code{<polygon>} descendants
    #' are the wedges in slice order, so the caller's descendant selector
    #' resolves against both without knowing which it got.
    #'
    #' The polar grill draws a polygon of its own under
    #' \code{coord_radial()}, named \code{GRID.polygon.<N>}; neither branch
    #' carries a name that matches it.
    #'
    #' @param grob Grob to search
    #' @return Grob name, or NULL when the tree holds none
    #' @description Pick the wedge container belonging to *this* layer
    #'
    #' A panel can hold more than one polar \code{geom_rect} layer -- two
    #' \code{geom_col()}s under \code{coord_polar()} is an ordinary way to
    #' draw a ring over a pie -- and a search that takes the first match
    #' hands every layer the first layer's wedges. Those selectors resolve,
    #' and the payload looks healthy, and the outline is on the wrong marks.
    #'
    #' \code{LayerProcessor$find_layer_grob_tree()} cannot be reused for
    #' this: it matches on the geom's own class, and a \code{geom_col()}
    #' layer is \code{GeomCol} while the grob it draws is named after
    #' \code{geom_rect}. So the containers are collected in drawing order --
    #' which is layer order -- and indexed.
    #'
    #' When the counts do not line up the answer is no selector rather than
    #' a guess, for the reason \code{generate_selectors()} already gives: a
    #' wrong selector highlights another layer's wedges, and the caller can
    #' tell an empty list from a wrong one where a reader cannot.
    #'
    #' @param plot The ggplot2 object, or NULL when the caller has none
    #' @param roots Grobs to search, in drawing order
    #' @return Grob name, or NULL
    resolve_layer_polygon_grob = function(plot, roots) {
      containers <- unlist(
        lapply(roots, function(root) self$collect_polygon_grobs(root)),
        use.names = FALSE
      )
      if (length(containers) == 0L) {
        return(NULL)
      }
      if (length(containers) == 1L) {
        return(containers[[1]])
      }

      index <- self$get_layer_index()
      layers <- if (is.null(plot)) NULL else plot$layers
      if (is.null(layers) || length(containers) != length(layers) ||
        is.null(index) || index < 1L || index > length(containers)) {
        return(NULL)
      }
      containers[[index]]
    },

    #' @description Every wedge container in a grob tree, in drawing order
    #'
    #' One entry per layer that drew wedges. A match is not descended into:
    #' the container is the whole layer's wedges, and its children are the
    #' individual ones.
    #'
    #' @param grob Grob to search
    #' @return Character vector of grob names, possibly empty
    collect_polygon_grobs = function(grob) {
      if (is.null(grob)) {
        return(character(0))
      }

      own <- self$find_own_polygon_grob(grob)
      if (!is.null(own)) {
        return(own)
      }

      found <- character(0)
      if ("children" %in% names(grob)) {
        for (child in grob$children) {
          found <- c(found, self$collect_polygon_grobs(child))
        }
      }
      found
    },

    #' @description Whether this grob is itself a wedge container
    #' @param grob Grob to test
    #' @return Grob name, or NULL
    find_own_polygon_grob = function(grob) {
      if (is.null(grob$name)) {
        return(NULL)
      }
      if (grepl("^geom_rect\\.polygon", grob$name)) {
        return(grob$name)
      }
      if (grepl("^geom_rect\\.gTree", grob$name) && self$holds_polygon(grob)) {
        return(grob$name)
      }
      NULL
    },

    find_polygon_grob = function(grob) {
      if (is.null(grob)) {
        return(NULL)
      }
      named <- self$find_named_polygon_grob(grob)
      if (!is.null(named)) {
        return(named)
      }
      self$find_wedge_container(grob)
    },

    #' @description Find a single grob holding every wedge, if there is one.
    #'
    #' @param grob Grob to search
    #' @return Grob name, or NULL
    find_named_polygon_grob = function(grob) {
      if (!is.null(grob$name) && grepl("^geom_rect\\.polygon", grob$name)) {
        return(grob$name)
      }

      if ("children" %in% names(grob)) {
        for (child in grob$children) {
          result <- self$find_named_polygon_grob(child)
          if (!is.null(result)) {
            return(result)
          }
        }
      }

      NULL
    },

    #' @description Find the layer tree whose polygon children are the wedges.
    #'
    #' Requires the tree to actually hold a polygon. A \code{geom_rect} gTree
    #' that drew none is a layer with nothing to point at, and naming it would
    #' emit a selector resolving to nothing -- which the caller cannot tell
    #' apart from a working one, and a reader cannot tell apart from a bug.
    #'
    #' @param grob Grob to search
    #' @return Grob name, or NULL
    find_wedge_container = function(grob) {
      if (!is.null(grob$name) && grepl("^geom_rect\\.gTree", grob$name) &&
        self$holds_polygon(grob)) {
        return(grob$name)
      }

      if ("children" %in% names(grob)) {
        for (child in grob$children) {
          result <- self$find_wedge_container(child)
          if (!is.null(result)) {
            return(result)
          }
        }
      }

      NULL
    },

    #' @description Whether a grob tree draws at least one polygon.
    #'
    #' @param grob Grob to search
    #' @return TRUE when the tree holds a polygon grob
    holds_polygon = function(grob) {
      if (identical(class(grob)[1], "polygon")) {
        return(TRUE)
      }

      if ("children" %in% names(grob)) {
        for (child in grob$children) {
          if (self$holds_polygon(child)) {
            return(TRUE)
          }
        }
      }

      FALSE
    }
  )
)
