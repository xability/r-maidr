#' SVG export on svglite
#'
#' Turns the grid scene on the current device into the SVG document maidr
#' ships. svglite draws every shape, so what reaches the browser is what R's
#' graphics engine drew; this file only gives that output the document shape
#' every selector in the package -- and every copy of maidr.js already
#' installed -- is written against. That shape is the one gridSVG produced,
#' which maidr exported with until svglite replaced it:
#'
#' * each grob is a `<g id="<name>.<k>">`, `<k>` counting how often the same
#'   name was drawn before, and each of its shapes carries
#'   `<name>.<k>.<i>`, `<i>` being the shape's position within the grob
#'   (lettered `a`, `b`, ... when a missing value breaks one line into
#'   pieces);
#' * each viewport pushed is a `<g>` named by its viewport path, so nesting
#'   and `:nth-child()` positions are those of the grob tree;
#' * the page is drawn under `translate(0, H) scale(1, -1)`, so coordinates
#'   in attributes grow upward from the bottom edge, as the violin, box and
#'   candlestick code here and in maidr.js expect;
#' * points are `<use>` references to one `<symbol>` per plotting character;
#' * paint is set with presentation attributes (`fill="rgb(...)"`), never a
#'   stylesheet or `style`, so the highlight maidr.js paints on a clone wins.
#'
#' How it works: the scene is forced and grabbed off the display list, then
#' walked the way gridSVG walked it -- same traversal, same names -- while
#' each grob is drawn again onto a fresh svglite page. Before each drawing
#' call the walk draws an invisible text marker whose label indexes the
#' walk's record of what the following shapes belong to; the markers are
#' read back and removed when svglite's output is rewritten.
#'
#' @noRd
NULL

# Label of the invisible text drawn before each batch of walk events.
svg_marker_prefix <- "@@maidr-svg-mark@@"

# The generic font stacks gridSVG wrote, so a reader's browser falls back to
# a font of the right kind rather than its default serif.
svg_font_stacks <- list(
  sans = "Helvetica, Arial, FreeSans, Liberation Sans, Nimbus Sans L, sans-serif",
  serif = "Times, Times New Roman, Liberation Serif, Nimbus Roman No9 L Regular, serif",
  mono = "Courier, Courier New, Nimbus Mono L, monospace"
)

#' Open the svglite page a chart is drawn on
#'
#' @param width,height Page size in inches.
#' @return A function returning the page's SVG once the device is closed.
#' @keywords internal
open_svg_device <- function(width, height) {
  svglite::svgstring(
    width = width,
    height = height,
    bg = "transparent",
    pointsize = 12,
    standalone = TRUE,
    fix_text_size = FALSE
  )
}

#' Export the grid scene on the current (svglite) device
#'
#' Must be called with the chart already drawn on a device opened by
#' [open_svg_device()]. Closes that device.
#'
#' @param svg_string The function [open_svg_device()] returned.
#' @param width,height Page size in inches.
#' @return Character vector of SVG lines.
#' @keywords internal
export_svg_scene <- function(svg_string, width, height) {
  dev <- grDevices::dev.cur()
  # Resolved once per session, and it opens a device of its own: never in
  # the middle of the walk.
  svg_font_aliases()
  on.exit(
    if (dev %in% grDevices::dev.list()) grDevices::dev.off(dev),
    add = TRUE
  )

  # The scene exactly as gridSVG took it: high-level grobs forced to their
  # drawn content, every viewport operation on the display list kept.
  grDevices::dev.hold()
  grid::grid.force()
  grDevices::dev.flush()
  grid::upViewport(0, recording = FALSE)
  scene <- grid::grid.grab(name = "gridSVG", wrap = TRUE, gp = grid::get.gpar())

  walk <- walk_svg_scene(scene)
  grDevices::dev.off(dev)
  doc <- build_svg_document(walk, utils::tail(svg_string(), 1L), width * 72, height * 72)

  # A rect or circle grob is drawn in one call on the assumption that each
  # element gives exactly one shape. Should that ever not hold, the shapes
  # would be numbered wrongly, so walk again drawing them one at a time.
  if (isTRUE(attr(doc, "run_mismatch"))) {
    svg_string <- open_svg_device(width, height)
    dev <- grDevices::dev.cur()
    walk <- walk_svg_scene(scene, one_at_a_time = TRUE)
    grDevices::dev.off(dev)
    doc <- build_svg_document(walk, utils::tail(svg_string(), 1L), width * 72, height * 72)
  }
  attr(doc, "run_mismatch") <- NULL
  doc
}

#' Walk a grabbed scene, redrawing it with batch markers
#' @param scene The gTree `grid.grab()` returned.
#' @param one_at_a_time Draw rect and circle grobs one element at a time.
#' @return The walk state (events per marker, symbol use).
#' @keywords internal
walk_svg_scene <- function(scene, one_at_a_time = FALSE) {
  st <- new.env(parent = emptyenv())
  st$one_at_a_time <- one_at_a_time
  st$batches <- vector("list", 256L)
  st$nbatch <- 0L
  st$pending <- list()
  st$usage <- new.env(parent = emptyenv(), hash = TRUE)
  st$gps <- list()
  st$pch <- integer(0)

  grid::grid.newpage(recording = FALSE)
  svg_walk_grob(scene, st)
  # Events after the last shape need no marker; they close the document.
  svg_flush(st, draw = FALSE)
  st$batches <- st$batches[seq_len(st$nbatch)]
  st
}

# -- walk --------------------------------------------------------------------

svg_event <- function(st, ev) {
  st$pending[[length(st$pending) + 1L]] <- ev
}

#' Close the pending batch, drawing its marker when shapes follow
#' @keywords internal
svg_flush <- function(st, draw = TRUE) {
  if (!length(st$pending)) {
    return(invisible())
  }
  k <- st$nbatch + 1L
  if (k > length(st$batches)) {
    length(st$batches) <- 2L * length(st$batches)
  }
  st$batches[[k]] <- st$pending
  st$nbatch <- k
  st$pending <- list()
  if (draw) {
    grid::grid.draw(
      grid::textGrob(
        paste0(svg_marker_prefix, k),
        x = 0, y = 0, just = c("left", "bottom"),
        gp = grid::gpar(
          col = NA, fontsize = 1, cex = 1, alpha = 1,
          fontfamily = "", fontface = 1, lineheight = 1
        ),
        name = "maidr.svg.marker"
      ),
      recording = FALSE
    )
  }
  invisible()
}

#' gridSVG's element id: `<name>.<k>`, `<k>` one more than the name's uses
#' @keywords internal
svg_get_id <- function(name, st) {
  u <- st$usage
  suffix <- if (exists(name, envir = u, inherits = FALSE)) {
    get(name, envir = u, inherits = FALSE) + 1L
  } else {
    1L
  }
  # A grob literally named like an earlier id ("rect.1") must not take it.
  while (exists(paste0(name, ".", suffix), envir = u, inherits = FALSE)) {
    suffix <- suffix + 1L
  }
  assign(name, suffix, envir = u)
  paste0(name, ".", suffix)
}

svg_start_vp_group <- function(st) {
  path <- as.character(grid::current.vpPath())
  name <- paste(grid::explode(path), collapse = "::")
  gp <- grid::current.viewport()$gp
  svg_event(st, list(
    t = "go", id = svg_get_id(name, st),
    attrs = svg_gp_attrs(grid::get.gpar(), names(gp))
  ))
}

svg_enforce_vp <- function(vp, st) {
  if (is.null(vp)) {
    return(0L)
  }
  if (!inherits(vp, "vpPath")) {
    grid::pushViewport(vp, recording = FALSE)
    depth <- grid::depth(vp)
  } else {
    depth <- grid::downViewport(vp, recording = FALSE)
  }
  if (depth > 1) {
    path <- grid::upViewport(depth - 1, recording = FALSE)
    for (step in grid::explode(path)) {
      svg_start_vp_group(st)
      grid::downViewport(step, recording = FALSE)
    }
  }
  svg_start_vp_group(st)
  depth
}

svg_unwind_vp <- function(depth, st) {
  if (depth > 0) {
    for (i in seq_len(depth)) svg_event(st, list(t = "gc"))
    grid::upViewport(depth, recording = FALSE)
  }
}

