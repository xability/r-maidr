#' Series-Group Helpers
#'
#' A layer whose grouping aesthetic is mapped (for example
#' \code{aes(colour = g)}) draws one curve per group. MAIDR describes that as
#' one series per group, each point carrying the group's name as \code{z}, and
#' names those values with the legend title as the z axis label. These helpers
#' are shared by the ggplot2 line and smooth layer processors so that a grouped
#' \code{geom_line()} and a grouped \code{geom_smooth()} are described the same
#' way.
#'
#' @name series_group_utils
#' @keywords internal
NULL

#' Resolve the aesthetic that splits a layer into series
#'
#' Mirrors ggplot2's precedence: the layer's own mapping wins over the
#' plot-level one. ggplot2 normalises \code{color} to \code{colour}, but both
#' spellings are probed defensively.
#'
#' @param plot The ggplot2 object
#' @param layer_index Index of the layer whose mapping takes precedence, or
#'   NULL to consult only the plot-level mapping
#' @param aes_groups List of aesthetic-name vectors, probed in order. Each
#'   element must hold spelling variants of ONE aesthetic (for example
#'   \code{c("colour", "color")}), never unrelated aesthetics: the winning
#'   element is handed to \code{resolve_legend_label()}, which documents that
#'   contract.
#' @return list with \code{aes} (the winning spelling variants, or NULL when
#'   nothing is mapped) and \code{column} (the mapped column name, or
#'   "group" as a fallback)
#' @keywords internal
resolve_series_group_mapping <- function(plot, layer_index = NULL,
                                         aes_groups = list(c("colour", "color"))) {
  mappings <- list()
  if (!is.null(layer_index) && length(plot$layers) >= layer_index) {
    mappings[[length(mappings) + 1L]] <- plot$layers[[layer_index]]$mapping
  }
  mappings[[length(mappings) + 1L]] <- plot$mapping

  for (mapping in mappings) {
    if (is.null(mapping)) next
    for (aes_names in aes_groups) {
      for (aes_name in aes_names) {
        quo <- mapping[[aes_name]]
        if (!is.null(quo)) {
          return(list(aes = aes_names, column = rlang::as_label(quo)))
        }
      }
    }
  }
  list(aes = NULL, column = "group")
}

#' Report whether extracted layer data is split into named series
#'
#' @param data The extracted layer data (a list of series)
#' @return TRUE when there is more than one series and points carry z
#' @keywords internal
data_has_series_groups <- function(data) {
  if (!is.list(data) || length(data) < 2L) {
    return(FALSE)
  }
  first_series <- data[[1]]
  if (!is.list(first_series) || length(first_series) == 0L) {
    return(FALSE)
  }
  !is.null(first_series[[1]]$z)
}

#' Name each series after the category its built group id stands for
#'
#' \code{ggplot_build()} replaces the grouping column with integer group ids,
#' so the user-facing name has to be recovered from the plot's own data. The
#' ids are assigned in the sorted order of the grouping column's values, which
#' is the order this function relies on. Falls back to "Series <id>" when the
#' mapped column is not present on the plot data (for example an expression
#' such as \code{aes(colour = paste(a, b))}).
#'
#' @param plot The ggplot2 object
#' @param group_ids The layer's built \code{group} column
#' @param column Name of the mapped grouping column
#' @return Character vector, one name per distinct group id in ascending order
#' @keywords internal
resolve_series_group_names <- function(plot, group_ids, column = "group") {
  unique_groups <- sort(unique(group_ids))
  original <- plot$data
  categories <- if (is.data.frame(original) && column %in% names(original)) {
    sort(unique(original[[column]]))
  } else {
    NULL
  }

  vapply(seq_along(unique_groups), function(i) {
    if (!is.null(categories) && i <= length(categories)) {
      as.character(categories[[i]])
    } else {
      paste0("Series ", unique_groups[[i]])
    }
  }, character(1))
}

#' Add the legend title as the z axis label for a grouped layer
#'
#' A grouped layer emits a per-series \code{z} value (the group's name), and
#' MAIDR announces it as "<z label> is <z value>". Without a z label the
#' frontend falls back to the generic word "Group", losing the legend title the
#' plot actually shows. Single-series layers emit no z value at all, so they
#' get no z label either.
#'
#' @param axes Axes built so far
#' @param plot The ggplot2 object
#' @param built Built plot data (optional)
#' @param data The extracted layer data
#' @param layer_index Index of the layer being described
#' @param aes_groups Grouping aesthetics to probe, as documented on
#'   \code{resolve_series_group_mapping()}
#' @return The axes list, with z added when the layer is grouped
#' @keywords internal
attach_series_group_axis <- function(axes, plot, built, data, layer_index = NULL,
                                     aes_groups = list(c("colour", "color"))) {
  if (!data_has_series_groups(data)) {
    return(axes)
  }
  group <- resolve_series_group_mapping(plot, layer_index, aes_groups)
  if (is.null(group$aes)) {
    return(axes)
  }
  label <- resolve_legend_label(
    plot,
    built = built,
    aes_names = group$aes,
    layer_index = layer_index
  )
  if (!is.null(label) && nzchar(label)) {
    axes$z <- list(label = label)
  }
  axes
}
