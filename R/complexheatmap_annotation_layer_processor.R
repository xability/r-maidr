#' The name the cells of one slice of a ComplexHeatmap annotation track are
#' exported under
#'
#' `anno_simple()` draws the cells of a track, in each slice of the heat
#' map, as one rect grob with a generated name. Each is renamed to this
#' prefix followed by `-<h>-<t>-<k>`: the heat map's place among those
#' read, the track's place among that heat map's tracks, and the slice, so
#' each cell is the SVG element
#' `#maidr-complexheatmap-annotation-<h>-<t>-<k>.1.<i>`.
#'
#' @keywords internal
COMPLEXHEATMAP_ANNOTATION_GROB <- "maidr-complexheatmap-annotation"

#' Which heat map each annotation a list holds belongs to
#'
#' An annotation added to a list with `+` or `%v%` (`ht1 + rowAnnotation(...)
#' + ht2`) is drawn between heat maps and annotates the rows (or columns)
#' they share. It is read with the heat map read before it in the list, or,
#' when none is, the first read after it.
#'
#' @param drawn The `HeatmapList` the draw returned
#' @param read The positions in `drawn@ht_list` of the heat maps read
#' @return One entry per heat map read, a list of `before` and `after`, the
#'   annotations it owns that are drawn before and after it
#' @keywords internal
complexheatmap_member_annotations <- function(drawn, read) {
  members <- drawn@ht_list
  owned <- lapply(read, function(r) list(before = list(), after = list()))
  for (p in seq_along(members)) {
    if (!inherits(members[[p]], "HeatmapAnnotation")) {
      next
    }
    preceding <- which(read < p)
    if (length(preceding)) {
      owner <- max(preceding)
      owned[[owner]]$after <- c(owned[[owner]]$after, list(members[[p]]))
    } else if (length(read)) {
      owned[[1]]$before <- c(owned[[1]]$before, list(members[[p]]))
    }
  }
  owned
}

#' The simple annotation tracks drawn beside a ComplexHeatmap heat map
#'
#' A track is one `SingleAnnotation` drawn by `anno_simple()` -- what
#' `HeatmapAnnotation(df = ...)`, `rowAnnotation(df = ...)`, a bare vector
#' (`HeatmapAnnotation(type = x)`) and `anno_simple(x)` all make -- holding
#' one value per column (a column annotation) or per row (a row
#' annotation) of the matrix. They are taken from the heat map's own
#' `top_annotation`, `bottom_annotation`, `left_annotation` and
#' `right_annotation`, and from the annotations of a list it owns
#' ([complexheatmap_member_annotations()]): column tracks first, top to
#' bottom, then row tracks, left to right, each annotation's tracks in the
#' order drawn.
#'
#' Any other annotation -- `anno_barplot()`, `anno_points()`, `anno_text()`,
#' `anno_mark()` and the like, or an `anno_simple()` of a matrix -- is drawn
#' and not read; its name is returned in `unread`.
#'
#' @param heatmap The `Heatmap`, as drawn
#' @param members The list's annotations it owns, `before` and `after` it
#' @return A list: `tracks`, each a list with `name` (the annotation's
#'   name), `owner` (the name of the heat map, or list annotation, whose
#'   viewport it is drawn in), `label` (what it is called on the chart),
#'   `which` (`"column"` or `"row"`), `annotation` (the `SingleAnnotation`)
#'   and `values` (one per matrix column or row, in the matrix's order);
#'   and `unread`, the names of the annotations not read
#' @keywords internal
complexheatmap_annotation_tracks <- function(heatmap, members = list()) {
  beside <- function(which, side) {
    Filter(function(m) identical(m@which, which), members[[side]] %||% list())
  }
  slot_annotation <- function(name) {
    annotation <- methods::slot(heatmap, name)
    if (inherits(annotation, "HeatmapAnnotation")) list(annotation) else list()
  }
  own <- function(annotations) lapply(annotations, function(a) list(a, heatmap@name))
  list_owned <- function(annotations) lapply(annotations, function(a) list(a, a@name))
  annotations <- c(
    list_owned(beside("column", "before")), own(slot_annotation("top_annotation")),
    own(slot_annotation("bottom_annotation")), list_owned(beside("column", "after")),
    list_owned(beside("row", "before")), own(slot_annotation("left_annotation")),
    own(slot_annotation("right_annotation")), list_owned(beside("row", "after"))
  )

  tracks <- list()
  unread <- character(0)
  for (entry in annotations) {
    annotation <- entry[[1]]
    which <- annotation@which
    n <- if (identical(which, "column")) ncol(heatmap@matrix) else nrow(heatmap@matrix)
    for (single in annotation@anno_list) {
      value <- complexheatmap_simple_value(single, n)
      if (is.null(value)) {
        unread <- c(unread, single@name)
        next
      }
      tracks[[length(tracks) + 1L]] <- list(
        name = single@name,
        owner = entry[[2]],
        label = complexheatmap_title(single@label, single@name),
        which = which,
        annotation = single,
        values = value
      )
    }
  }
  list(tracks = tracks, unread = unread)
}

