#' Common SVG and HTML utilities
#'
#' This file contains common utilities for SVG manipulation, maidr data
#' injection, and HTML generation that work for all plot types.
#'
#' @importFrom grid grid.newpage grid.draw
#' @importFrom gridSVG grid.export
#' @importFrom stats setNames
NULL

# Counter for unique ID generation
.maidr_id_counter <- new.env(parent = emptyenv())
.maidr_id_counter$value <- 0L

#' Generate a unique ID for MAIDR plots
#'
#' Creates a unique identifier combining timestamp and counter to ensure
#' uniqueness even when multiple plots are created within the same second.
#'
#' @return Character string with unique ID
#' @keywords internal
generate_unique_id <- function() {
  .maidr_id_counter$value <- .maidr_id_counter$value + 1L
  paste0(
    as.integer(Sys.time()) * 1000 + .maidr_id_counter$value,
    "-",
    sample.int(9999, 1)
  )
}

#' Create enhanced SVG with maidr data
#' @param gt A gtable object
#' @param maidr_data The maidr-data structure
#' @param ... Additional arguments
#' @return Character vector of SVG content
#' @keywords internal
create_enhanced_svg <- function(gt, maidr_data, ...) {
  svg_file <- tempfile(fileext = ".svg")

  # Save current device
  current_dev <- grDevices::dev.cur()

  # Device dimensions (must match the PDF device)
  # Default: 7x5 (existing aspect ratio used by all other plot types).
  # Candlestick (chartSeries) needs a wider canvas (10x5) to keep
  # chartSeries' centered title and right-side bracketed date range
  # within the SVG viewBox. quantmod centers the title at ~10% of
  # canvas width and the date bracket at ~91%; at 9 in (648 px) long
  # titles still clipped on the left and the bracket extended ~44 px
  # past the right edge. Bumping to 10 in (720 px) clears both for
  # realistic ticker/title lengths. (See quantmod GH issue #129 for
  # the underlying upstream layout limitation.)
  # We widen ONLY when a candlestick layer is present in maidr_data,
  # leaving all other plot types' visual aspect ratio unchanged.
  has_candlestick <- length(collect_candlestick_layers(maidr_data)) > 0L
  # Candlestick needs a larger canvas (12x6 in -> 864x432 px) so that
  # chartSeries' right-side date-range header and bottom date labels
  # fit inside the gridSVG viewBox. This MUST match the gt_width/gt_height
  # used in base_r_plot_orchestrator.R; otherwise gridSVG exports content
  # sized for 864x432 into a 720x360 viewBox, producing a background rect
  # at (-180,-90) with size 1080x540 and right-axis labels only ~47 px
  # from the right edge. See quantmod GH issue #129.
  dev_width  <- if (has_candlestick) 12 else 7  # inches (was 10)
  dev_height <- if (has_candlestick)  6 else 5  # inches (was 5)

  # Use a null/invisible PDF device for rendering to avoid side effects
  pdf_file <- tempfile(fileext = ".pdf")
  grDevices::pdf(pdf_file, width = dev_width, height = dev_height)
  on.exit(
    {
      grDevices::dev.off()
      if (current_dev > 1) grDevices::dev.set(current_dev)
      unlink(pdf_file)
    },
    add = TRUE
  )

  # Render to the invisible device
  grid.newpage()
  grid.draw(gt)

  # Inject svg_x/svg_y coordinates into violin_kde layers while we have

  # access to the grid viewports (must happen after grid.draw but before
  # closing the device)
  maidr_data <- inject_violin_kde_svg_coords(gt, maidr_data)

  # Export to SVG
  grid.export(svg_file, exportCoords = "inline", exportMappings = "inline")

  svg_content <- readLines(svg_file, warn = FALSE)
  # Inject candlestick open/close virtual line elements before serializing
  # the maidr-data attribute so that the bundled maidr JS can resolve
  # `selectors.open` / `selectors.close` against real DOM nodes (bypassing
  # its Y-axis-flip-unaware auto-derivation heuristic).
  svg_content <- inject_candlestick_open_close(svg_content, maidr_data)
  # Reposition quantmod chartSeries' bracketed date-range header so it
  # right-aligns inside the viewBox (upstream quantmod #129). No-op for
  # ggplot candlestick / non-candlestick plots.
  svg_content <- adjust_chartseries_bracket(svg_content, maidr_data)
  # Remove the misaligned bottom-axis line and tick marks from
  # chartSeries candlestick output (date labels remain). No-op for
  # ggplot candlesticks / non-candlestick plots.
  svg_content <- strip_chartseries_date_axis(svg_content, maidr_data)
  # Remove the right y-axis (line + ticks + price labels) from
  # chartSeries candlestick output: on sparse OHLC the vertical
  # axis line overlaps the rightmost candle. Price info remains
  # in maidr-data JSON and is announced by the screen reader.
  svg_content <- strip_chartseries_right_axis(svg_content, maidr_data)
  svg_content <- add_maidr_data_to_svg(svg_content, maidr_data)

  svg_content
}

