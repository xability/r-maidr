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
  dev_width <- 7   # inches
  dev_height <- 5  # inches

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

#' Add maidr-data to SVG using proper XML manipulation
#' @param svg_content Character vector of SVG lines
#' @param maidr_data The maidr-data structure
#' @return Modified SVG content
#' @keywords internal
add_maidr_data_to_svg <- function(svg_content, maidr_data) {
  maidr_json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE)

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
  html_doc <- htmltools::tags$html(
    htmltools::tags$head(),
    htmltools::tags$body(
      htmltools::HTML(paste(svg_content, collapse = "\n"))
    )
  )

  html_doc <- htmltools::attachDependencies(
    html_doc,
    maidr_html_dependencies(use_cdn = use_cdn)
  )

  html_doc
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