#' The values of a simple annotation, if it is one
#'
#' @param single A `SingleAnnotation`
#' @param n The number of matrix columns or rows it annotates
#' @return Its vector of values, one per column or row, or NULL when it is
#'   not an `anno_simple()` of a vector of that length with a colour mapping
#' @keywords internal
complexheatmap_simple_value <- function(single, n) {
  fun <- single@fun
  if (!inherits(fun, "AnnotationFunction") || !identical(fun@fun_name, "anno_simple")) {
    return(NULL)
  }
  value <- fun@var_env$value
  mapping <- fun@var_env$color_mapping
  if (!is.atomic(value) || is.matrix(value) || length(value) != n ||
    !inherits(mapping, "ColorMapping")) {
    return(NULL)
  }
  value
}

#' The colour mapping a simple annotation track is drawn with
#'
#' The one `anno_simple()` keeps, which `HeatmapAnnotation()` also records
#' on the `SingleAnnotation` for a track made from a vector, and does not
#' for an `anno_simple()` passed in.
#'
#' @param track A track, from [complexheatmap_annotation_tracks()]
#' @return A `ColorMapping`
#' @keywords internal
complexheatmap_track_mapping <- function(track) {
  track$annotation@fun@var_env$color_mapping
}

#' Give the cells of each annotation track names the selectors can rely on
#'
#' `anno_simple()` draws each slice of a track in a viewport named
#' `annotation_<name>_<k>`, `k` the slice in drawn order, inside the
#' viewport `heatmap_<owner>` of the heat map or list annotation it belongs
#' to, as one rect: a
#' column track's cells left to right, a row track's top to bottom, each at
#' the middle of an even grid. A slice's rect is renamed only when that is
#' what it is: one rect per cell, at those places, each filled with the
#' colour the track's colour mapping gives the cell's value. A track drawn
#' otherwise -- runs of one level merged into one rect, which
#' `anno_simple()` does for a discrete track given a `gp` without `col` --
#' or one whose name another track of the same owner also has, so its
#' viewports cannot be told apart, is read without highlighting.
#'
#' @param grob The gTree the drawing was grabbed as
#' @param tracks The tracks, from [complexheatmap_annotation_tracks()]
#' @param heatmap The `Heatmap` drawn, its row and column order set
#' @param h The heat map's place among those read, for the names given
#' @return A list: `grob`, with the cells renamed; `cells`, one entry per
#'   track, a list of the names given by slice, or NULL when the track's
#'   cells cannot be selected
#' @keywords internal
complexheatmap_name_annotations <- function(grob, tracks, heatmap, h = 1L) {
  kids <- grob$children[grob$childrenOrder]
  paths <- vapply(kids, function(kid) {
    vp <- kid$vp
    if (inherits(kid, "rect") && inherits(vp, "vpPath") && !is.null(vp$path)) {
      as.character(vp$path)
    } else {
      ""
    }
  }, character(1))
  parents <- sub("^.*::", "", paths)
  names <- vapply(tracks, function(track) paste(track$owner, track$name), character(1))
  claimed <- logical(length(kids))
  cells <- vector("list", length(tracks))
  for (t in seq_along(tracks)) {
    track <- tracks[[t]]
    if (sum(names == names[t]) != 1L) {
      next
    }
    within <- grepl(paste0("::heatmap_", track$owner, "::"), paths, fixed = TRUE)
    slices <- if (identical(track$which, "column")) heatmap@column_order_list else heatmap@row_order_list
    found <- character(0)
    for (k in seq_along(slices)) {
      index <- slices[[k]]
      fills <- ComplexHeatmap::map_to_colors(complexheatmap_track_mapping(track), track$values[index])
      at <- which(!claimed & within & parents == paste0("annotation_", track$name, "_", k))
      at <- Filter(function(i) complexheatmap_rect_is_track(kids[[i]], fills, track$which), at)
      if (length(at) == 0L) {
        break
      }
      name <- paste(COMPLEXHEATMAP_ANNOTATION_GROB, h, t, k, sep = "-")
      kids[[at[1]]]$name <- name
      claimed[at[1]] <- TRUE
      found <- c(found, name)
    }
    if (length(found) == length(slices)) {
      cells[[t]] <- as.list(found)
    }
  }
  if (any(claimed)) {
    grob <- grid::setChildren(grob, do.call(grid::gList, unname(kids)))
  }
  list(grob = grob, cells = cells)
}