svg_walk_grob <- function(x, st) {
  if (inherits(x, "recordedGrob")) {
    x <- x$list
    if (!is.null(x$vp)) {
      svg_enforce_vp(x$vp, st)
    } else if (!is.null(x$path)) {
      svg_enforce_vp(x$path, st)
    } else if (!is.null(x$n)) {
      svg_unwind_vp(x$n, st)
    }
    return(invisible())
  }
  if (inherits(x, "gTree")) {
    depth <- svg_enforce_vp(x$vp, st)
    if (!is.null(x$childrenvp)) {
      grid::pushViewport(x$childrenvp, recording = FALSE)
      grid::upViewport(grid::depth(x$childrenvp), recording = FALSE)
    }
    root <- identical(x$name, "gridSVG") && !length(st$gps) &&
      is.null(st$root_seen)
    if (root) {
      st$root_seen <- TRUE
      svg_event(st, list(
        t = "go", id = "gridSVG", root = TRUE,
        attrs = svg_gp_attrs(grid::get.gpar(), svg_gp_names)
      ))
      children <- x$children
    } else {
      st$gps <- c(st$gps, list(x$gp))
      svg_event(st, list(
        t = "go", id = svg_get_id(x$name, st),
        attrs = svg_gp_attrs(svg_effective_gp(st), names(x$gp))
      ))
      children <- x$children[x$childrenOrder]
    }
    for (child in children) svg_walk_grob(child, st)
    if (!root) st$gps <- st$gps[-length(st$gps)]
    svg_event(st, list(t = "gc"))
    svg_unwind_vp(depth, st)
    return(invisible())
  }
  if (inherits(x, "grob")) {
    depth <- svg_enforce_vp(x$vp, st)
    x$vp <- NULL
    svg_prim(x, st)
    svg_unwind_vp(depth, st)
  }
  invisible()
}

#' Draw one grob in the walk's context, under its ancestors' gpar
#' @keywords internal
svg_draw <- function(g, st) {
  for (gp in rev(st$gps)) {
    if (!is.null(gp) && length(gp)) {
      g <- grid::gTree(children = grid::gList(g), gp = gp)
    }
  }
  grid::grid.draw(g, recording = FALSE)
}

# The gpar a drawing inherits: the viewport's, under each ancestor gTree's,
# alpha, cex and lex compounding as grid compounds them.
svg_effective_gp <- function(st, own = NULL) {
  eff <- unclass(grid::get.gpar())
  for (gp in c(st$gps, list(own))) {
    if (is.null(gp)) next
    for (nm in names(gp)) {
      eff[[nm]] <- if (nm %in% c("alpha", "cex", "lex")) {
        eff[[nm]] * gp[[nm]]
      } else {
        gp[[nm]]
      }
    }
  }
  eff
}

svg_gp_names <- c(
  "col", "fill", "alpha", "lwd", "lex", "lty", "lineend", "linejoin",
  "linemitre", "fontsize", "cex", "fontfamily", "fontface", "font"
)

#' Presentation attributes for a group, as gridSVG gave them
#'
#' gridSVG wrote a group's own gpar as attributes its shapes inherit, and a
#' shape's own gpar on the shape. Shapes here keep that split (see
#' [svg_convert_shapes()]), so the groups carry their share: each setting the
#' group's gpar names, at the value the drawing inherits there. Alpha is
#' folded into the opacities rather than written as `opacity`, the way the
#' device folds it into every shape.
#'
#' @param eff The effective gpar at the group.
#' @param set Names of the gpar settings the group itself makes.
#' @return A string of attributes with a leading space, or "".
#' @keywords internal
svg_gp_attrs <- function(eff, set) {
  set <- intersect(set, svg_gp_names)
  if (!length(set)) {
    return("")
  }
  first <- function(v) if (length(v)) v[[1]] else NULL
  alpha <- first(eff$alpha)
  if (is.null(alpha)) alpha <- 1
  out <- list()
  paint <- function(col) {
    col <- first(col)
    if (is.null(col) || is.na(col)) {
      return(list("none", 0))
    }
    rgba <- grDevices::col2rgb(col, alpha = TRUE)[, 1]
    if (rgba[4] == 0) {
      return(list("none", 0))
    }
    list(
      paste0("rgb(", rgba[1], ",", rgba[2], ",", rgba[3], ")"),
      round(rgba[4] / 255 * alpha, 2)
    )
  }
  if (any(c("col", "alpha") %in% set)) {
    v <- paint(eff$col)
    out[["stroke"]] <- v[[1]]
    out[["stroke-opacity"]] <- v[[2]]
  }
  if (any(c("fill", "alpha") %in% set)) {
    v <- paint(eff$fill)
    out[["fill"]] <- v[[1]]
    out[["fill-opacity"]] <- v[[2]]
  }
  lwd <- first(eff$lwd) * (if (is.null(eff$lex)) 1 else first(eff$lex))
  if (any(c("lwd", "lex", "lty") %in% set)) {
    blank <- as.character(first(eff$lty)) %in% c("blank", "0")
    out[["stroke-width"]] <- if (blank) 0 else round(lwd / 96 * 72, 2)
  }
  if ("lty" %in% set) {
    out[["stroke-dasharray"]] <- svg_lty(first(eff$lty), lwd)
  }
  if ("lineend" %in% set) out[["stroke-linecap"]] <- first(eff$lineend)
  if ("linejoin" %in% set) {
    out[["stroke-linejoin"]] <- sub("mitre", "miter", first(eff$linejoin))
  }
  if ("linemitre" %in% set) out[["stroke-miterlimit"]] <- first(eff$linemitre)
  if (any(c("fontsize", "cex") %in% set)) {
    out[["font-size"]] <- round(first(eff$fontsize) * first(eff$cex), 2)
  }
  if ("fontfamily" %in% set) {
    out[["font-family"]] <- svg_font_stack(first(eff$fontfamily))
  }
  if (any(c("fontface", "font") %in% set)) {
    face <- first(eff$fontface)
    if (is.null(face)) face <- first(eff$font)
    face <- as.character(face)
    bold <- face %in% c("2", "4", "bold", "bold.italic")
    italic <- face %in% c("3", "4", "italic", "bold.italic")
    out[["font-weight"]] <- if (bold) "bold" else "normal"
    out[["font-style"]] <- if (italic) "italic" else "normal"
  }
  paste0(" ", names(out), '="', unlist(out), '"', collapse = "")
}

# Open a grob's group and return its id.
svg_open_grob <- function(x, st) {
  id <- svg_get_id(x$name, st)
  svg_event(st, list(t = "go", id = id, grob = TRUE))
  id
}

# Draw one shape of a grob; everything svglite emits until the next marker
# belongs to it.
svg_element <- function(g, id, kind, st, pieces = NULL) {
  svg_event(st, list(
    t = "el", id = id, kind = kind, pieces = pieces, own = names(g$gp),
    blank = svg_blank_lty(g$gp, st)
  ))
  svg_flush(st)
  svg_draw(g, st)
}

svg_all_finite <- function(...) {
  all(vapply(list(...), function(u) {
    v <- if (grid::is.unit(u)) {
      suppressWarnings(grid::convertX(u, "inches", valueOnly = TRUE))
    } else {
      u
    }
    all(is.finite(v))
  }, logical(1)))
}

svg_inches <- function(u, convert) {
  if (!grid::is.unit(u)) {
    return(u)
  }
  suppressWarnings(convert(u, "inches", valueOnly = TRUE))
}

svg_expand_gp <- function(gp, n) {
  if (is.null(gp)) {
    return(grid::gpar())
  }
  for (i in seq_along(gp)) gp[[i]] <- rep(gp[[i]], length.out = n)
  gp
}

svg_expand_arrow <- function(arrow, n) {
  if (!is.null(arrow)) {
    for (i in seq_along(arrow)) arrow[[i]] <- rep(arrow[[i]], length.out = n)
  }
  arrow
}

svg_split_ids <- function(x) {
  if ((is.null(x$id) && is.null(x$id.lengths)) ||
    (!is.null(x$id) && all(is.na(x$id)))) {
    return(rep(1L, length(x$x)))
  }
  if (is.null(x$id)) rep(seq_along(x$id.lengths), x$id.lengths) else x$id
}

# Number of pieces gridSVG split a line into: runs of at least two finite
# points. Only needed to tell a line's pieces from its arrow heads.
svg_line_pieces <- function(x, y) {
  xs <- suppressWarnings(grid::convertX(x, "inches", valueOnly = TRUE))
  ys <- suppressWarnings(grid::convertY(y, "inches", valueOnly = TRUE))
  ok <- is.finite(xs) & is.finite(ys)
  r <- rle(ok)
  sum(r$values & r$lengths >= 2)
}

svg_draw_lines <- function(lg, id, st) {
  pieces <- if (is.null(lg$arrow)) NULL else svg_line_pieces(lg$x, lg$y)
  # The engine draws nothing for a blank line type, but gridSVG still wrote
  # the line (with no stroke), and later elements' positions count it. An
  # invisible solid line keeps the element.
  if (svg_blank_lty(lg$gp, st)) {
    if (is.null(lg$gp)) lg$gp <- grid::gpar()
    lg$gp$lty <- "solid"
    lg$gp$col <- NA
    lg$gp$lwd <- 0
  }
  svg_element(lg, id, "line", st, pieces)
}

