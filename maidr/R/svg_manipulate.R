#' Annotate bar rects in SVG with a unique maidr attribute for a given layer_id
#' @param svg_path Path to the SVG file
#' @param out_path Path to save the modified SVG
#' @param layer_id The unique id to add as maidr attribute
#' @export
add_maidr_id_to_bars <- function(svg_path, out_path, layer_id) {
  library(xml2)
  doc <- read_xml(svg_path)
  ns <- xml_ns(doc)
  # Use the SVG namespace in the XPath query
  g_nodes <- xml_find_all(doc, ".//d1:g[@clip-path]", ns)
  if (length(g_nodes) == 0) stop("No <g> with clip-path found.")

  max_rects <- 0
  best_g <- NULL
  for (i in seq_along(g_nodes)) {
    g <- g_nodes[[i]]
    rects <- xml_find_all(g, ".//d1:rect", ns)
    if (length(rects) > max_rects) {
      max_rects <- length(rects)
      best_g <- g
    }
  }
  if (is.null(best_g) || max_rects < 2) stop("No suitable <g> with enough rects found.")
  rects <- xml_find_all(best_g, ".//d1:rect", ns)
  for (rect in rects[-1]) {
    xml_set_attr(rect, "maidr", layer_id)
  }
  write_xml(doc, out_path, options = "format")
  # Patch the root <svg> tag to ensure xmlns is present
  svg_lines <- readLines(out_path)
  if (!grepl('xmlns="http://www.w3.org/2000/svg"', svg_lines[1])) {
    svg_lines[1] <- sub('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ', svg_lines[1], fixed = TRUE)
    writeLines(svg_lines, out_path)
  }
}

#' Inject maidr-data JSON as an attribute on the root <svg> node (in-memory)
#' @param doc An xml_document (SVG)
#' @param maidr_json A JSON string to add as the maidr-data attribute
#' @return The modified xml_document
#' @export
inject_maidr_data_attribute <- function(doc, maidr_json) {
  ns <- xml2::xml_ns(doc)
  svg_node <- xml2::xml_find_first(doc, "//d1:svg", ns)
  if (is.na(svg_node)) stop("No <svg> root node found.")
  xml2::xml_set_attr(svg_node, "maidr-data", maidr_json)
  doc
} 