#' Whether a rect grob is the cells of one slice of an annotation track
#'
#' @param rect A rect grob
#' @param fills The colour of each cell, in drawn order
#' @param which `"column"`, cells left to right, or `"row"`, top to bottom
#' @return TRUE when the rect draws one cell per colour, at the middles of
#'   an even grid, filled with those colours
#' @keywords internal
complexheatmap_rect_is_track <- function(rect, fills, which) {
  n <- length(fills)
  position <- if (identical(which, "column")) rect$x else rect$y
  if (n == 0L || length(position) != n || length(rect$gp$fill) != n ||
    !all(grid::unitType(position) == "npc")) {
    return(FALSE)
  }
  middles <- (seq_len(n) - 0.5) / n
  if (!identical(which, "column")) {
    middles <- rev(middles)
  }
  isTRUE(all.equal(as.numeric(position), middles)) &&
    identical(
      grDevices::col2rgb(rect$gp$fill, alpha = TRUE),
      grDevices::col2rgb(fills, alpha = TRUE)
    )
}

#' ComplexHeatmap Annotation Layer Processor
#'
#' @description
#' Reads one simple annotation track of a ComplexHeatmap heat map
#' ([complexheatmap_annotation_tracks()]) as a layer of the heat map's
#' subplot, beside its `heat` layer, named by the annotation (`name`).
#'
#' **Shape.** Every track is read as a row of its own, one cell per column
#' (a column annotation) or per row (a row annotation) of the heat layer,
#' in the order the heat layer reads them: clustered, reordered and split
#' as drawn, a row track top first. Its `x` labels are the heat layer's
#' column or row labels, so moving between the heat layer and a column
#' track keeps the column.
#'
#' - A track mapped to a continuous colour scale is a 1-row `heat` layer:
#'   `y` is the track's name, `points` its values, exactly; a missing value
#'   is a hole (`null`).
#' - A track mapped to discrete colours (characters, factors, logicals, or
#'   numbers given discrete colours) is a `step` layer of one series, one
#'   point per cell: `x` its label, `y` the level's place among the colour
#'   mapping's levels (1, 2, ...), and `label` the level, which maidr.js
#'   announces in place of `y`. A missing value is `y: null` without a
#'   `label`. maidr.js's `heat` cell is a number only, so a level can be
#'   announced only by a trace that carries a name beside its number.
#'
#' **Selectors.** Each cell is the rect it is drawn as
#' ([complexheatmap_name_annotations()]): for `heat`, a one-row grid; for
#' `step`, one selector matching every cell in drawn order. A track whose
#' cells cannot be told apart is read without highlighting.
#'
#' @keywords internal
ComplexHeatmapAnnotationLayerProcessor <- R6::R6Class(
  "ComplexHeatmapAnnotationLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Read the layer
    #' @param plot The `Heatmap` or `HeatmapList` passed in
    #' @param layout The figure's layout: its title and its rows' title
    #' @param built Unused
    #' @param gt The capture, from [complexheatmap_capture()]
    #' @param grob_id Unused
    #' @param panel_id Unused
    #' @param panel_ctx Unused
    #' @param layer_info Unused; the track is the processor's `layer_info`
    #' @return The layer
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      track <- self$layer_info$track
      row_title <- layout$row_title %||% ""
      along <- if (identical(track$which, "column")) {
        "Columns"
      } else if (nzchar(row_title)) {
        row_title
      } else {
        "Rows"
      }
      categorical <- self$is_categorical()
      list(
        type = if (categorical) "step" else "heat",
        name = track$label,
        data = self$extract_data(plot, gt),
        selectors = self$generate_selectors(plot, gt),
        title = layout$title %||% "",
        axes = if (categorical) {
          build_axes(x = along, y = track$label)
        } else {
          build_axes(x = along, y = "Annotation", z = track$label)
        }
      )
    },

    #' @description Whether the track's colours are discrete levels
    #' @return Logical
    is_categorical = function() {
      !identical(complexheatmap_track_mapping(self$layer_info$track)@type, "continuous")
    },

    #' @description The track's cells, in the heat layer's order
    #' @param plot The `Heatmap` or `HeatmapList` passed in
    #' @param built The capture, from [complexheatmap_capture()]
    #' @return For `heat`, a list with `x`, `y` and `points`; for `step`, a
    #'   list of one series of points
    extract_data = function(plot, built = NULL) {
      track <- self$layer_info$track
      heatmap <- built$heatmap
      labeller <- ComplexHeatmapLayerProcessor$new(NULL)
      if (identical(track$which, "column")) {
        order <- unlist(heatmap@column_order_list, use.names = FALSE)
        labels <- labeller$labels(heatmap@column_names_param, colnames(heatmap@matrix), order)
      } else {
        order <- unlist(heatmap@row_order_list, use.names = FALSE)
        labels <- labeller$labels(heatmap@row_names_param, rownames(heatmap@matrix), order)
      }
      values <- track$values[order]

      if (!self$is_categorical()) {
        values <- as.double(values)
        values[!is.finite(values)] <- NA_real_
        return(list(
          x = as.list(labels),
          y = list(track$label),
          points = list(as.list(values))
        ))
      }
      levels <- as.character(complexheatmap_track_mapping(track)@levels)
      values <- as.character(values)
      codes <- match(values, levels)
      list(lapply(seq_along(values), function(i) {
        point <- list(x = labels[i], y = codes[i])
        if (!is.na(codes[i])) {
          point$label <- values[i]
        }
        point
      }))
    },

    #' @description The selectors of the track's cells
    #' @param plot The `Heatmap` or `HeatmapList` passed in
    #' @param gt The capture, from [complexheatmap_capture()]
    #' @param grob_id Unused
    #' @param panel_ctx Unused
    #' @return For `heat`, a one-row grid; for `step`, a list of one
    #'   selector; an empty list when the cells cannot be selected
    generate_selectors = function(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL) {
      cells <- self$layer_info$cells
      if (is.null(cells)) {
        return(list())
      }
      track <- self$layer_info$track
      slices <- if (identical(track$which, "column")) {
        gt$heatmap@column_order_list
      } else {
        gt$heatmap@row_order_list
      }
      if (self$is_categorical()) {
        return(list(paste(
          vapply(cells, lattice_grob_selector, character(1), element = "rect"),
          collapse = ", "
        )))
      }
      list(unlist(lapply(seq_along(slices), function(k) {
        lapply(seq_along(slices[[k]]), function(i) lattice_shape_selector(cells[[k]], i))
      }), recursive = FALSE))
    }
  )
)