# Whether a grob draws with a blank line type, its own gpar over its
# ancestors' over the viewport's.
svg_blank_lty <- function(gp, st) {
  lty <- grid::get.gpar("lty")[[1]]
  for (g in c(st$gps, list(gp))) {
    if (!is.null(g) && !is.null(g$lty)) lty <- g$lty
  }
  length(lty) >= 1L && (identical(as.character(lty[[1]]), "blank") ||
    identical(as.character(lty[[1]]), "0"))
}

svg_prim <- function(x, st) {
  cls <- class(x)
  if (any(c("null", "zeroGrob") %in% cls)) {
    return(invisible())
  }
  if ("clip" %in% cls) {
    svg_flush(st)
    svg_draw(x, st)
    return(invisible())
  }
  if ("points" %in% cls) {
    return(svg_prim_points(x, st))
  }
  if ("rect" %in% cls || "circle" %in% cls) {
    return(svg_prim_vectorised(x, st))
  }
  if ("text" %in% cls) {
    return(svg_prim_text(x, st))
  }

  id <- svg_open_grob(x, st)
  if ("polyline" %in% cls) {
    ids <- svg_split_ids(x)
    xs <- split(x$x, ids)
    ys <- split(x$y, ids)
    n <- length(xs)
    gp <- svg_expand_gp(x$gp, n)
    arrows <- svg_expand_arrow(x$arrow, n)
    for (i in seq_len(n)) {
      lg <- grid::linesGrob(
        x = xs[[i]], y = ys[[i]], gp = gp[i], arrow = arrows[i],
        default.units = x$default.units
      )
      svg_draw_lines(lg, paste0(id, ".", i), st)
    }
  } else if ("segments" %in% cls) {
    n <- max(length(x$x0), length(x$x1), length(x$y0), length(x$y1))
    gp <- svg_expand_gp(x$gp, n)
    arrows <- svg_expand_arrow(x$arrow, n)
    for (i in seq_len(n)) {
      lg <- grid::linesGrob(
        grid::unit.c(
          x$x0[(i - 1) %% length(x$x0) + 1],
          x$x1[(i - 1) %% length(x$x1) + 1]
        ),
        grid::unit.c(
          x$y0[(i - 1) %% length(x$y0) + 1],
          x$y1[(i - 1) %% length(x$y1) + 1]
        ),
        arrow = arrows[i], default.units = x$default.units, gp = gp[i]
      )
      svg_draw_lines(lg, paste0(id, ".", i), st)
    }
  } else if ("lines" %in% cls || "line.to" %in% cls) {
    svg_draw_lines(x, paste0(id, ".1"), st)
  } else if ("polygon" %in% cls) {
    ids <- svg_split_ids(x)
    xs <- split(x$x, ids)
    ys <- split(x$y, ids)
    n <- length(xs)
    gp <- svg_expand_gp(x$gp, n)
    for (i in seq_len(n)) {
      pg <- grid::polygonGrob(
        x = xs[[i]], y = ys[[i]], gp = gp[i],
        default.units = x$default.units
      )
      svg_element(pg, paste0(id, ".", i), "shape", st)
    }
  } else if ("pathgrob" %in% cls &&
    !(is.null(x$pathId) && is.null(x$pathId.lengths))) {
    path_id <- if (is.null(x$pathId)) {
      rep(seq_along(x$pathId.lengths), x$pathId.lengths)
    } else {
      x$pathId
    }
    ids <- if (is.null(x$id) && is.null(x$id.lengths)) {
      rep(1L, length(x$x))
    } else if (is.null(x$id)) {
      rep(seq_along(x$id.lengths), x$id.lengths)
    } else {
      x$id
    }
    xs <- split(x$x, path_id)
    ys <- split(x$y, path_id)
    is <- split(ids, path_id)
    n <- length(xs)
    gp <- svg_expand_gp(x$gp, n)
    for (i in seq_len(n)) {
      pg <- grid::pathGrob(
        x = xs[[i]], y = ys[[i]], id = is[[i]], rule = x$rule, gp = gp[i],
        default.units = x$default.units
      )
      svg_element(pg, paste0(id, ".", i), "path", st)
    }
  } else if ("rastergrob" %in% cls) {
    n <- max(length(x$x), length(x$y), length(x$width), length(x$height))
    if (n <= 1L) {
      svg_element(x, paste0(id, ".1"), "shape", st)
    } else {
      for (i in seq_len(n)) {
        rg <- x
        rg$x <- rep(x$x, length.out = n)[i]
        rg$y <- rep(x$y, length.out = n)[i]
        if (!is.null(x$width)) rg$width <- rep(x$width, length.out = n)[i]
        if (!is.null(x$height)) rg$height <- rep(x$height, length.out = n)[i]
        svg_element(rg, paste0(id, ".", i), "shape", st)
      }
    }
  } else if ("xspline" %in% cls) {
    ids <- svg_split_ids(x)
    xs <- split(x$x, ids)
    ys <- split(x$y, ids)
    shapes <- split(rep(x$shape, length.out = length(x$x)), ids)
    n <- length(xs)
    gp <- svg_expand_gp(x$gp, n)
    arrows <- svg_expand_arrow(x$arrow, n)
    for (i in seq_len(n)) {
      xg <- grid::xsplineGrob(
        x = xs[[i]], y = ys[[i]], shape = shapes[[i]], open = x$open,
        repEnds = rep(x$repEnds, length.out = n)[i], arrow = arrows[i],
        gp = gp[i], default.units = x$default.units
      )
      svg_element(xg, paste0(id, ".", i), "shape", st)
    }
  } else if ("pathgrob" %in% cls) {
    svg_element(x, paste0(id, ".1"), "path", st)
  } else {
    # Anything else (a roundrect, a grob class of some extension) is one
    # shape as far as selectors go.
    svg_element(x, paste0(id, ".1"), "shape", st)
  }
  svg_event(st, list(t = "gc"))
  invisible()
}

# Rects and circles draw one shape per element, so the whole grob is drawn
# in one call and its shapes numbered in order. An element with a missing
# coordinate is not drawn, which would shift that numbering, so such a grob
# is drawn one element at a time instead.
svg_prim_vectorised <- function(x, st) {
  is_rect <- inherits(x, "rect")
  n <- if (is_rect) {
    max(length(x$x), length(x$y), length(x$width), length(x$height))
  } else {
    max(length(x$x), length(x$y), length(x$r))
  }
  finite <- if (is_rect) {
    svg_all_finite(x$x, x$y, x$width, x$height)
  } else {
    svg_all_finite(x$x, x$y, x$r)
  }
  id <- svg_open_grob(x, st)
  if (finite && n > 0 && !isTRUE(st$one_at_a_time)) {
    svg_event(st, list(
      t = "run", id = id, n = n, own = names(x$gp),
      blank = svg_blank_lty(x$gp, st)
    ))
    svg_flush(st)
    svg_draw(x, st)
  } else {
    gp <- svg_expand_gp(x$gp, n)
    for (i in seq_len(n)) {
      g <- x
      if (is_rect) {
        g$x <- rep(x$x, length.out = n)[i]
        g$y <- rep(x$y, length.out = n)[i]
        g$width <- rep(x$width, length.out = n)[i]
        g$height <- rep(x$height, length.out = n)[i]
      } else {
        g$x <- rep(x$x, length.out = n)[i]
        g$y <- rep(x$y, length.out = n)[i]
        g$r <- rep(x$r, length.out = n)[i]
      }
      g$gp <- gp[i]
      svg_element(g, paste0(id, ".", i), "shape", st)
    }
  }
  svg_event(st, list(t = "gc"))
  invisible()
}

svg_prim_text <- function(x, st) {
  n <- max(length(x$x), length(x$y), length(x$label))
  # A label with nowhere to go (an axis without breaks) is drawn by neither
  # grid nor gridSVG.
  if (length(x$x) == 0L || length(x$y) == 0L) n <- 0L
  id <- svg_open_grob(x, st)
  if (n > 0) {
    xs <- rep(x$x, length.out = n)
    ys <- rep(x$y, length.out = n)
    rot <- rep(x$rot, length.out = n)
    labels <- if (length(x$label) == 0) {
      rep(" ", n)
    } else if (is.language(x$label)) {
      rep(as.expression(x$label), length.out = n)
    } else {
      rep(x$label, length.out = n)
    }
    gp <- svg_expand_gp(x$gp, n)
    # gridSVG wrote nothing for a label at a missing position; grid draws
    # nothing there either.
    placed <- is.finite(svg_inches(xs, grid::convertX)) &
      is.finite(svg_inches(ys, grid::convertY))
    for (i in which(placed)) {
      g <- x
      g$x <- xs[i]
      g$y <- ys[i]
      g$rot <- rot[i]
      g$label <- labels[i]
      g$gp <- gp[i]
      svg_element(g, paste0(id, ".", i), "text", st)
    }
  }
  svg_event(st, list(t = "gc"))
  invisible()
}

