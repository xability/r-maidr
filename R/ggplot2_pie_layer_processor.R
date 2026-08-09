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
      values <- built_data$ymax - built_data$ymin

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

      polygon_grob <- NULL

      if (!is.null(panel_ctx) && !is.null(panel_ctx$panel_name)) {
        # Facet / patchwork path: scope the search to this panel's grob
        panel_grob <- find_gtable_panel_grob(gt, panel_ctx)
        if (!is.null(panel_grob)) {
          polygon_grob <- self$find_polygon_grob(panel_grob)
        }
      } else if ("grobs" %in% names(gt)) {
        for (grob in gt$grobs) {
          polygon_grob <- self$find_polygon_grob(grob)
          if (!is.null(polygon_grob)) break
        }
      }

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

    #' @description Find this layer's wedge polygon grob within a grob tree
    #'
    #' Matches on the \code{geom_rect.polygon} prefix, which the polar grill's
    #' own polygon (named \code{GRID.polygon.<N>} under \code{coord_radial()})
    #' does not carry.
    #'
    #' @param grob Grob to search
    #' @return Grob name, or NULL when the tree holds none
    find_polygon_grob = function(grob) {
      if (!is.null(grob$name) && grepl("geom_rect\\.polygon", grob$name)) {
        return(grob$name)
      }

      if ("children" %in% names(grob)) {
        for (child in grob$children) {
          result <- self$find_polygon_grob(child)
          if (!is.null(result)) {
            return(result)
          }
        }
      }

      NULL
    }
  )
)