#' Inject svg_x/svg_y coordinates into violin_kde layer data
#'
#' After `grid.draw(gt)` has been called on a PDF device, this function
#' navigates to the panel viewport, maps data coordinates to SVG points,
#' and injects `svg_x`/`svg_y` into each ViolinKdePoint.  Temporary
#' metadata fields (`.panel_x_range`, `.panel_y_range`, `.is_horizontal`,
#' `data_left_x`, `data_right_x`, `data_y`) are stripped from the output.
#'
#' @param gt The gtable object (used to find the panel viewport name)
#' @param maidr_data The maidr-data structure (modified in place)
#' @return Updated maidr_data with svg_x/svg_y injected
#' @keywords internal
inject_violin_kde_svg_coords <- function(gt, maidr_data) {
  # Find violin_kde layers in the maidr_data structure
  if (is.null(maidr_data$subplots)) return(maidr_data)

  # Find the panel viewport name from the gtable layout
  panel_idx <- which(gt$layout$name == "panel")
  if (length(panel_idx) == 0) return(maidr_data)
  panel_layout <- gt$layout[panel_idx[1], ]
  vp_name <- sprintf(
    "panel.%d-%d-%d-%d",
    panel_layout$t, panel_layout$l, panel_layout$b, panel_layout$r
  )

  # Navigate to the panel viewport to get device coordinate mapping
  tryCatch(
    grid::downViewport(vp_name),
    error = function(e) {
      return(maidr_data)
    }
  )

  # Get absolute device position of panel corners (inches from device origin)
  loc0 <- grid::deviceLoc(grid::unit(0, "npc"), grid::unit(0, "npc"))
  loc1 <- grid::deviceLoc(grid::unit(1, "npc"), grid::unit(1, "npc"))
  dx0 <- as.numeric(loc0$x)
  dy0 <- as.numeric(loc0$y)
  dx1 <- as.numeric(loc1$x)
  dy1 <- as.numeric(loc1$y)

  grid::upViewport(0)

  # Walk subplots looking for violin_kde layers
  for (row_idx in seq_along(maidr_data$subplots)) {
    row <- maidr_data$subplots[[row_idx]]
    for (cell_idx in seq_along(row)) {
      cell <- row[[cell_idx]]
      if (is.null(cell$layers)) next

      for (layer_idx in seq_along(cell$layers)) {
        layer <- cell$layers[[layer_idx]]
        if (!identical(layer$type, "violin_kde")) next
        if (is.null(layer$.panel_x_range) || is.null(layer$.panel_y_range)) next

        x_range <- layer$.panel_x_range
        y_range <- layer$.panel_y_range
        is_horizontal <- isTRUE(layer$.is_horizontal)

        # Inject svg_x/svg_y into each KDE point
        for (group_idx in seq_along(layer$data)) {
          points <- layer$data[[group_idx]]
          is_left <- TRUE  # Points alternate: left, right, left, right ...

          for (pt_idx in seq_along(points)) {
            pt <- points[[pt_idx]]
            if (is.null(pt$data_left_x) || is.null(pt$data_y)) next

            # Determine which data x to use (left or right edge)
            if (is_left) {
              data_x <- pt$data_left_x
            } else {
              data_x <- pt$data_right_x
            }
            data_y <- pt$data_y

            # For horizontal violins, the axes are swapped:
            # data_left_x/data_right_x are on the y-axis (category),
            # data_y is on the x-axis (value)
            if (is_horizontal) {
              # Horizontal: category axis = y, value axis = x
              # data_x is actually in the y-axis range, data_y in x-axis range
              npc_x <- (data_y - x_range[1]) / (x_range[2] - x_range[1])
              npc_y <- (data_x - y_range[1]) / (y_range[2] - y_range[1])
            } else {
              npc_x <- (data_x - x_range[1]) / (x_range[2] - x_range[1])
              npc_y <- (data_y - y_range[1]) / (y_range[2] - y_range[1])
            }

            dev_x <- dx0 + npc_x * (dx1 - dx0)
            dev_y <- dy0 + npc_y * (dy1 - dy0)

            # gridSVG uses translate(0, height) scale(1, -1), so SVG coords
            # are device points without Y inversion
            pt$svg_x <- round(dev_x * 72, 2)
            pt$svg_y <- round(dev_y * 72, 2)

            # Strip temporary fields
            pt$data_left_x <- NULL
            pt$data_right_x <- NULL
            pt$data_y <- NULL

            points[[pt_idx]] <- pt
            is_left <- !is_left
          }
          # Sort points along the value axis for smooth keyboard navigation.
          # ViolinKdeTrace uses point order directly as the navigation order.
          #   Vertical:   value axis = Y → sort by svg_y (bottom-to-top)
          #   Horizontal: value axis = X → sort by svg_x (left-to-right)
          sort_vals <- if (is_horizontal) {
            vapply(points, function(p) {
              if (!is.null(p$svg_x)) p$svg_x else NA_real_
            }, numeric(1))
          } else {
            vapply(points, function(p) {
              if (!is.null(p$svg_y)) p$svg_y else NA_real_
            }, numeric(1))
          }
          if (!all(is.na(sort_vals))) {
            layer$data[[group_idx]] <- points[order(sort_vals)]
          } else {
            layer$data[[group_idx]] <- points
          }
        }

        # Strip layer-level metadata
        layer$.panel_x_range <- NULL
        layer$.panel_y_range <- NULL
        layer$.is_horizontal <- NULL

        cell$layers[[layer_idx]] <- layer
      }
      row[[cell_idx]] <- cell
    }
    maidr_data$subplots[[row_idx]] <- row
  }

  maidr_data
}