# -- points ------------------------------------------------------------------
#
# Points are written here rather than drawn: every selector for a point
# layer targets the `<use>` elements gridSVG wrote, one per point, each
# referencing one `<symbol>` per plotting character. The geometry below is
# gridSVG's (symbols in a 10-unit box, the `<use>` scaled to the point size,
# the stroke scaled back), so the marks are the ones maidr always drew.

svg_col <- function(col) {
  if (is.numeric(col)) col[col == 0] <- "transparent"
  rgb <- grDevices::col2rgb(col, alpha = TRUE)
  out <- paste0("rgb(", rgb[1, ], ",", rgb[2, ], ",", rgb[3, ], ")")
  out[is.na(col) | col == "transparent"] <- "none"
  list(col = out, alpha = round(rgb[4, ] / 255, 2))
}

svg_lty <- function(lty, lwd) {
  if (is.numeric(lty)) {
    lty <- c("blank", "solid", "dashed", "dotted", "dotdash", "longdash",
             "twodash")[lty %% 7 + 1]
  }
  mapply(function(l, w) {
    v <- switch(l,
      blank = , solid = 0, dashed = c(4, 4), dotted = c(1, 3),
      dotdash = c(1, 3, 4, 3), longdash = c(7, 3), twodash = c(2, 2, 6, 2),
      as.numeric(as.hexmode(strsplit(l, "")[[1]]))
    )
    v <- v * w
    paste(ifelse(v == 0, "none", round(v, 2)), collapse = ",")
  }, lty, lwd)
}

# The gpar a point grob draws with: its ancestors' gTree gpar under its own,
# alpha, cex and lex compounding as grid compounds them.
svg_points_gp <- function(x, st) {
  out <- list()
  for (gp in c(st$gps, list(x$gp))) {
    if (is.null(gp)) next
    for (nm in names(gp)) {
      if (nm %in% c("alpha", "cex", "lex") && !is.null(out[[nm]])) {
        out[[nm]] <- out[[nm]] * gp[[nm]]
      } else {
        out[[nm]] <- gp[[nm]]
      }
    }
  }
  out
}

svg_prim_points <- function(x, st) {
  n <- length(x$x)
  id <- svg_open_grob(x, st)
  if (n == 0) {
    svg_event(st, list(t = "gc"))
    return(invisible())
  }
  gp <- svg_points_gp(x, st)
  cur <- grid::get.gpar()
  col <- rep(if (is.null(gp$col)) cur$col else gp$col, length.out = n)
  fill <- rep(if (is.null(gp$fill)) cur$fill else gp$fill, length.out = n)
  lwd <- if (is.null(gp$lwd)) cur$lwd else gp$lwd
  if (!is.null(gp$lex)) lwd <- lwd * gp$lex
  lwd <- rep(lwd, length.out = n)

  pch <- x$pch
  if (!is.numeric(pch)) {
    chars <- as.character(pch)
    num <- suppressWarnings(as.numeric(chars))
    is_code <- !is.na(num) & chars %in% as.character(c(0:25, 32:127))
    pch <- ifelse(
      is_code, num,
      vapply(chars, function(ch) {
        if (is.na(ch) || !nzchar(ch)) NA_real_ else as.numeric(charToRaw(ch))[1]
      }, numeric(1))
    )
  }
  pch <- rep(pch, length.out = n)

  size <- x$size
  if (!grid::is.unit(size)) size <- grid::unit(size, x$default.units)
  if (!is.null(gp$cex) || !is.null(gp$fontsize)) {
    vp <- grid::current.viewport()
    fgp <- grid::gpar()
    if (!is.null(gp$cex)) fgp$cex <- gp$cex
    if (!is.null(gp$fontsize)) fgp$fontsize <- gp$fontsize
    grid::pushViewport(
      grid::viewport(xscale = vp$xscale, yscale = vp$yscale, gp = fgp),
      recording = FALSE
    )
    size <- grid::convertWidth(size, "inches")
    grid::popViewport(recording = FALSE)
  }
  size_w <- grid::convertWidth(size, "inches", valueOnly = TRUE)
  size_h <- grid::convertHeight(size, "inches", valueOnly = TRUE)
  size <- rep(pmin(size_w, size_h) * 72, length.out = n)

  loc <- grid::deviceLoc(
    if (grid::is.unit(x$x)) x$x else grid::unit(x$x, x$default.units),
    if (grid::is.unit(x$y)) x$y else grid::unit(x$y, x$default.units),
    valueOnly = TRUE
  )
  px <- rep(loc$x * 72, length.out = n)
  py <- rep(loc$y * 72, length.out = n)
  angle <- grid::current.rotation()

  fill[!is.na(pch) & pch < 15] <- "transparent"
  no_stroke <- !is.na(pch) & (pch %in% 15:20 | (pch >= 32 & pch != 46))
  fill[no_stroke] <- col[no_stroke]
  col[no_stroke & pch %in% 15:18] <- "transparent"

  stroke <- svg_col(col)
  fillc <- svg_col(fill)
  sw <- round(lwd / 96 * 72, 2)
  if (!is.null(gp$lty)) {
    lty <- rep(gp$lty, length.out = n)
    sw[lty %in% c("blank", 0)] <- 0
  }

  keep <- is.finite(px) & is.finite(py) & is.finite(size) & !is.na(pch)
  dot <- which(pch == 46)
  size[dot] <- 1
  rx <- round(px, 2)
  ry <- round(py, 2)
  r <- round(-size / 2, 2)
  transform <- paste0("translate(", r, ",", r, ")")
  if (angle != 0) {
    transform <- paste0("rotate(", round(angle, 2), ",", rx, ",", ry, ") ",
                        transform)
  } else {
    transform <- paste0(" ", transform)
  }
  scale_sw <- round(sw / (size / 10), 2)
  extra <- rep("", n)
  is_char <- which(pch > 25 & pch != 46)
  scale_sw[is_char] <- "0.1"
  extra[is_char] <- ' font-size="10"'
  extra[dot] <- ' shape-rendering="crispEdges"'
  style <- paste0(
    ' stroke="', stroke$col, '" fill="', fillc$col, '"',
    ' stroke-width="', scale_sw, '"',
    ' stroke-opacity="', stroke$alpha, '" fill-opacity="', fillc$alpha, '"'
  )
  if (!is.null(gp$lty)) {
    style <- paste0(
      style, ' stroke-dasharray="',
      svg_lty(rep(gp$lty, length.out = n), sw), '"'
    )
  }
  if (!is.null(gp$alpha)) {
    style <- paste0(style, ' opacity="', rep(gp$alpha, length.out = n), '"')
  }
  lines <- paste0(
    '<use id="', id, ".", seq_len(n), '" xlink:href="#gridSVG.pch', pch,
    '" x="', rx, '" y="', ry, '" width="', round(size, 2),
    '" height="', round(size, 2), '" transform="', transform, '"',
    style, extra, "/>"
  )[keep]
  st$pch <- union(st$pch, pch[keep])
  svg_event(st, list(t = "pts", lines = lines))
  # The marker drawn here is what tells which clip the points sit in.
  svg_flush(st)
  svg_event(st, list(t = "gc"))
  invisible()
}

