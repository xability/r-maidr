#' MAIDR JavaScript library version bundled with this package
#'
#' @keywords internal
MAIDR_VERSION <- "3.69.0"

#' Get the MAIDR CDN base URL
#'
#' Uses @latest to always fetch the most recent version from CDN.
#'
#' @return CDN URL string
#' @keywords internal
maidr_cdn_url <- function() {
  "https://cdn.jsdelivr.net/npm/maidr@latest/dist"
}

#' Register JS/CSS dependencies for maidr
#'
#' Creates HTML dependencies for MAIDR JavaScript and CSS files.
#' Behavior is controlled by the `use_cdn` parameter:
#' - If `TRUE`: Use CDN (requires internet)
#' - If `FALSE` (default): Use local bundled files (works offline)
#' - If `NULL`: Same as `FALSE` — use local bundled files
#'
#' We default to local bundled assets for deterministic rendering. Previously
#' we auto-detected via `curl::has_internet()`; when internet was available
#' the CDN path was selected, which combined with a (now-fixed) malformed
#' nested-`<html>` HTML scaffold caused base R chart SVGs to render squished
#' in the upper-left of the viewport. Local assets match the ggplot path that
#' has always rendered correctly. Users who want CDN can still pass
#' `use_cdn = TRUE` explicitly.
#'
#' @param use_cdn Logical. If `TRUE`, use CDN. If `FALSE` or `NULL` (default),
#'   use bundled files.
#' @return A list containing one htmlDependency object
#' @keywords internal
maidr_html_dependencies <- function(use_cdn = NULL) {

  # Default to local bundled assets for deterministic offline-capable rendering
  if (is.null(use_cdn)) {
    use_cdn <- FALSE
  }

  if (use_cdn) {
    # CDN dependency - smaller HTML, relies on internet
    maidr_dep <- htmltools::htmlDependency(
      name = "maidr",
      version = MAIDR_VERSION,
      src = c(href = maidr_cdn_url()),
      script = "maidr.js",
      stylesheet = "maidr.css"
    )
  } else {
    # Local dependency - works offline, copies files to lib/ folder
    maidr_dep <- htmltools::htmlDependency(
      name = "maidr",
      version = MAIDR_VERSION,
      package = "maidr",
      src = sprintf("htmlwidgets/lib/maidr-%s", MAIDR_VERSION),
      script = "maidr.js",
      stylesheet = "maidr.css"
    )
  }

  list(maidr_dep)
}

#' Get paths to local MAIDR assets
#'
#' Returns the file paths to the locally bundled MAIDR JavaScript and CSS files.
#'
#' @return A named list with 'js' and 'css' file paths
#' @keywords internal
maidr_local_assets <- function() {
  base_path <- system.file(
    sprintf("htmlwidgets/lib/maidr-%s", MAIDR_VERSION),
    package = "maidr"
  )

  list(
    js = file.path(base_path, "maidr.js"),
    css = file.path(base_path, "maidr.css"),
    version = MAIDR_VERSION
  )
}