#' Inject candlestick open/close virtual line elements into the SVG
#'
#' tidyquant's `geom_candlestick()` draws each candle's body as a single
#' `<rect>`. Upstream maidr JS auto-derives `open` and `close` highlight
#' positions from the rect's bounding-box edges, but its heuristic assumes
#' a natural SVG y-axis (y increasing downward). gridSVG exports content
#' inside a `translate(0, h) scale(1, -1)` group, so y is flipped. The
#' upstream heuristic therefore swaps open and close on every candle.
#'
#' We sidestep the heuristic by emitting two sibling `<g>` containers (one
#' for opens, one for closes), each holding N invisible `<line>` elements
#' positioned at the correct edge of the corresponding body rect (computed
#' from the per-candle `trend`). The candlestick processor emits explicit
#' `selectors.open` / `selectors.close` referencing these groups, so JS
#' uses our placed elements directly and skips its own derivation.
#'
#' @param svg_content Character vector of SVG lines
#' @param maidr_data The maidr-data structure (read-only; used to look up
#'   per-candle `trend`)
#' @return Modified SVG content (character vector). If parsing fails or no
#'   candlestick layers are present, returns `svg_content` unchanged.
#' @keywords internal
inject_candlestick_open_close <- function(svg_content, maidr_data) {
  cs_layers <- collect_candlestick_layers(maidr_data)
  if (length(cs_layers) == 0) {
    return(svg_content)
  }
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(svg_content)
  }

  svg_text <- paste(svg_content, collapse = "\n")
  svg_doc <- tryCatch(
    xml2::read_xml(svg_text),
    error = function(e) NULL
  )
  if (is.null(svg_doc)) {
    return(svg_content)
  }

  ns <- c(svg = "http://www.w3.org/2000/svg")
  modified <- FALSE

  for (layer in cs_layers) {
    body_sel <- layer$selectors$body
    if (is.null(body_sel) || !is.character(body_sel)) next

    # `body_sel` may be a length-N character vector (one selector per
    # candle). All entries share the same parent body group, so use the
    # first entry to recover the group id.
    body_sel_first <- body_sel[[1L]]
    body_id <- extract_body_grob_id(body_sel_first)
    if (is.null(body_id)) next

    rect_index <- extract_rect_index_from_id(body_id)
    if (is.null(rect_index)) next

    # Find the body grob; SVG ids contain dots which break attribute-equality
    # XPath in some parsers, so escape using a literal predicate.
    xp <- sprintf("//svg:g[@id=\"%s\"]", body_id)
    body_g <- xml2::xml_find_first(svg_doc, xp, ns)
    if (inherits(body_g, "xml_missing")) next

    rects <- xml2::xml_find_all(body_g, ".//svg:rect", ns)
    n <- length(rects)
    if (n == 0) next

    # Number of candles in the maidr layer drives line emission. If the
    # SVG rect count drifts (e.g. partially clipped panels), be defensive.
    n_candles <- length(layer$data)
    n_use <- min(n, n_candles)
    if (n_use == 0) next

    opens_node <- xml2::xml_add_sibling(
      body_g, "g",
      id = sprintf("maidr-cs-opens-%s", rect_index),
      .where = "after"
    )
    closes_node <- xml2::xml_add_sibling(
      opens_node, "g",
      id = sprintf("maidr-cs-closes-%s", rect_index),
      .where = "after"
    )

    fmt <- function(v) format(v, trim = TRUE, scientific = FALSE)

    for (i in seq_len(n_use)) {
      rect <- rects[[i]]
      x  <- suppressWarnings(as.numeric(xml2::xml_attr(rect, "x")))
      y  <- suppressWarnings(as.numeric(xml2::xml_attr(rect, "y")))
      w  <- suppressWarnings(as.numeric(xml2::xml_attr(rect, "width")))
      h  <- suppressWarnings(as.numeric(xml2::xml_attr(rect, "height")))
      if (any(is.na(c(x, y, w, h)))) next

      trend <- layer$data[[i]]$trend
      # In gridSVG's flipped local space, smaller raw y = lower data value.
      # Bull (close > open): open is the lower edge → y; close → y + h.
      # Bear (close < open): open is the higher edge → y + h; close → y.
      if (identical(trend, "Bull")) {
        open_y  <- y
        close_y <- y + h
      } else if (identical(trend, "Bear")) {
        open_y  <- y + h
        close_y <- y
      } else {
        # Neutral: open == close; place both at the rect's y edge.
        open_y  <- y
        close_y <- y
      }

      xml2::xml_add_child(
        opens_node, "line",
        id = sprintf("maidr-cs-open-%s-%d", rect_index, i),
        x1 = fmt(x),
        y1 = fmt(open_y),
        x2 = fmt(x + w),
        y2 = fmt(open_y),
        stroke = "none",
        fill = "none"
      )
      xml2::xml_add_child(
        closes_node, "line",
        id = sprintf("maidr-cs-close-%s-%d", rect_index, i),
        x1 = fmt(x),
        y1 = fmt(close_y),
        x2 = fmt(x + w),
        y2 = fmt(close_y),
        stroke = "none",
        fill = "none"
      )
    }
    modified <- TRUE
  }

  if (!modified) {
    return(svg_content)
  }

  strsplit(as.character(svg_doc), "\n")[[1]]
}