svg_symbol_defs <- function(pchs) {
  if (!length(pchs)) {
    return(character(0))
  }
  trc0 <- sqrt(4 * pi / (3 * sqrt(3)))
  pts <- function(x, y) {
    paste0('points="', paste(round(x, 2), round(y, 2), sep = ",",
                             collapse = " "), '"')
  }
  poly <- function(x, y) paste0("<polyline ", pts(x, y), "/>")
  circle <- function(r = 3.75) paste0('<circle cx="0" cy="0" r="', r, '"/>')
  square <- '<rect x="-3.75" y="-3.75" width="7.5" height="7.5"/>'
  tri_up <- poly(
    c(0, trc0 * sqrt(3) / 2 * 3.75, -trc0 * sqrt(3) / 2 * 3.75, 0),
    c(trc0 * 3.75, -trc0 / 2 * 3.75, -trc0 / 2 * 3.75, trc0 * 3.75)
  )
  tri_down <- poly(
    c(0, trc0 * sqrt(3) / 2 * 3.75, -trc0 * sqrt(3) / 2 * 3.75, 0),
    c(-trc0 * 3.75, trc0 / 2 * 3.75, trc0 / 2 * 3.75, -trc0 * 3.75)
  )
  xc <- sqrt(2) * 3.75
  plus <- c(poly(c(-xc, xc), c(0, 0)), poly(c(0, 0), c(-xc, xc)))
  times <- c(poly(c(-3.75, 3.75), c(-3.75, 3.75)),
             poly(c(-3.75, 3.75), c(3.75, -3.75)))
  diamond <- paste0("<polygon ", pts(c(-xc, 0, xc, 0, -xc), c(0, xc, 0, -xc, 0)), "/>")
  small_plus <- c(poly(c(-3.75, 3.75), c(0, 0)), poly(c(0, 0), c(-3.75, 3.75)))
  shape <- function(p) {
    switch(as.character(p),
      "0" = square, "1" = circle(), "2" = tri_up, "3" = plus, "4" = times,
      "5" = diamond, "6" = tri_down, "7" = c(square, times),
      "8" = c(plus, times), "9" = c(plus, diamond),
      "10" = c(circle(), small_plus),
      "11" = {
        yc <- 0.5 * (trc0 / 2 * 3.75 + trc0 * 3.75)
        xs <- trc0 * sqrt(3) / 2 * 3.75
        c(poly(c(0, xs, -xs, 0), c(-trc0 * 3.75, yc, yc, -trc0 * 3.75)),
          poly(c(0, xs, -xs, 0), c(trc0 * 3.75, -yc, -yc, trc0 * 3.75)))
      },
      "12" = c(square, small_plus), "13" = c(circle(), times),
      "14" = c(paste0("<polyline ", pts(c(0, 3.75, -3.75, 0),
                                        c(-3.75, 3.75, 3.75, -3.75)), "/>"),
               square),
      "15" = square, "16" = circle(), "17" = tri_up, "18" = diamond,
      "19" = circle(), "20" = circle(2.5), "21" = circle(),
      "22" = {
        r <- round(sqrt(pi / 4) * 3.75, 2)
        paste0('<rect x="', -r, '" y="', -r, '" width="', 2 * r,
               '" height="', 2 * r, '"/>')
      },
      "23" = {
        r <- 3.75 * sqrt(pi / 4) * sqrt(2)
        paste0("<polygon ", pts(c(-r, 0, r, 0, -r), c(0, r, 0, -r, 0)), "/>")
      },
      "24" = tri_up, "25" = tri_down,
      "46" = '<rect x="-0.5" y="-0.5" width="1" height="1"/>',
      paste0(
        '<text x="0" y="0" fontsize="7.5" transform="scale(1, -1)"',
        ' text-anchor="middle" baseline-shift="-25%">',
        svg_escape(rawToChar(as.raw(p))), "</text>"
      )
    )
  }
  body <- unlist(lapply(sort(pchs), function(p) {
    c(
      paste0('<symbol id="gridSVG.pch', p,
             '" viewBox="-5 -5 10 10" overflow="visible">'),
      shape(p),
      "</symbol>"
    )
  }))
  c("<defs>", body, "</defs>")
}

svg_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}

# -- rewriting svglite's output ----------------------------------------------

#' Families svglite resolved R's generic font families to
#'
#' Cached per session: svglite writes the concrete family it measured with
#' ("Liberation Sans"), which a reader's browser may not have. Each is
#' written back as the generic stack gridSVG used, ending in a CSS generic.
#' @keywords internal
svg_font_aliases <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) {
      return(cache)
    }
    prev <- grDevices::dev.cur()
    get_svg <- open_svg_device(1, 1)
    dev <- grDevices::dev.cur()
    for (fam in c("sans", "serif", "mono")) {
      grid::grid.text("x", gp = grid::gpar(fontfamily = fam))
    }
    grDevices::dev.off(dev)
    if (prev > 1 && prev %in% grDevices::dev.list()) grDevices::dev.set(prev)
    svg <- utils::tail(get_svg(), 1L)
    fams <- regmatches(svg, gregexpr("font-family: \"[^\"]*\"", svg))[[1]]
    fams <- sub("font-family: \"([^\"]*)\"", "\\1", fams)
    out <- character(0)
    if (length(fams) == 3) {
      # Later entries lose a clash, so a family shared by two generics maps
      # to the first (sans).
      for (i in 3:1) out[[fams[i]]] <- svg_font_stacks[[i]]
    }
    cache <<- out
    out
  }
})

svg_font_stack <- function(family) {
  aliases <- svg_font_aliases()
  out <- aliases[family]
  miss <- is.na(out)
  out[miss] <- ifelse(
    nzchar(family[miss]),
    paste0(family[miss], ", ", svg_font_stacks$sans),
    svg_font_stacks$sans
  )
  unname(out)
}

svg_hex_to_rgb <- function(hex) {
  if (!length(hex)) {
    return(character(0))
  }
  paste0(
    "rgb(", strtoi(substr(hex, 2, 3), 16L), ",",
    strtoi(substr(hex, 4, 5), 16L), ",", strtoi(substr(hex, 6, 7), 16L), ")"
  )
}

# Which presentation attributes each gpar setting accounts for.
svg_gp_attr_map <- list(
  col = c("stroke", "stroke-opacity"),
  fill = c("fill", "fill-opacity"),
  alpha = c("stroke-opacity", "fill-opacity"),
  lwd = "stroke-width", lex = "stroke-width",
  lty = c("stroke-dasharray", "stroke-width"),
  lineend = "stroke-linecap", linejoin = "stroke-linejoin",
  linemitre = "stroke-miterlimit",
  fontsize = "font-size", cex = "font-size", fontfamily = "font-family",
  fontface = c("font-weight", "font-style"),
  font = c("font-weight", "font-style")
)

# What svglite leaves out of `style` when a setting is at its default.
svg_style_defaults <- c(
  "stroke" = "#000000", "stroke-opacity" = "1", "fill" = "none",
  "fill-opacity" = "1", "stroke-linecap" = "round",
  "stroke-linejoin" = "round", "stroke-miterlimit" = "10.00",
  "stroke-dasharray" = "none", "font-weight" = "normal",
  "font-style" = "normal"
)

#' svglite's `style` declarations as presentation attributes
#'
#' svglite resolves every setting a shape draws with. gridSVG wrote on a
#' shape only what the shape's own gpar set and let the rest come from its
#' groups, and that split is visible to maidr.js: a highlight clone of a
#' group repaints the shapes inside it only where they inherit. So a shape
#' keeps just the attributes its own gpar accounts for (NA: all of them),
#' with the value svglite resolved, which is the value it was drawn with.
#'
#' @param style Character vector of `style` values (NA for none).
#' @param text Logical vector: the element is text.
#' @param own Comma-separated names of each shape's own gpar settings, NA
#'   for a shape drawn outside any grob.
#' @param line Logical vector: the element is an open line, which gridSVG
#'   always wrote unfilled.
#' @return Character vector of attribute strings, each with a leading space.
#' @keywords internal
svg_style_attrs <- function(style, text, own = rep(NA_character_, length(style)),
                            line = logical(length(style))) {
  style[is.na(style)] <- ""
  key <- paste(as.integer(text), as.integer(line), own, style, sep = "\r")
  uniq <- !duplicated(key)
  conv <- vapply(which(uniq), function(i) {
    d <- trimws(strsplit(style[i], ";", fixed = TRUE)[[1]])
    d <- d[nzchar(d)]
    k <- trimws(sub(":.*$", "", d))
    v <- trimws(sub("^[^:]*:", "", d))
    keep <- k != "white-space"
    val <- stats::setNames(v[keep], k[keep])
    if (is.na(own[i])) {
      want <- union(names(val), c("fill", "stroke"))
    } else {
      set <- strsplit(own[i], ",", fixed = TRUE)[[1]]
      want <- unique(unlist(svg_gp_attr_map[intersect(set, names(svg_gp_attr_map))]))
      want <- c(want, intersect(names(val), "fill-rule"))
      if (text[i]) {
        want <- union(want, c("fill", "fill-opacity", "font-size", "font-family"))
      }
    }
    miss <- setdiff(want, names(val))
    val[miss] <- svg_style_defaults[miss]
    if (text[i]) {
      # gridSVG painted a label's colour as its stroke as well as its fill
      # (the stroke hairline-thin, from the label's group).
      if ("fill" %in% miss) val[["fill"]] <- "#000000"
      if ("stroke" %in% want) {
        val[["stroke"]] <- val[["fill"]]
        val[["stroke-opacity"]] <- if (is.na(val["fill-opacity"])) "1" else val[["fill-opacity"]]
      }
    }
    val <- val[want]
    val <- val[!is.na(val)]
    if (line[i]) val[["fill"]] <- "none"
    hex <- grepl("^#[0-9A-Fa-f]{6}$", val)
    val[hex] <- svg_hex_to_rgb(val[hex])
    val <- sub("^([0-9.]+)px$", "\\1", val)
    num <- grepl("^[0-9.]+$", val)
    val[num] <- svg_trim(val[num])
    fam <- names(val) == "font-family"
    val[fam] <- svg_font_stack(gsub("\"", "", val[fam], fixed = TRUE))
    if (!length(val)) {
      return("")
    }
    paste0(" ", names(val), '="', val, '"', collapse = "")
  }, character(1))
  conv[match(key, key[uniq])]
}