#' Read one ComplexHeatmap heat map's simple annotation tracks
#'
#' Finds the tracks ([complexheatmap_annotation_tracks()]), names their
#' cells in the drawing ([complexheatmap_name_annotations()]) and reads each
#' as a layer ([ComplexHeatmapAnnotationLayerProcessor]), for the heat
#' map's own subplot after its `heat` layer.
#'
#' @param plot The `Heatmap` or `HeatmapList` passed in
#' @param view The capture, from [complexheatmap_capture()], its `heatmap`
#'   the one whose tracks are read
#' @param layout The heat map's layout: its title and its rows' title
#' @param first The index the first track's layer is given
#' @param members The list's annotations the heat map owns
#'   ([complexheatmap_member_annotations()])
#' @param h The heat map's place among those read
#' @return A list: `grob`, the drawing with the tracks' cells renamed;
#'   `layers`, the layers read; `processors`, their processors; `unread`,
#'   the names of the annotations drawn and not read
#' @keywords internal
complexheatmap_read_annotations <- function(plot, view, layout, first,
                                            members = list(), h = 1L) {
  found <- complexheatmap_annotation_tracks(view$heatmap, members)
  named <- complexheatmap_name_annotations(view$grob, found$tracks, view$heatmap, h)
  view$grob <- named$grob
  layers <- list()
  processors <- list()
  for (t in seq_along(found$tracks)) {
    info <- list(
      index = first + t - 1L, type = "annotation",
      track = found$tracks[[t]], cells = named$cells[[t]]
    )
    processor <- ComplexHeatmapAnnotationLayerProcessor$new(info)
    result <- processor$process(plot, layout, gt = view)
    processor$set_last_result(result)
    validate_axes(result$axes, context = "ComplexHeatmap annotation")
    layers[[t]] <- list(
      id = paste0("maidr-layer-", info$index),
      selectors = result$selectors,
      type = result$type,
      name = result$name,
      data = result$data,
      title = result$title,
      axes = result$axes
    )
    processors[[t]] <- processor
  }
  list(grob = named$grob, layers = layers, processors = processors, unread = found$unread)
}

#' Say which annotations of a ComplexHeatmap chart are drawn and not read
#'
#' A message of class `maidr_complexheatmap_annotation` naming them, or none.
#'
#' @param unread The names of the annotations not read
#' @return NULL (invisible)
#' @keywords internal
complexheatmap_inform_unread <- function(unread) {
  unread <- unique(unread)
  if (length(unread) == 0L) {
    return(invisible(NULL))
  }
  one <- length(unread) == 1L
  rlang::inform(
    paste0(
      "maidr: ComplexHeatmap ", if (one) "annotation " else "annotations ",
      paste0("'", unread, "'", collapse = ", "), if (one) " is" else " are",
      " drawn but not read; only simple annotations (one value per ",
      "row or column, as `anno_simple()` draws) are read."
    ),
    class = "maidr_complexheatmap_annotation"
  )
  invisible(NULL)
}