#' Collect all candlestick layers in a maidr_data structure
#' @keywords internal
collect_candlestick_layers <- function(maidr_data) {
  out <- list()
  if (is.null(maidr_data$subplots)) return(out)
  for (row in maidr_data$subplots) {
    for (cell in row) {
      if (is.null(cell$layers)) next
      for (layer in cell$layers) {
        if (identical(layer$type, "candlestick")) {
          out[[length(out) + 1]] <- layer
        }
      }
    }
  }
  out
}

#' Extract the body `<g>` id from a candlestick `body` selector
#'
#' Input form: "#geom_rect\\.rect\\.57\\.1 rect"
#' Output: "geom_rect.rect.57.1"
#' @keywords internal
extract_body_grob_id <- function(body_selector) {
  m <- regmatches(body_selector,
                  regexpr("#[^ ]+", body_selector))
  if (length(m) == 0 || !nzchar(m)) return(NULL)
  raw <- sub("^#", "", m)
  # Unescape CSS dot escapes
  gsub("\\\\\\.", ".", raw)
}

#' Extract the trailing numeric index used to scope grouped open/close
#' element ids. For an id like "geom_rect.rect.57.1", returns "57".
#' @keywords internal
extract_rect_index_from_id <- function(grob_id) {
  # Strip the gridSVG ".1" suffix first
  base <- sub("\\.\\d+$", "", grob_id)
  m <- regmatches(base, regexpr("\\d+$", base))
  if (length(m) == 0 || !nzchar(m)) return(NULL)
  m
}

#' Reposition chartSeries date-range bracket header to prevent clipping
#'
#' `quantmod::chartSeries()` renders a bracketed date-range header
#' (e.g. "[2024-01-12/2024-01-15]") via base R `title()` with `par(adj=1)`.
#' For short timeseries the text width exceeds the available right margin
#' and the closing bracket is clipped at the SVG viewBox edge. This is
#' upstream quantmod issue #129 (open since 2016, no fix). See
#' `chartSeries.chob.R` lines 205-209 for the hardcoded placement.
#'
#' Earlier we tried CSS `overflow: visible`, but that re-exposes
#' chartSeries' intentionally negative-y volume `<rect>`s which rely on
#' the SVG root's default `overflow: hidden` for clipping. Further canvas
#' enlargement is impractical: the header is anchored at ~91% of canvas
#' width regardless of total width, so even 24-inch canvases would still
#' leave the header riding the right edge.
#'
#' This helper performs surgical SVG post-processing on the exported
#' gridSVG output: it locates the bracket text element by content pattern,
#' switches its `text-anchor` to `end`, and snaps its `x` coordinate to
#' 95% of the viewBox width. The text then right-aligns within the
#' viewBox regardless of header length.
#'
#' Safety: this is a no-op when `maidr_data` contains no candlestick
#' layers (ggplot candlestick / non-candlestick plots), when xml2 is
#' unavailable, when the SVG fails to parse, when the viewBox cannot be
#' read, or when no element matches the bracket pattern.
#'
#' @param svg_content Character vector of SVG lines
#' @param maidr_data The maidr-data structure (read-only; used to detect
#'   candlestick layers)
#' @return Modified SVG content (character vector). If any guard fails,
#'   returns `svg_content` unchanged.
#' @keywords internal
adjust_chartseries_bracket <- function(svg_content, maidr_data) {
  cs_layers <- collect_candlestick_layers(maidr_data)
  if (length(cs_layers) == 0L) {
    return(svg_content)
  }
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(svg_content)
  }

  svg_text <- paste(svg_content, collapse = "\n")
  svg_doc <- tryCatch(
    xml2::read_xml(svg_text),
    error = function(e) NULL
  )
  if (is.null(svg_doc)) {
    return(svg_content)
  }

  svg_root <- xml2::xml_root(svg_doc)
  viewbox <- xml2::xml_attr(svg_root, "viewBox")
  if (is.na(viewbox)) {
    return(svg_content)
  }
  vb_parts <- suppressWarnings(
    as.numeric(strsplit(viewbox, "\\s+")[[1]])
  )
  if (length(vb_parts) < 4L || any(is.na(vb_parts)) || vb_parts[3] <= 0) {
    return(svg_content)
  }
  vb_width <- vb_parts[3]
  safe_x <- vb_width * 0.95  # 5% right padding

  ns <- c(svg = "http://www.w3.org/2000/svg")
  text_nodes <- xml2::xml_find_all(svg_doc, ".//svg:text", ns)

  # Pattern: [YYYY-MM-DD/YYYY-MM-DD] (allow leading/trailing whitespace).
  bracket_re <- paste0(
    "^\\s*\\[\\s*\\d{4}-\\d{2}-\\d{2}",
    "\\s*/\\s*",
    "\\d{4}-\\d{2}-\\d{2}\\s*\\]\\s*$"
  )

  modified <- FALSE
  for (node in text_nodes) {
    content <- xml2::xml_text(node)
    if (grepl(bracket_re, content)) {
      xml2::xml_set_attr(node, "x", format(safe_x, trim = TRUE))
      xml2::xml_set_attr(node, "text-anchor", "end")
      modified <- TRUE
      break  # chartSeries emits at most one bracket header
    }
  }

  if (!modified) {
    return(svg_content)
  }
  strsplit(as.character(svg_doc), "\n")[[1]]
}