# Numbers as gridSVG wrote them: to two places, without trailing zeros.
svg_fmt <- function(v) {
  svg_trim(formatC(v, format = "f", digits = 2))
}

svg_trim <- function(x) {
  sub("(\\.[0-9]*[1-9])0+$", "\\1", sub("\\.0+$", "", x))
}

# Flip "x,y x,y" point lists about the page height.
svg_flip_points <- function(points, h) {
  parts <- strsplit(trimws(points), "[ ]+")
  lens <- lengths(parts)
  flat <- unlist(parts, use.names = FALSE)
  xy <- strsplit(flat, ",", fixed = TRUE)
  x <- svg_trim(vapply(xy, `[`, "", 1L))
  y <- svg_fmt(h - as.numeric(vapply(xy, `[`, "", 2L)))
  pairs <- paste0(x, ",", y)
  unname(vapply(
    split(pairs, rep(seq_along(points), lens)),
    paste, "", collapse = " "
  ))
}

# Flip an absolute M/L/Z path about the page height.
svg_flip_path <- function(d, h) {
  vapply(d, function(one) {
    tok <- strsplit(gsub("([MLZ])", " \\1 ", one), "[ ,]+")[[1]]
    tok <- tok[nzchar(tok)]
    out <- tok
    num <- grepl("^[0-9.-]", tok)
    out[num] <- svg_trim(tok[num])
    i <- 1L
    while (i <= length(tok)) {
      if (tok[i] %in% c("M", "L")) {
        out[i + 2L] <- svg_fmt(h - as.numeric(tok[i + 2L]))
        i <- i + 3L
      } else if (grepl("^[0-9.-]", tok[i])) {
        # an implicit L continuing the previous command
        out[i + 1L] <- svg_fmt(h - as.numeric(tok[i + 1L]))
        i <- i + 2L
      } else {
        i <- i + 1L
      }
    }
    paste(out, collapse = " ")
  }, character(1), USE.NAMES = FALSE)
}

svg_attr <- function(lines, name) {
  key <- paste0(" ", name, "='")
  out <- rep(NA_character_, length(lines))
  has <- grepl(key, lines, fixed = TRUE)
  out[has] <- sub(
    paste0("^.*? ", name, "='([^']*)'.*$"), "\\1", lines[has], perl = TRUE
  )
  out
}

#' Rewrite svglite shapes into the exported document's shapes
#'
#' @param lines svglite element lines.
#' @param ids Element ids (NA for none).
#' @param clips Clip-path ids (NA for none).
#' @param h Page height in px.
#' @param as_path Shapes of a path grob, written as `<path>`.
#' @param own Each shape's own gpar names (see [svg_style_attrs()]).
#' @param blank Shapes drawn with a blank line type.
#' @return Character vector of rewritten element lines.
#' @keywords internal
svg_convert_shapes <- function(lines, ids, clips, h, as_path = logical(length(lines)),
                               own = rep(NA_character_, length(lines)),
                               blank = logical(length(lines))) {
  n <- length(lines)
  if (!n) {
    return(character(0))
  }
  tag <- sub("^<([a-zA-Z]+).*$", "\\1", lines)
  # The engine hands a one-piece path to the device as a polygon; gridSVG
  # wrote every path grob as a <path>.
  poly_path <- as_path & tag == "polygon"
  if (any(poly_path)) {
    pts <- trimws(svg_attr(lines[poly_path], "points"))
    d <- vapply(strsplit(pts, "[ ]+"), function(p) {
      xy <- sub(",", " ", p, fixed = TRUE)
      paste0("M ", xy[1], paste0(" L ", xy[-1], collapse = ""), " Z")
    }, character(1))
    lines[poly_path] <- sub(
      "^<polygon points='[^']*'", paste0("<path d='", d, "'"),
      lines[poly_path]
    )
    tag[poly_path] <- "path"
  }
  style <- svg_attr(lines, "style")
  is_text <- tag == "text"
  paint <- svg_style_attrs(style, is_text, own, tag %in% c("polyline", "line"))
  # gridSVG gave a blank line type a zero stroke width, which a highlight
  # clone's width is added to.
  paint[blank] <- sub(' stroke-width="[^"]*"', ' stroke-width="0"', paint[blank])
  id_attr <- ifelse(is.na(ids), "", paste0(' id="', ids, '"'))
  # Text sits under a counter-flip and an image carries one, so their clip
  # regions are the unflipped variant ("@u"); text is clipped by its
  # wrapper group, since svglite's own transform on the <text> would move
  # a clip set on the element itself.
  clip_ref <- ifelse(tag == "image", paste0(clips, "@u"), clips)
  clip_attr <- ifelse(
    is.na(clips) | is_text, "", paste0(' clip-path="url(#', clip_ref, ')"')
  )
  out <- character(n)

  w <- which(tag == "rect")
  if (length(w)) {
    x <- as.numeric(svg_attr(lines[w], "x"))
    y <- as.numeric(svg_attr(lines[w], "y"))
    wd <- as.numeric(svg_attr(lines[w], "width"))
    ht <- as.numeric(svg_attr(lines[w], "height"))
    out[w] <- paste0(
      "<rect", id_attr[w], ' x="', svg_fmt(x), '" y="', svg_fmt(h - y - ht),
      '" width="', svg_fmt(wd), '" height="', svg_fmt(ht), '"',
      paint[w], clip_attr[w], "/>"
    )
  }
  w <- which(tag == "circle")
  if (length(w)) {
    out[w] <- paste0(
      "<circle", id_attr[w], ' cx="', svg_trim(svg_attr(lines[w], "cx")),
      '" cy="', svg_fmt(h - as.numeric(svg_attr(lines[w], "cy"))),
      '" r="', svg_trim(svg_attr(lines[w], "r")), '"', paint[w], clip_attr[w], "/>"
    )
  }
  w <- which(tag == "line")
  if (length(w)) {
    out[w] <- paste0(
      "<polyline", id_attr[w], ' points="',
      svg_trim(svg_attr(lines[w], "x1")), ",",
      svg_fmt(h - as.numeric(svg_attr(lines[w], "y1"))), " ",
      svg_trim(svg_attr(lines[w], "x2")), ",",
      svg_fmt(h - as.numeric(svg_attr(lines[w], "y2"))), '"',
      paint[w], clip_attr[w], "/>"
    )
  }
  w <- which(tag %in% c("polyline", "polygon"))
  if (length(w)) {
    out[w] <- paste0(
      "<", tag[w], id_attr[w], ' points="',
      svg_flip_points(svg_attr(lines[w], "points"), h), '"',
      paint[w], clip_attr[w], "/>"
    )
  }
  w <- which(tag == "path")
  if (length(w)) {
    out[w] <- paste0(
      "<path", id_attr[w], ' d="', svg_flip_path(svg_attr(lines[w], "d"), h),
      '"', paint[w], clip_attr[w], "/>"
    )
  }
  w <- which(tag == "image")
  if (length(w)) {
    tf <- svg_attr(lines[w], "transform")
    flip <- paste0("translate(0,", svg_fmt(h), ") scale(1,-1)")
    tf <- ifelse(is.na(tf), flip, paste(flip, tf))
    rest <- sub("^<image ", "", lines[w])
    rest <- sub(" transform='[^']*'", "", rest)
    rest <- gsub("'", '"', rest, fixed = TRUE)
    out[w] <- paste0(
      "<image", id_attr[w], ' transform="', tf, '"', clip_attr[w], " ",
      rest
    )
  }
  w <- which(is_text)
  if (length(w)) {
    head <- sub("^<text([^>]*)>.*$", "\\1", lines[w])
    body <- sub("^<text[^>]*>(.*)</text>$", "\\1", lines[w])
    head <- sub(" style='[^']*'", "", head)
    head <- gsub("'", '"', head, fixed = TRUE)
    out[w] <- paste0(
      "<text", id_attr[w], head, paint[w], ' xml:space="preserve">', body,
      "</text>"
    )
  }
  other <- which(!nzchar(out))
  out[other] <- lines[other]
  out
}

