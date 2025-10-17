#' Boxplot Layer Processor
#'
#' Processes boxplot layers (geom_boxplot) to extract statistical data and generate selectors
#' for individual boxplot components in the SVG structure.
#'
#' @keywords internal
Ggplot2BoxplotLayerProcessor <- R6::R6Class("Ggplot2BoxplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' Process the boxplot layer
    #' @param plot The ggplot2 object
    #' @param layout Layout information
    #' @param built Built plot data (optional)
    #' @param gt Gtable object (optional)
    #' @return List with data and selectors
    process = function(plot, layout, built = NULL, gt = NULL) {
      # Extract data from the boxplot layer
      extracted_data <- self$extract_data(plot, built)

      # Generate selectors for the boxplot elements
      selectors <- self$generate_selectors(plot, gt)

      # Determine orientation
      orientation <- self$determine_orientation(plot)

      # Create axes information
      axes <- list(
        x = if (!is.null(layout$axes$x)) layout$axes$x else "x",
        y = if (!is.null(layout$axes$y)) layout$axes$y else "y"
      )

      list(
        data = extracted_data,
        selectors = selectors,
        axes = axes,
        orientation = orientation,
        type = "box"
      )
    },

    #' Extract data from boxplot layer
    #' @param plot The ggplot2 object
    #' @param built Built plot data (optional)
    #' @return List with boxplot statistics for each category
    extract_data = function(plot, built = NULL) {
      if (is.null(built)) built <- ggplot2::ggplot_build(plot)

      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]

      # Extract boxplot statistics for each category
      boxplot_data <- list()

      for (i in 1:nrow(layer_data)) {
        row <- layer_data[i, ]

        # Extract basic statistics
        stats <- list(
          min = row$xmin, # Min of data (including outliers)
          max = row$xmax, # Max of data (including outliers)
          q1 = row$xlower, # Lower quartile (Q1) - box start
          q3 = row$xupper, # Upper quartile (Q3) - box end
          q2 = row$xmiddle, # Median (Q2) - box middle
          fill = as.character(row$y), # Use y values as category codes (will be mapped to actual names)
          y_value = row$y # Store the numeric y value for mapping
        )

        # Handle outliers - they are stored as "c(value1, value2)" strings
        outliers_str <- as.character(row$outliers)
        if (outliers_str != "" && !is.na(outliers_str) && outliers_str != "NA" && outliers_str != " numeric(0) ") {
          # Parse the "c(value1, value2)" format
          outliers_text <- gsub("^c\\(|\\)$", "", outliers_str) # Remove "c(" and ")"
          if (outliers_text != "") {
            outliers <- suppressWarnings(as.numeric(strsplit(outliers_text, ", ")[[1]]))
            outliers <- outliers[!is.na(outliers)] # Remove any NA values

            if (length(outliers) > 0) {
              # Split into lower and upper outliers based on whisker bounds
              lower_outliers <- outliers[outliers < stats$min]
              upper_outliers <- outliers[outliers > stats$max]

              # Ensure outliers are always arrays (even single elements)
              lower_outliers <- as.list(lower_outliers)
              upper_outliers <- as.list(upper_outliers)
            } else {
              lower_outliers <- list()
              upper_outliers <- list()
            }
          } else {
            lower_outliers <- list()
            upper_outliers <- list()
          }
        } else {
          lower_outliers <- list()
          upper_outliers <- list()
        }

        stats$lowerOutliers <- lower_outliers
        stats$upperOutliers <- upper_outliers

        boxplot_data[[i]] <- stats
      }

      # Map numeric categories to actual names if possible
      boxplot_data <- self$map_categories_to_names(boxplot_data, plot)

      # Remove the temporary y_value field
      for (i in seq_along(boxplot_data)) {
        if (!is.null(boxplot_data[[i]]$y_value)) {
          boxplot_data[[i]]$y_value <- NULL
        }
      }

      boxplot_data
    },

    #' Generate selectors for boxplot elements
    #' @param plot The ggplot2 object
    #' @param gt Gtable object (optional)
    #' @return List of selectors for each boxplot
    generate_selectors = function(plot, gt = NULL) {
      if (is.null(gt)) gt <- ggplot2::ggplotGrob(plot)

      # Locate panel
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        return(list())
      }
      panel_grob <- gt$grobs[[panel_index]]
      if (!inherits(panel_grob, "gTree")) {
        return(list())
      }

      # Helpers for traversal
      collect_children <- function(grob) {
        out <- list()
        if (inherits(grob, "gTree") && length(grob$children) > 0) {
          for (nm in names(grob$children)) {
            child <- grob$children[[nm]]
            out[[length(out) + 1]] <- child
            out <- c(out, collect_children(child))
          }
        }
        out
      }
      find_children_by_pattern <- function(grob, pattern) {
        kids <- collect_children(grob)
        ids <- vapply(kids, function(ch) if (!is.null(ch$name) && grepl(pattern, ch$name)) ch$name else NA_character_, character(1))
        ids <- ids[!is.na(ids)]
        unique(ids)
      }
      first_level_children_of <- function(grob, parent_id, pattern) {
        if (!inherits(grob, "gTree")) {
          return(character(0))
        }
        for (nm in names(grob$children)) {
          child <- grob$children[[nm]]
          if (!is.null(child$name) && child$name == parent_id && inherits(child, "gTree")) {
            ids <- character(0)
            for (cn in names(child$children)) {
              ch2 <- child$children[[cn]]
              if (!is.null(ch2$name) && grepl(pattern, ch2$name)) ids <- c(ids, ch2$name)
            }
            return(ids)
          }
          ids <- first_level_children_of(child, parent_id, pattern)
          if (length(ids) > 0) {
            return(ids)
          }
        }
        character(0)
      }
      find_descendant_of_parent_by_pattern <- function(grob, parent_id, pattern) {
        if (!inherits(grob, "gTree")) {
          return(NULL)
        }
        for (nm in names(grob$children)) {
          child <- grob$children[[nm]]
          if (!is.null(child$name) && child$name == parent_id) {
            ids <- find_children_by_pattern(child, pattern)
            return(if (length(ids) > 0) ids[1] else NULL)
          }
          res <- find_descendant_of_parent_by_pattern(child, parent_id, pattern)
          if (!is.null(res)) {
            return(res)
          }
        }
        NULL
      }
      esc <- function(id) gsub("\\.", "\\\\.", id)
      with_suffix <- function(id) {
        if (is.null(id)) {
          return(NULL)
        }
        # Already has a trailing instance suffix if it ends with .<digits>.<digits>
        if (grepl("\\.\\d+\\.\\d+$", id)) {
          return(id)
        }
        paste0(id, ".1")
      }

      # Identify master geom_boxplot container and per-box children
      all_box <- find_children_by_pattern(panel_grob, "geom_boxplot\\.gTree")
      if (length(all_box) == 0) {
        return(list())
      }
      master_id <- all_box[1]
      per_box_ids <- first_level_children_of(panel_grob, master_id, "geom_boxplot\\.gTree")
      if (length(per_box_ids) == 0) per_box_ids <- setdiff(all_box, master_id)

      # Data for outlier counts
      built <- ggplot2::ggplot_build(plot)
      layer_data <- built$data[[self$layer_info$index]]

      selectors <- vector("list", length(per_box_ids))
      for (i in seq_along(per_box_ids)) {
        box_id <- per_box_ids[i]
        box_sel <- list()

        # Outliers
        outlier_container <- find_descendant_of_parent_by_pattern(panel_grob, box_id, "geom_point\\.points")
        lower_n <- 0
        upper_n <- 0
        if (!is.null(layer_data) && nrow(layer_data) >= i) {
          row <- layer_data[i, ]
          outliers_str <- as.character(row$outliers)
          if (!is.na(outliers_str) && outliers_str != "" && outliers_str != "NA" && outliers_str != " numeric(0) ") {
            txt <- gsub("^c\\(|\\)$", "", outliers_str)
            if (nzchar(txt)) {
              vals <- suppressWarnings(as.numeric(strsplit(txt, ", ")[[1]]))
              vals <- vals[!is.na(vals)]
              if (length(vals) > 0) {
                lower_n <- sum(vals < row$xmin)
                upper_n <- sum(vals > row$xmax)
              }
            }
          }
        }
        if (!is.null(outlier_container) && lower_n > 0) {
          oc <- with_suffix(outlier_container)
          box_sel$lowerOutliers <- list(paste0("g#", esc(oc), " > use:nth-child(-n+", lower_n, ")"))
        } else {
          box_sel$lowerOutliers <- list()
        }
        if (!is.null(outlier_container) && upper_n > 0) {
          oc <- with_suffix(outlier_container)
          box_sel$upperOutliers <- list(paste0("g#", esc(oc), " > use:nth-child(n+", lower_n + 1, ")"))
        } else {
          box_sel$upperOutliers <- list()
        }

        # IQR box and median inside crossbar
        crossbar_id <- find_descendant_of_parent_by_pattern(panel_grob, box_id, "geom_crossbar\\.gTree")
        iq_id <- if (!is.null(crossbar_id)) find_descendant_of_parent_by_pattern(panel_grob, crossbar_id, "geom_polygon\\.polygon") else NULL
        med_id <- if (!is.null(crossbar_id)) find_descendant_of_parent_by_pattern(panel_grob, crossbar_id, "GRID\\.segments") else NULL
        if (!is.null(iq_id)) box_sel$iq <- paste0("g#", esc(with_suffix(iq_id)), " > polygon")
        if (!is.null(med_id)) box_sel$q2 <- paste0("g#", esc(with_suffix(med_id)), " > polyline")

        # Whiskers (another GRID.segments under box)
        whisker_id <- find_descendant_of_parent_by_pattern(panel_grob, box_id, "GRID\\.segments")
        if (!is.null(whisker_id) && !is.null(med_id) && whisker_id == med_id) {
          direct_segments <- first_level_children_of(panel_grob, box_id, "GRID\\.segments")
          if (length(direct_segments) > 0) {
            alt <- setdiff(direct_segments, med_id)
            whisker_id <- if (length(alt) > 0) alt[1] else direct_segments[1]
          }
        }
        if (!is.null(whisker_id)) {
          wid <- with_suffix(whisker_id)
          box_sel$min <- paste0("g#", esc(wid), " > polyline:nth-child(2)")
          box_sel$max <- paste0("g#", esc(wid), " > polyline:nth-child(1)")
        }

        selectors[[i]] <- box_sel
      }

      selectors
    },

    #' Determine if the boxplot is horizontal or vertical
    #' @param plot The ggplot2 object
    #' @return "horz" or "vert"
    determine_orientation = function(plot) {
      # Build the plot to examine the structure
      built <- ggplot2::ggplot_build(plot)
      layer_data <- built$data[[self$layer_info$index]]

      # Check if y values in built data are numeric codes (indicating categorical y-axis)
      # For horizontal boxplots, y contains numeric codes (1, 2, 3, etc.)
      # For vertical boxplots, y is empty or contains the continuous values
      if ("y" %in% names(layer_data)) {
        y_values <- layer_data$y
        if (length(y_values) > 0 && all(y_values %in% 1:10)) {
          # y contains small integers (1, 2, 3, etc.) - likely categorical codes
          return("horz")
        }
      }

      # Check if x values in built data indicate categorical x-axis
      if ("x" %in% names(layer_data)) {
        x_values <- layer_data$x
        if (length(x_values) > 0 && all(x_values %in% 1:10)) {
          # x contains small integers - likely categorical codes for vertical boxplot
          return("vert")
        }
      }

      # Check layer mapping
      layer_mapping <- plot$layers[[self$layer_info$index]]$mapping

      # If y is mapped and x is not explicitly continuous, check y data
      if (!is.null(layer_mapping$y) && is.null(layer_mapping$x)) {
        y_var_name <- rlang::as_name(layer_mapping$y)
        y_data <- plot$data[[y_var_name]]
        if (is.factor(y_data) || is.character(y_data) || length(unique(y_data)) <= 10) {
          return("horz")
        }
      }

      # If x is mapped and y is not explicitly continuous, check x data
      if (!is.null(layer_mapping$x) && is.null(layer_mapping$y)) {
        x_var_name <- rlang::as_name(layer_mapping$x)
        x_data <- plot$data[[x_var_name]]
        if (is.factor(x_data) || is.character(x_data) || length(unique(x_data)) <= 10) {
          return("vert")
        }
      }

      # Default to vertical
      "vert"
    },

    #' Map numeric category codes to actual category names
    #' Uses panel_params axis labels from ggplot_build to map codes to labels
    #' @param boxplot_data List of boxplot statistics
    #' @param plot The ggplot2 object
    #' @return Updated boxplot data with proper category names
    map_categories_to_names = function(boxplot_data, plot) {
      built <- ggplot2::ggplot_build(plot)
      panel_params <- built$layout$panel_params[[1]]
      layer_index <- self$get_layer_index()
      layer_data <- built$data[[layer_index]]
      orientation <- self$determine_orientation(plot)

      get_axis_labels <- function(pp_axis) {
        if (is.null(pp_axis)) {
          return(character(0))
        }
        if (!is.null(pp_axis$labels)) {
          return(as.character(pp_axis$labels))
        }
        if (!is.null(pp_axis$breaks)) {
          return(as.character(pp_axis$breaks))
        }
        character(0)
      }

      if (orientation == "horz") {
        labels <- get_axis_labels(panel_params$y)
        codes <- if ("y" %in% names(layer_data)) layer_data$y else NULL
      } else {
        labels <- get_axis_labels(panel_params$x)
        codes <- if ("x" %in% names(layer_data)) layer_data$x else NULL
      }

      if (!is.null(codes) && length(labels) > 0) {
        for (i in seq_along(boxplot_data)) {
          idx <- suppressWarnings(as.integer(round(codes[i])))
          if (!is.na(idx) && idx >= 1 && idx <= length(labels)) {
            boxplot_data[[i]]$fill <- as.character(labels[idx])
          }
        }
      }

      boxplot_data
    },

    #' Find the main panel grob
    #' @param gt The gtable to search
    #' @return The panel grob or NULL
    find_panel_grob = function(gt) {
      panel_index <- which(gt$layout$name == "panel")
      if (length(panel_index) == 0) {
        return(NULL)
      }

      panel_grob <- gt$grobs[[panel_index]]
      if (!inherits(panel_grob, "gTree")) {
        return(NULL)
      }

      panel_grob
    },

    #' Find children by type pattern
    #' @param grob The grob to search
    #' @param type_pattern Pattern to match
    #' @return List of matching children
    find_children_by_type = function(grob, type_pattern) {
      children <- list()

      if (inherits(grob, "gTree")) {
        for (i in seq_along(grob$children)) {
          child <- grob$children[[i]]
          if (!is.null(child$name) && grepl(type_pattern, child$name)) {
            children[[length(children) + 1]] <- child$name
          }
        }
      }

      children
    },

    #' Find the outlier container within a boxplot
    #' @param gt The gtable object
    #' @param boxplot_id The boxplot container ID
    #' @return The outlier container ID or NULL
    find_outlier_container = function(gt, boxplot_id) {
      # Look for geom_point container within the boxplot
      self$find_child_by_pattern(gt, boxplot_id, "geom_point")
    },

    #' Find the box container within a boxplot
    #' @param gt The gtable object
    #' @param boxplot_id The boxplot container ID
    #' @return The box container ID or NULL
    find_box_container = function(gt, boxplot_id) {
      # Look for geom_polygon container within the boxplot
      self$find_child_by_pattern(gt, boxplot_id, "geom_polygon")
    },

    #' Find the whisker container within a boxplot
    #' @param gt The gtable object
    #' @param boxplot_id The boxplot container ID
    #' @return The whisker container ID or NULL
    find_whisker_container = function(gt, boxplot_id) {
      # Look for GRID.segments container within the boxplot
      self$find_child_by_pattern(gt, boxplot_id, "GRID\\.segments")
    },

    #' Find the median container within a boxplot
    #' @param gt The gtable object
    #' @param boxplot_id The boxplot container ID
    #' @return The median container ID or NULL
    find_median_container = function(gt, boxplot_id) {
      # Look for GRID.segments container within the boxplot (same as whiskers)
      self$find_child_by_pattern(gt, boxplot_id, "GRID\\.segments")
    },

    #' Find a child element by pattern within a container
    #' @param gt The gtable object
    #' @param container_id The container ID to search within
    #' @param pattern Pattern to match
    #' @return The matching child ID or NULL
    find_child_by_pattern = function(gt, container_id, pattern) {
      # This is a simplified implementation
      # In practice, we'd need to traverse the grob tree structure
      # For now, return a constructed ID based on common patterns
      paste0(container_id, ".1")
    }
  )
)