#' Strip the bottom axis line and tick marks from chartSeries candlestick SVG
#'
#' quantmod::chartSeries() emits a bottom date axis (axis line, tick
#' marks, and "Jan 12 2024" labels) via gridSVG. The axis line and
#' tick marks are drawn slightly off-center from the candles (gridSVG
#' places ticks at evenly-spaced positions that do not always coincide
#' with the candle centers), which reads as a visual misalignment.
#' This helper removes the axis line and tick marks but preserves the
#' date labels themselves so the chart still communicates which date
#' each candle represents visually. Per-row date info is also encoded
#' in the maidr-data JSON for the screen reader.
#'
#' The relevant groups have IDs of the form
#' `graphics-plot-N-bottom-axis-(line|ticks)-...`; we match by
#' substring with `contains(@id, 'bottom-axis-(line|ticks)-')` and
#' explicitly leave `bottom-axis-labels-` untouched.
#'
#' Safety: no-op when `maidr_data` contains no candlestick layers
#' (ggplot candlestick / non-candlestick plots use different SVG IDs
#' and are unaffected), when xml2 is unavailable, when SVG parsing
#' fails, or when no matching groups are found.
#'
#' @param svg_content Character vector of SVG lines
#' @param maidr_data The maidr-data structure (read-only; used to
#'   detect candlestick layers)
#' @return Modified SVG content (character vector). If any guard
#'   fails, returns `svg_content` unchanged.
#' @keywords internal
strip_chartseries_date_axis <- function(svg_content, maidr_data) {
  cs_layers <- collect_candlestick_layers(maidr_data)
  if (length(cs_layers) == 0L) {
    return(svg_content)
  }
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(svg_content)
  }

  svg_text <- paste(svg_content, collapse = "\n")
  svg_doc <- tryCatch(
    xml2::read_xml(svg_text),
    error = function(e) NULL
  )
  if (is.null(svg_doc)) {
    return(svg_content)
  }

  ns <- c(svg = "http://www.w3.org/2000/svg")
  modified <- FALSE

  # Strip only the axis line and tick marks; keep the date labels.
  for (id_substr in c(
    "bottom-axis-line-",
    "bottom-axis-ticks-"
  )) {
    xpath <- sprintf("//svg:g[contains(@id, '%s')]", id_substr)
    nodes <- xml2::xml_find_all(svg_doc, xpath, ns)
    if (length(nodes) > 0L) {
      xml2::xml_remove(nodes)
      modified <- TRUE
    }
  }

  if (!modified) {
    return(svg_content)
  }
  strsplit(as.character(svg_doc), "\n")[[1]]
}