#' Parse svglite's page into shapes, markers and clip regions
#' @keywords internal
svg_parse_svglite <- function(svg) {
  lines <- strsplit(svg, "\n", fixed = TRUE)[[1]]
  n <- length(lines)
  # Everything inside <defs> is a definition; svglite opens and closes each
  # <defs> on lines of their own.
  depth <- cumsum(startsWith(lines, "<defs>")) - cumsum(startsWith(lines, "</defs>"))
  in_defs <- depth > 0 | startsWith(lines, "</defs>")
  # Clip region per line: a <g clip-path> opens one, the next </g> ends it.
  opens <- startsWith(lines, "<g clip-path='url(#") & !in_defs
  closes <- startsWith(lines, "</g>") & !in_defs
  run <- cumsum(opens | closes)
  region <- ifelse(
    opens, sub("^<g clip-path='url\\(#([^)]*)\\)'>$", "\\1", lines),
    NA_character_
  )
  starts <- which(opens | closes)
  clip <- rep(NA_character_, n)
  clip[run > 0] <- region[starts][run[run > 0]]
  shape <- !in_defs & grepl(
    "^<(rect|circle|line|polyline|polygon|path|text|image|use)[ >]", lines
  ) & !startsWith(lines, "<rect width='100%'")
  mark <- shape & startsWith(lines, "<text") &
    grepl(svg_marker_prefix, lines, fixed = TRUE)
  kind <- ifelse(mark, "mark", ifelse(shape, "shape", "skip"))
  clip[kind == "skip"] <- NA_character_

  # Clip definitions, and any other definitions (gradients, patterns) kept
  # as they are.
  clip_defs <- list()
  d <- which(in_defs)
  cp <- d[grepl("^\\s*<clipPath id='", lines[d])]
  for (i in cp) {
    r <- lines[i + 1L]
    clip_defs[[sub("^\\s*<clipPath id='([^']*)'.*$", "\\1", lines[i])]] <- c(
      as.numeric(svg_attr(r, "x")), as.numeric(svg_attr(r, "y")),
      as.numeric(svg_attr(r, "width")), as.numeric(svg_attr(r, "height"))
    )
  }
  other <- d[!(d %in% c(cp, cp + 1L, cp + 2L)) &
    !grepl("^</?defs>|style|CDATA|\\]\\]>|^\\s*\\.svglite|^\\s*[a-z-]+:|^\\s*}",
           lines[d])]
  extra_defs <- lines[other]
  mark <- which(kind == "mark")
  list(
    lines = lines,
    kind = kind,
    clip = clip,
    mark = mark,
    mark_id = as.integer(sub(
      paste0("^.*>", svg_marker_prefix, "([0-9]+)</text>$"), "\\1",
      lines[mark]
    )),
    clip_defs = clip_defs,
    extra_defs = extra_defs
  )
}

# A clip region's id is its geometry, so two charts on one page that share
# an id share the region too.
svg_clip_name <- function(frame, x, y, w, h) {
  paste0(
    "maidr-clip-", frame,
    gsub("-", "m", paste(svg_fmt(x), svg_fmt(y), svg_fmt(w), svg_fmt(h), sep = "_"))
  )
}

svg_alpha_suffix <- function(n) {
  if (n <= 1) {
    return("")
  }
  m <- suppressWarnings(matrix(rep(letters, length.out = n), nrow = 26))
  alpha <- apply(m, 1, function(x) {
    unlist(lapply(mapply(rep, x, seq_along(x)), paste, collapse = ""))
  })
  t(alpha)[seq_len(n)]
}

