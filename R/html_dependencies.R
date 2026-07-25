#' MAIDR JavaScript library version bundled with this package
#'
#' @keywords internal
MAIDR_VERSION <- "3.73.0"

#' Get the MAIDR CDN base URL
#'
#' Pinned to the same version as the bundled assets: the maidr-data JSON
#' emitted by this package is written against that frontend version, so an
#' unpinned `@latest` CDN could silently break rendering when upstream
#' releases a breaking change.
#'
#' @return CDN URL string
#' @keywords internal
maidr_cdn_url <- function() {
  sprintf("https://cdn.jsdelivr.net/npm/maidr@%s/dist", MAIDR_VERSION)
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

# Session cache for inlined asset tags (the JS bundle is several MB;
# re-reading it from disk for every rendered plot is wasteful in
# documents with many plots) and for the internet-availability probe.
.maidr_asset_cache <- new.env(parent = emptyenv())

#' Check internet availability once per session
#'
#' curl::has_internet() can block for seconds on offline machines, so the
#' result is cached for the session rather than probed per plot.
#'
#' @return TRUE if internet appears available
#' @keywords internal
maidr_internet_available <- function() {
  cached <- .maidr_asset_cache$internet
  if (!is.null(cached)) {
    return(cached)
  }

  result <- tryCatch(curl::has_internet(), error = function(e) FALSE)
  .maidr_asset_cache$internet <- isTRUE(result)
  .maidr_asset_cache$internet
}

#' Get `<style>`/`<script>` tags with the bundled assets inlined
#'
#' Reads the bundled maidr.js/maidr.css once per session and caches the
#' assembled tags.
#'
#' @return A named list with `css_tag` and `js_tag` strings
#' @keywords internal
maidr_inline_asset_tags <- function() {
  cached <- .maidr_asset_cache$tags
  if (!is.null(cached)) {
    return(cached)
  }

  assets <- maidr_local_assets()
  css_content <- paste(readLines(assets$css, warn = FALSE), collapse = "\n")
  js_content <- paste(readLines(assets$js, warn = FALSE), collapse = "\n")

  tags <- list(
    css_tag = sprintf("<style>\n%s\n</style>", css_content),
    js_tag = sprintf("<script>\n%s\n</script>", js_content)
  )
  .maidr_asset_cache$tags <- tags
  tags
}