#' Strip the right y-axis vertical line from chartSeries candlestick SVG
#'
#' quantmod::chartSeries() draws a right-hand y-axis with a vertical
#' axis line, tick marks, and numeric price labels (e.g. 101..106).
#' On sparse OHLC inputs (few candles spread across the plot region),
#' the right-axis vertical line is positioned within the candle area
#' and visually overlaps the rightmost candle, reading like a stray
#' "axis through the middle" of the chart. This helper removes only
#' the `right-axis-line-*` polyline; the tick marks and the price
#' labels themselves are preserved so the chart still communicates
#' the y-axis scale visually.
#'
#' The matched group has an ID of the form
#' `graphics-plot-N-right-axis-line-...`; matched by substring with
#' `contains(@id, 'right-axis-line-')`.
#'
#' Safety: no-op when `maidr_data` contains no candlestick layers
#' (ggplot candlestick / non-candlestick plots use different SVG IDs
#' and are unaffected), when xml2 is unavailable, when SVG parsing
#' fails, or when no matching groups are found.
#'
#' @param svg_content Character vector of SVG lines
#' @param maidr_data The maidr-data structure (read-only; used to
#'   detect candlestick layers)
#' @return Modified SVG content (character vector). If any guard
#'   fails, returns `svg_content` unchanged.
#' @keywords internal
strip_chartseries_right_axis <- function(svg_content, maidr_data) {
  cs_layers <- collect_candlestick_layers(maidr_data)
  if (length(cs_layers) == 0L) {
    return(svg_content)
  }
  if (!requireNamespace("xml2", quietly = TRUE)) {
    return(svg_content)
  }

  svg_text <- paste(svg_content, collapse = "\n")
  svg_doc <- tryCatch(
    xml2::read_xml(svg_text),
    error = function(e) NULL
  )
  if (is.null(svg_doc)) {
    return(svg_content)
  }

  ns <- c(svg = "http://www.w3.org/2000/svg")
  modified <- FALSE

  # Strip only the right-axis vertical line; keep the ticks and the
  # numeric price labels so the y-scale remains visible to sighted users.
  xpath <- "//svg:g[contains(@id, 'right-axis-line-')]"
  nodes <- xml2::xml_find_all(svg_doc, xpath, ns)
  if (length(nodes) > 0L) {
    xml2::xml_remove(nodes)
    modified <- TRUE
  }

  if (!modified) {
    return(svg_content)
  }
  strsplit(as.character(svg_doc), "\n")[[1]]
}

#' Add maidr-data to SVG using proper XML manipulation
#' @param svg_content Character vector of SVG lines
#' @param maidr_data The maidr-data structure
#' @return Modified SVG content
#' @keywords internal
add_maidr_data_to_svg <- function(svg_content, maidr_data) {
  # `na = "null"` ensures NA y-values (e.g. the leading rows of an SMA
  # moving-average line) serialize to JSON `null` rather than the string
  # `"NA"`, which `Number(point.y)` in the maidr JS frontend would coerce
  # to NaN and treat as a parse error.
  maidr_json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE, na = "null")

  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop(
      "The 'xml2' package is required for SVG manipulation. ",
      "Please install it with: install.packages('xml2')"
    )
  }

  svg_text <- paste(svg_content, collapse = "\n")
  svg_doc <- xml2::read_xml(svg_text)

  xml2::xml_attr(svg_doc, "maidr-data") <- maidr_json

  svg_content <- strsplit(as.character(svg_doc), "\n")[[1]]

  svg_content
}

#' Create HTML document with dependencies
#' @param svg_content Character vector of SVG content
#' @param use_cdn Logical. If `TRUE`, use CDN. If `FALSE`, use bundled files.
#'   If `NULL` (default), auto-detect based on internet availability.
#' @return An htmltools HTML document object
#' @keywords internal
create_html_document <- function(svg_content, use_cdn = NULL) {
  # Note: do NOT wrap in htmltools::tags$html(head, body) here.
  # htmltools::save_html() already wraps the content in a full
  # <!DOCTYPE html><html><head>...</head><body>...</body></html>
  # scaffold; an additional tags$html() produces a malformed document
  # with a nested duplicate <html> element. That breaks SVG container
  # sizing on some asset-loading paths (e.g. CDN), causing the chart
  # to render squished into the upper-left of the viewport.
  #
  # The wrapping <div class="maidr-page"> together with the
  # `maidr_responsive_dependency()` injection below provides a viewport
  # meta tag and CSS that center the SVG and let it scale fluidly with
  # the browser window. Without this, gridSVG's fixed-px width/height
  # on the <svg> leaves the chart pinned at its intrinsic 720x360
  # rendering size, producing the "tiny chart in the upper-left of a
  # huge empty page" appearance reported for base R candlestick output.
  html_doc <- htmltools::tags$div(
    class = "maidr-page",
    htmltools::HTML(paste(svg_content, collapse = "\n"))
  )

  html_doc <- htmltools::attachDependencies(
    html_doc,
    c(
      list(maidr_responsive_dependency()),
      maidr_html_dependencies(use_cdn = use_cdn)
    )
  )

  html_doc
}

