#' MAIDR JavaScript library version bundled with this package
#'
#' @keywords internal
MAIDR_VERSION <- "3.39.0"

#' Get the MAIDR CDN base URL for a specific version
#'
#' @param version MAIDR version string (default: bundled version)
#' @return CDN URL string
#' @keywords internal
maidr_cdn_url <- function(version = MAIDR_VERSION) {
  sprintf("https://cdn.jsdelivr.net/npm/maidr@%s/dist", version)
}

#' Register JS/CSS dependencies for maidr with auto-detection
#'
#' Creates HTML dependencies for MAIDR JavaScript and CSS files.
#' Automatically detects internet availability:
#' - If internet is available: uses CDN (smaller HTML, better caching)
#' - If offline: uses local bundled files (works without internet)
#'
#' @return A list containing one htmlDependency object
#' @keywords internal
maidr_html_dependencies <- function() {
  # Auto-detect: use CDN if internet available, otherwise local files
  use_cdn <- curl::has_internet()

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