#' Assemble the exported document
#'
#' @param walk The walk state.
#' @param svg svglite's page.
#' @param w,h Page size in px.
#' @return Character vector of SVG lines.
#' @keywords internal
build_svg_document <- function(walk, svg, w, h) {
  p <- svg_parse_svglite(svg)
  # svglite clips everything to at least the page; gridSVG wrote no clip
  # there, and clipping to the page clips nothing.
  page <- names(Filter(function(r) {
    r[1] <= 0 && r[2] <= 0 && r[1] + r[3] >= w && r[2] + r[4] >= h
  }, p$clip_defs))
  p$clip[p$clip %in% page] <- NA_character_
  shape_idx <- which(p$kind == "shape")
  n_shapes <- length(shape_idx)
  shape_id <- rep(NA_character_, n_shapes)
  # Output is a list of pieces: character (literal lines) or integer
  # (indices into the converted shapes).
  out <- vector("list", 1024L)
  n_out <- 0L
  put <- function(x) {
    if (n_out == length(out)) length(out) <<- 2L * length(out)
    n_out <<- n_out + 1L
    out[[n_out]] <<- x
  }
  # Which shape each shape position is in `shape_idx`.
  pos <- integer(length(p$lines))
  pos[shape_idx] <- seq_len(n_shapes)
  clip_of <- p$clip[shape_idx]

  sink <- NULL
  run_mismatch <- FALSE
  as_path <- logical(n_shapes)
  shape_own <- rep(NA_character_, n_shapes)
  own_key <- function(ev) paste(ev$own, collapse = ",")
  shape_blank <- logical(n_shapes)
  # A grob's shapes almost always share one clip region; it is then written
  # once, on the grob's group, as gridSVG wrote it once per viewport.
  shape_noclip <- logical(n_shapes)
  gstack <- list()
  note_clip <- function(idx = integer(0), clip = clip_of[idx], at = integer(0),
                        text = NULL) {
    k <- length(gstack)
    if (!k || !isTRUE(gstack[[k]]$grob)) {
      return(FALSE)
    }
    gstack[[k]]$clips <<- c(gstack[[k]]$clips, clip)
    gstack[[k]]$shapes <<- c(gstack[[k]]$shapes, idx)
    if (length(at)) {
      gstack[[k]]$pts <<- c(gstack[[k]]$pts, at)
      gstack[[k]]$pts_clip <<- c(gstack[[k]]$pts_clip, clip)
      gstack[[k]]$pts_text <<- c(gstack[[k]]$pts_text, list(text))
    }
    TRUE
  }
  drain <- function(from, to) {
    # Shapes between two markers, assigned to the current sink.
    idx <- if (to >= from) pos[from:to] else integer(0)
    idx <- idx[idx > 0]
    if (!length(idx)) {
      # svglite draws nothing for an empty label; gridSVG wrote an empty
      # <text>, and later labels' positions count it.
      if (!is.null(sink) && identical(sink$kind, "text")) {
        put(c(
          paste0('<g id="', sink$id, '" stroke-width="0.1">'),
          paste0('<g id="', sink$id, '.scale" transform="scale(1, -1)">'),
          paste0('<text id="', sink$id, '.text" x="0" y="0"/>'),
          "</g>", "</g>"
        ))
      }
      return(invisible())
    }
    if (is.null(sink)) {
      put(idx)
      return(invisible())
    }
    shape_own[idx] <<- own_key(sink)
    shape_blank[idx] <<- isTRUE(sink$blank)
    if (!identical(sink$kind, "text")) note_clip(idx)
    if (sink$t == "run") {
      if (length(idx) != sink$n) run_mismatch <<- TRUE
      shape_id[idx] <<- paste0(sink$id, ".", seq_along(idx))
      put(idx)
    } else if (sink$kind == "text") {
      label <- svg_text_element(
        sink$id, p$lines[shape_idx[idx]], clip_of[idx[1]], own_key(sink)
      )
      put(label)
    } else {
      pieces <- length(idx)
      heads <- integer(0)
      if (!is.null(sink$pieces) && sink$pieces < length(idx)) {
        pieces <- sink$pieces
        heads <- idx[-seq_len(pieces)]
        idx <- idx[seq_len(pieces)]
      }
      if (length(heads)) {
        # gridSVG wrote an arrowed line's heads as one <defs> sibling before
        # it; the heads keep that one position.
        put("<g>")
        put(heads)
        put("</g>")
      }
      shape_id[idx] <<- paste0(sink$id, svg_alpha_suffix(length(idx)))
      if (identical(sink$kind, "path")) as_path[idx] <<- TRUE
      put(idx)
    }
    invisible()
  }
  # Text keeps gridSVG's shape: <g id translate(anchor)> <g .scale
  # scale(1,-1)> <text> at the origin, later lines of the label offset from
  # it. A clip region is re-expressed in the translated frame (a clip on a
  # transformed group is read in that group's coordinates); one covering
  # the whole page clips nothing and is left off.
  text_clips <- character(0)
  text_clip <- function(tx) {
    r <- tx$r
    cx <- svg_fmt(r[1] - tx$ax)
    cy <- svg_fmt(tx$ay - r[2] - r[4])
    nm <- svg_clip_name("t", r[1] - tx$ax, tx$ay - r[2] - r[4], r[3], r[4])
    if (!(nm %in% names(text_clips))) {
      text_clips[[nm]] <<- paste0(
        '<clipPath id="', nm, '"><rect x="', cx, '" y="', cy,
        '" width="', svg_fmt(r[3]), '" height="', svg_fmt(r[4]),
        '"/></clipPath>'
      )
    }
    nm
  }
  svg_text_element <- function(id, lines, cl, own) {
    tf <- svg_attr(lines, "transform")
    has_tf <- !is.na(tf)
    x <- as.numeric(svg_attr(lines, "x"))
    y <- as.numeric(svg_attr(lines, "y"))
    rot <- rep(NA_character_, length(lines))
    if (any(has_tf)) {
      m <- regmatches(tf[has_tf], regexec(
        "translate\\(([-0-9.]+),([-0-9.]+)\\)(?: rotate\\(([-0-9.]+)\\))?",
        tf[has_tf]
      ))
      x[has_tf] <- as.numeric(vapply(m, `[`, "", 2L))
      y[has_tf] <- as.numeric(vapply(m, `[`, "", 3L))
      r <- vapply(m, `[`, "", 4L)
      rot[has_tf] <- ifelse(is.na(r) | !nzchar(r), NA_character_, r)
    }
    x[!is.finite(x)] <- 0
    y[!is.finite(y)] <- 0
    ax <- x[1]
    ay <- y[1]
    body <- sub("^<text[^>]*>(.*)</text>$", "\\1", lines)
    anchor <- svg_attr(lines, "text-anchor")
    paint <- svg_style_attrs(
      svg_attr(lines, "style"), rep(TRUE, length(lines)),
      rep(own, length(lines))
    )
    dx <- svg_fmt(x - ax)
    dy <- svg_fmt(y - ay)
    place <- ifelse(
      is.na(rot),
      paste0(' x="', dx, '" y="', dy, '"'),
      paste0(' x="0" y="0" transform="translate(', dx, ",", dy, ") rotate(",
             rot, ')"')
    )
    ids <- c(paste0(' id="', id, '.text"'), rep("", length(lines) - 1L))
    texts <- paste0(
      "<text", ids, place,
      ifelse(is.na(anchor), "", paste0(' text-anchor="', anchor, '"')),
      paint,
      ifelse(grepl("^ | $|  ", body), ' xml:space="preserve"', ""),
      ">", body, "</text>"
    )
    r <- if (is.na(cl)) NULL else p$clip_defs[[cl]]
    full <- !is.null(r) && r[1] <= 0 && r[2] <= 0 && r[1] + r[3] >= w &&
      r[2] + r[4] >= h
    # Labels sharing a clip get it once on the grob's group (flipped frame);
    # only a label clipped differently from its siblings takes its own,
    # re-expressed in its translated frame.
    if (!full && !is.null(r)) {
      note_clip(clip = cl, at = n_out + 1L, text = list(r = r, ax = ax, ay = ay))
    }
    c(
      paste0('<g id="', id, '" transform="translate(', svg_fmt(ax), ", ",
             svg_fmt(h - ay), ')" stroke-width="0.1">'),
      paste0('<g id="', id, '.scale" transform="scale(1, -1)">'),
      texts,
      "</g>", "</g>"
    )
  }

  apply_batch <- function(events, clip) {
    for (ev in events) {
      switch(ev$t,
        go = {
          sink <<- NULL
          attrs <- if (is.null(ev$attrs)) "" else ev$attrs
          if (isTRUE(ev$root)) {
            put(c(
              paste0('<g id="gridSVG"', attrs, ">"),
              "@@maidr-svg-defs@@"
            ))
          } else {
            put(paste0('<g id="', ev$id, '"', attrs, ">"))
          }
          gstack[[length(gstack) + 1L]] <<- list(
            at = n_out, grob = isTRUE(ev$grob), clips = character(0),
            shapes = integer(0), pts = integer(0), pts_clip = character(0),
            pts_text = list()
          )
        },
        gc = {
          sink <<- NULL
          put("</g>")
          if (length(gstack)) {
            g <- gstack[[length(gstack)]]
            gstack[[length(gstack)]] <<- NULL
            one <- unique(g$clips)
            if (length(one) == 1L && !is.na(one)) {
              out[[g$at]] <<- sub(
                ">$", paste0(' clip-path="url(#', one, ')">'), out[[g$at]]
              )
              shape_noclip[g$shapes] <<- TRUE
            } else {
              for (i in seq_along(g$pts)) {
                tx <- g$pts_text[[i]]
                if (!is.null(tx)) {
                  out[[g$pts[i]]][1] <<- sub(
                    ">$", paste0(' clip-path="url(#', text_clip(tx), ')">'),
                    out[[g$pts[i]]][1]
                  )
                } else if (!is.na(g$pts_clip[i])) {
                  out[[g$pts[i]]] <<- sub(
                    "/>$", paste0(' clip-path="url(#', g$pts_clip[i], ')"/>'),
                    out[[g$pts[i]]]
                  )
                }
              }
            }
          }
        },
        el = sink <<- ev,
        run = sink <<- ev,
        pts = {
          sink <<- NULL
          lines <- ev$lines
          if (length(lines)) {
            put(lines)
            if (!note_clip(clip = clip, at = n_out) && !is.na(clip)) {
              out[[n_out]] <<- sub(
                "/>$", paste0(' clip-path="url(#', clip, ')"/>'), lines
              )
            }
          }
        }
      )
    }
  }

  prev <- 1L
  done <- 0L
  for (j in seq_along(p$mark)) {
    m <- p$mark[j]
    drain(prev, m - 1L)
    k <- p$mark_id[j]
    if (k > done) {
      for (b in seq.int(done + 1L, k)) {
        apply_batch(walk$batches[[b]], p$clip[m])
      }
      done <- k
    }
    prev <- m + 1L
  }
  drain(prev, length(p$lines))
  if (done < length(walk$batches)) {
    for (b in seq.int(done + 1L, length(walk$batches))) {
      apply_batch(walk$batches[[b]], NA_character_)
    }
  }

  # Clip regions: svglite's are in its own, unflipped frame. Shapes are
  # rewritten into the flipped page and take a flipped copy; text and
  # images, drawn under a counter-flip, keep the original ("@u").
  used_clips <- unique(stats::na.omit(c(clip_of, p$clip[p$mark])))
  clip_lines <- character(0)
  renames <- character(0)
  for (cid in used_clips) {
    r <- p$clip_defs[[cid]]
    if (is.null(r)) next
    for (flip in c(TRUE, FALSE)) {
      y <- if (flip) h - r[2] - r[4] else r[2]
      nm <- svg_clip_name(if (flip) "f" else "u", r[1], y, r[3], r[4])
      renames[[if (flip) cid else paste0(cid, "@u")]] <- nm
      clip_lines <- c(
        clip_lines,
        paste0('<clipPath id="', nm, '"><rect x="', svg_fmt(r[1]), '" y="',
               svg_fmt(y), '" width="', svg_fmt(r[3]), '" height="',
               svg_fmt(r[4]), '"/></clipPath>')
      )
    }
  }

  converted <- svg_convert_shapes(
    p$lines[shape_idx], shape_id, ifelse(shape_noclip, NA_character_, clip_of),
    h, as_path, shape_own, shape_blank
  )

  out <- out[seq_len(n_out)]
  pieces <- lapply(out, function(x) {
    if (is.character(x)) x else converted[x]
  })
  body <- unlist(pieces, use.names = FALSE)
  # "@u" names first: they extend the flipped ones.
  ord <- order(!grepl("@u$", names(renames)))
  for (cid in names(renames)[ord]) {
    body <- gsub(paste0("url(#", cid, ")"), paste0("url(#", renames[[cid]], ")"),
                 body, fixed = TRUE)
  }
  clip_lines <- c(clip_lines, unname(text_clips))
  # Only the regions something refers to.
  used <- vapply(
    sub('^<clipPath id="([^"]*)".*$', "\\1", clip_lines),
    function(nm) any(grepl(paste0("url(#", nm, ")"), body, fixed = TRUE)),
    logical(1)
  )
  clip_lines <- unique(clip_lines[used])
  defs <- c(
    if (length(clip_lines)) c("<defs>", clip_lines, "</defs>"),
    svg_symbol_defs(walk$pch),
    if (length(p$extra_defs)) c("<defs>", trimws(p$extra_defs), "</defs>")
  )
  at <- match("@@maidr-svg-defs@@", body)
  if (!is.na(at)) {
    body <- c(body[seq_len(at - 1L)], defs, body[-seq_len(at)])
  } else {
    body <- c(defs, body)
  }

  wpx <- round(w, 2)
  hpx <- round(h, 2)
  result <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    paste0(
      '<svg xmlns="http://www.w3.org/2000/svg"',
      ' xmlns:xlink="http://www.w3.org/1999/xlink" width="', wpx,
      'px" height="', hpx, 'px" viewBox="0 0 ', wpx, " ", hpx,
      '" version="1.1">'
    ),
    paste0('<g transform="translate(0, ', hpx, ') scale(1, -1)">'),
    body,
    "</g>",
    "</svg>"
  )
  attr(result, "run_mismatch") <- run_mismatch
  result
}