#' Responsive page CSS dependency for MAIDR HTML output
#'
#' Returns an htmltools::htmlDependency() whose `head` payload injects a
#' viewport meta tag, a minimal CSS reset, and rules that make the embedded
#' SVG fill (or proportionally fit) the browser viewport. This is purely a
#' presentational layer; the SVG content, selectors, viewBox, and embedded
#' `maidr-data` attribute are untouched and the maidr JS frontend behaves
#' identically. We use a dependency (rather than an inline `<style>` tag in
#' the body) so the meta and style land in the document `<head>` produced by
#' `htmltools::save_html()`.
#'
#' @return A single htmltools::htmlDependency() object
#' @keywords internal
maidr_responsive_dependency <- function() {
  head_html <- paste(
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
    '<style>',
    '  html, body { margin: 0; padding: 0; width: 100%; height: 100%; }',
    '  body { background-color: white; }',
    '  .maidr-page {',
    # align-items: flex-start so chart anchors to the top of the viewport
    # instead of being vertically centered (which leaves a large blank band
    # above the chart, and looks like a rendering bug).
    '    display: flex; align-items: flex-start; justify-content: center;',
    '    min-height: 100vh; width: 100%; padding: 16px;',
    '    box-sizing: border-box;',
    '  }',
    '  .maidr-page svg {',
    '    max-width: 100%; max-height: calc(100vh - 32px);',
    '    width: auto; height: auto;',
    # IMPORTANT: do NOT set `overflow: visible` here. gridSVG export of
    # quantmod::chartSeries emits volume <rect> elements with negative-y
    # coordinates (e.g. y="-43.3", height up to ~165) that depend on the
    # SVG root's default `overflow: hidden` to clip the un-rendered
    # portion. `overflow: visible` un-clips those rectangles and causes
    # the volume bars to spill far below the chart panel. Label fitting
    # for chartSeries date-range header and bottom date labels is handled
    # instead by enlarging the device canvas (see gt_width/gt_height in
    # base_r_plot_orchestrator.R and dev_width/dev_height in
    # create_enhanced_svg() below).
    '  }',
    '</style>',
    sep = "\n"
  )
  htmltools::htmlDependency(
    name = "maidr-responsive",
    version = "1.0.0",
    src = c(href = ""),
    all_files = FALSE,
    head = head_html
  )
}

#' Save HTML document to file
#' @param html_doc An htmltools HTML document object
#' @param file Output file path
#' @keywords internal
save_html_document <- function(html_doc, file) {
  htmltools::save_html(html_doc, file = file)
}

#' Display HTML document directly
#' @param html_doc An htmltools HTML document object
#' @keywords internal
display_html <- function(html_doc) {
  if (Sys.getenv("RSTUDIO") == "1") {
    htmltools::html_print(html_doc)
  } else {
    temp_file <- tempfile(fileext = ".html")
    htmltools::save_html(html_doc, file = temp_file)
    utils::browseURL(temp_file)
  }
}

#' Display HTML file in browser
#' @param file HTML file path
#' @keywords internal
display_html_file <- function(file) {
  if (Sys.getenv("RSTUDIO") == "1") {
    htmltools::html_print(htmltools::includeHTML(file))
  } else {
    utils::browseURL(file)
  }
}

#' Create self-contained HTML for iframe embedding
#'
#' Generates a complete standalone HTML document with MAIDR.js that can be
#' embedded in an iframe for isolation. Each iframe gets its own JavaScript
#' context, avoiding MAIDR.js singleton pattern issues with multiple plots.
#'
#' @param svg_content Character vector of SVG content with maidr-data attribute
#' @param use_cdn Logical. If `TRUE`, use CDN. If `FALSE`, use bundled files.
#'   If `NULL` (default), auto-detect based on internet availability.
#' @return Character string of complete HTML document
#' @keywords internal
create_standalone_html <- function(svg_content, use_cdn = NULL) {
  svg_html <- paste(svg_content, collapse = "\n")

  # Auto-detect if not specified
  if (is.null(use_cdn)) {
    use_cdn <- curl::has_internet()
  }

  if (use_cdn) {
    # CDN links - smaller HTML, relies on internet at view time
    css_tag <- sprintf(
      '<link rel="stylesheet" href="%s/maidr.css">',
      maidr_cdn_url()
    )
    js_tag <- sprintf(
      '<script src="%s/maidr.js"></script>',
      maidr_cdn_url()
    )
  } else {
    # Inline local content - works offline, larger HTML
    assets <- maidr_local_assets()
    css_content <- paste(readLines(assets$css, warn = FALSE), collapse = "\n")
    js_content <- paste(readLines(assets$js, warn = FALSE), collapse = "\n")
    css_tag <- sprintf("<style>\n%s\n</style>", css_content)
    js_tag <- sprintf("<script>\n%s\n</script>", js_content)
  }

  # Create a complete standalone HTML document
  # CSS prevents layout shifts from focus outlines and MAIDR UI elements
  # Includes postMessage-based height reporting for dynamic iframe sizing
  html <- sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MAIDR Plot</title>
  %s
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%%;
      overflow: visible;
      box-sizing: border-box;
    }
    body {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: flex-start;
      padding-bottom: 10px;
    }
    svg {
      max-width: 100%%;
      height: auto;
      display: block;
    }
    /* Prevent focus outlines from causing layout shifts */
    *:focus {
      outline-offset: -2px !important;
    }
    svg:focus, svg:focus-visible {
      outline: 2px solid #0066cc !important;
      outline-offset: -2px !important;
    }
    /* Ensure MAIDR containers do not shift layout */
    figure, article {
      margin: 0 !important;
      padding: 0 !important;
      box-sizing: border-box;
    }
  </style>
</head>
<body>
  %s
  %s
  <script>
    // Dynamic height reporting via postMessage for iframe auto-sizing
    (function() {
      var lastHeight = 0;

      function reportHeight() {
        // Calculate total content height including any MAIDR-added elements
        var height = document.body.scrollHeight;
        // Add small buffer for padding
        height = Math.max(height, 100) + 20;

        // Only send if height changed significantly (avoid message spam)
        if (Math.abs(height - lastHeight) > 5) {
          lastHeight = height;
          try {
            window.parent.postMessage({
              type: "maidr-iframe-height",
              height: height
            }, "*");
          } catch(e) {
            // Ignore cross-origin errors
          }
        }
      }

      // Report initial height after page loads
      if (document.readyState === "complete") {
        setTimeout(reportHeight, 100);
      } else {
        window.addEventListener("load", function() {
          setTimeout(reportHeight, 100);
        });
      }

      // Watch for DOM changes (MAIDR.js adds instruction div dynamically)
      var observer = new MutationObserver(function(mutations) {
        // Debounce: wait a bit for all changes to complete
        setTimeout(reportHeight, 50);
      });

      observer.observe(document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        characterData: true
      });

      // Also report on window resize
      window.addEventListener("resize", reportHeight);

      // Report periodically for first few seconds to catch late MAIDR init
      var checks = 0;
      var interval = setInterval(function() {
        reportHeight();
        checks++;
        if (checks > 20) clearInterval(interval);
      }, 250);
    })();
  </script>
</body>
</html>', css_tag, svg_html, js_tag)

  html
}

#' Create iframe HTML tag for isolated MAIDR plot
#'
#' Creates an iframe element with base64-encoded src containing the complete MAIDR plot.
#' Uses data URI with base64 encoding to avoid quote escaping issues with JSON.
#' This isolates each plot in its own document/JavaScript context.
#'
#' @param svg_content Character vector of SVG content with maidr-data attribute
#' @param width Width of the iframe (default: "100\%")
#' @param height Height of the iframe (default: "450px")
#' @param plot_id Unique identifier for the plot
#' @param use_cdn Logical. If `TRUE`, use CDN. If `FALSE`, use bundled files.
#'   If `NULL` (default), auto-detect based on internet availability.
#' @return Character string of iframe HTML
#' @keywords internal
create_maidr_iframe <- function(svg_content, width = "100%", height = "450px", plot_id = NULL, use_cdn = NULL) {
  if (is.null(plot_id)) {
    plot_id <- generate_unique_id()
  }

  standalone_html <- create_standalone_html(svg_content, use_cdn = use_cdn)

  # Use base64 encoding to avoid quote escaping issues with JSON in maidr-data
  html_base64 <- base64enc::base64encode(charToRaw(standalone_html))
  data_uri <- paste0("data:text/html;base64,", html_base64)

  iframe_html <- sprintf(
    '<iframe id="maidr-iframe-%s" src="%s" style="width: %s; height: %s; border: none; display: block; margin: 0 auto; outline: none;" role="img" tabindex="0"></iframe>',
    plot_id,
    data_uri,
    width,
    height
  )

  iframe_html
}

#' Create iframe HTML tag for fallback static image
#'
#' Creates an iframe element with base64-encoded src containing a static image.
#' Used when plots contain unsupported layers and fall back to PNG rendering.
#' Unlike create_maidr_iframe, this does not include MAIDR.js dependencies.
#'
#' @param html_content Character string of HTML content (with img tag)
#' @param width Width of the iframe (default: "100\%")
#' @param height Height of the iframe (default: "450px")
#' @param plot_id Unique identifier for the plot
#' @return Character string of iframe HTML
#' @keywords internal
create_fallback_iframe <- function(html_content, width = "100%", height = "450px", plot_id = NULL) {
  if (is.null(plot_id)) {
    plot_id <- generate_unique_id()
  }

  # Create a simple standalone HTML document for the fallback image
  standalone_html <- sprintf(
    '<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Plot (Fallback)</title>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%%;
      height: 100%%;
      display: flex;
      align-items: center;
      justify-content: center;
      background-color: white;
      box-sizing: border-box;
    }
    img {
      max-width: 100%%;
      max-height: 100%%;
      height: auto;
      display: block;
    }
  </style>
</head>
<body>
  %s
</body>
</html>',
    html_content
  )

  # Use base64 encoding for the iframe src
  html_base64 <- base64enc::base64encode(charToRaw(standalone_html))
  data_uri <- paste0("data:text/html;base64,", html_base64)

  iframe_html <- sprintf(
    '<iframe id="maidr-fallback-%s" src="%s" style="width: %s; height: %s; border: none; display: block; margin: 0 auto;" role="img" tabindex="0"></iframe>',
    plot_id,
    data_uri,
    width,
    height
  )

  iframe_html
}
